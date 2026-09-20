use std::collections::{BTreeMap, BTreeSet};
use std::env;
use std::ffi::OsString;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::LazyLock;

use anyhow::{Context, Result, ensure};
use duct::cmd;
use regex::Regex;
use saphyr::{LoadableYamlNode, Yaml};
use serde::{Deserialize, Serialize};

static NAME: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^[a-zA-Z0-9][a-zA-Z0-9._-]*$").unwrap());

#[derive(Deserialize, Serialize)]
struct Registry {
    admin: String,
    devices: BTreeMap<String, Device>,
}

#[derive(Deserialize, Serialize)]
struct Device {
    recipient: String,
    scopes: BTreeSet<String>,
}

#[derive(Serialize)]
struct SopsConfig {
    creation_rules: Vec<CreationRule>,
}

#[derive(Serialize)]
struct CreationRule {
    path_regex: String,
    key_groups: [KeyGroup; 1],
}

#[derive(Serialize)]
struct KeyGroup {
    age: BTreeSet<String>,
}

pub struct Repository {
    root: PathBuf,
}

impl Repository {
    pub fn discover() -> Result<Self> {
        let root = cmd!("git", "rev-parse", "--show-toplevel").read()?;
        Ok(Self { root: root.into() })
    }

    pub fn init(&self) -> Result<()> {
        ensure!(
            self.registry()?.is_none() && !self.config_path().exists(),
            "editor identity already initialized"
        );
        ensure!(
            self.secret_files()?.is_empty(),
            "uninitialized repository contains secrets"
        );

        let key_file = key_file()?;
        ensure!(
            !key_file.exists(),
            "key already exists: {}",
            key_file.display()
        );
        fs::create_dir_all(key_file.parent().context("invalid key path")?)?;
        cmd!("age-keygen", "-o", &key_file).run()?;
        fs::set_permissions(&key_file, fs::Permissions::from_mode(0o600))?;
        fs::create_dir_all(self.root.join("secrets"))?;
        let registry = Registry {
            admin: cmd!("age-keygen", "-y", &key_file).read()?,
            devices: BTreeMap::new(),
        };
        self.save_and_rekey(&registry)
    }

    pub fn onboard(&self, name: &str, public_key: &Path, scopes: &[String]) -> Result<()> {
        require_name(name)?;
        ensure!(
            fs::read_to_string(public_key)?.starts_with("ssh-ed25519 "),
            "expected SSH Ed25519 public key"
        );

        let mut registry = self.initialized_registry()?;
        let recipient = cmd!("ssh-to-age", "-i", public_key).read()?;
        require_recipient(&recipient)?;
        let scopes = parse_scopes(scopes, name)?;
        ensure!(
            registry.admin != recipient
                && registry
                    .devices
                    .values()
                    .all(|device| device.recipient != recipient),
            "recipient is already registered"
        );

        registry
            .devices
            .insert(name.into(), Device { recipient, scopes });
        self.save_and_rekey(&registry)
    }

    pub fn offboard(&self) -> Result<()> {
        let mut registry = self.initialized_registry()?;
        let name = select("device> ", registry.devices.keys().cloned())?;
        ensure!(
            registry.devices.remove(&name).is_some(),
            "unknown device: {name}"
        );
        self.save_and_rekey(&registry)
    }

    fn save_and_rekey(&self, registry: &Registry) -> Result<()> {
        validate_registry(registry)?;
        let files = self.secret_files()?;
        let original_files = files
            .iter()
            .map(fs::read)
            .collect::<std::io::Result<Vec<_>>>()?;
        let config = config_for(registry, &self.scopes(registry, &files)?);
        let pending_config = self.config_path().with_extension("yaml.new");
        let pending_registry = self.registry_path().with_extension("json.new");
        fs::write(&pending_config, json(&config)?)?;
        fs::write(&pending_registry, json(registry)?)?;
        for file in &files {
            if let Err(error) = cmd!(
                "sops",
                "--config",
                &pending_config,
                "updatekeys",
                "--yes",
                file
            )
            .run()
            {
                for (file, contents) in files.iter().zip(original_files) {
                    fs::write(file, contents)?;
                }
                fs::remove_file(&pending_config)?;
                fs::remove_file(&pending_registry)?;
                return Err(error.into());
            }
        }
        fs::rename(pending_config, self.config_path())?;
        fs::rename(pending_registry, self.registry_path())?;
        self.git_add(
            [self.registry_path(), self.config_path()]
                .into_iter()
                .chain(files),
        )
    }

    pub fn edit(&self, scope: &str, name: &str) -> Result<()> {
        require_name(scope)?;
        require_name(name)?;
        let registry = self.initialized_registry()?;
        let files = self.secret_files()?;
        ensure!(
            self.scopes(&registry, &files)?.contains(scope),
            "unknown scope: {scope}"
        );

        let directory = self.root.join("secrets").join(scope);
        fs::create_dir_all(&directory)?;
        let file = directory.join(format!("{name}.yaml"));

        let config = self.config_path();
        let created = !file.exists();
        if created {
            let ciphertext = cmd!(
                "sops",
                "--config",
                &config,
                "encrypt",
                "--filename-override",
                &file,
                "--input-type",
                "yaml",
                "--output-type",
                "yaml",
                "/dev/stdin"
            )
            .stdin_bytes(b"value: \"\"\n")
            .read()?;
            fs::write(&file, ciphertext)?;
        }

        let status = cmd!("sops", "--config", config, &file)
            .unchecked()
            .run()?
            .status;
        ensure!(
            status.success() || status.code() == Some(200),
            "sops failed with {status}"
        );
        if created && status.code() == Some(200) {
            fs::remove_file(file)?;
            return Ok(());
        }
        self.git_add([file])
    }

    pub fn remove(&self) -> Result<()> {
        self.initialized_registry()?;
        let secrets = self
            .secret_files()?
            .into_iter()
            .map(|file| {
                file.strip_prefix(self.root.join("secrets"))
                    .map(|path| path.with_extension("").display().to_string())
                    .map_err(Into::into)
            })
            .collect::<Result<Vec<_>>>()?;
        let secret = select("secret> ", secrets)?;
        let (scope, name) = secret
            .split_once('/')
            .context("secret must be formatted as SCOPE/NAME")?;
        require_name(scope)?;
        require_name(name)?;
        let file = self
            .root
            .join("secrets")
            .join(scope)
            .join(format!("{name}.yaml"));
        ensure!(file.is_file(), "unknown secret: {scope}/{name}");
        fs::remove_file(&file)?;
        self.git_add([file])
    }

    pub fn check(&self) -> Result<()> {
        let files = self.secret_files()?;
        let registry = match (self.registry()?, self.config_path().exists()) {
            (None, false) => {
                ensure!(files.is_empty(), "secrets repository is not initialized");
                return Ok(());
            }
            (Some(registry), true) => registry,
            _ => anyhow::bail!("secrets repository is only partially initialized"),
        };
        validate_registry(&registry)?;
        ensure!(
            fs::read_to_string(self.config_path())?
                == json(&config_for(&registry, &self.scopes(&registry, &files)?))?,
            ".sops.yaml is stale"
        );
        for file in files {
            self.check_secret(&registry, &file)?;
        }
        Ok(())
    }

    fn check_secret(&self, registry: &Registry, file: &Path) -> Result<()> {
        let relative = file.strip_prefix(self.root.join("secrets"))?;
        let scope = relative
            .parent()
            .and_then(Path::file_name)
            .and_then(|name| name.to_str())
            .context("invalid secret path")?;
        let expected = recipients_for_scope(registry, scope);
        ensure!(
            !expected.is_empty(),
            "secret has no recipients: {}",
            relative.display()
        );

        let documents = Yaml::load_from_str(&fs::read_to_string(file)?)?;
        ensure!(documents.len() == 1, "secret has multiple documents");
        let document = documents.first().context("empty secret")?;
        let fields = document.as_mapping().context("secret is not a mapping")?;
        ensure!(
            fields.len() == 2
                && fields
                    .keys()
                    .all(|field| matches!(field.as_str(), Some("value" | "sops"))),
            "secret has unexpected fields: {}",
            relative.display()
        );
        ensure!(
            document["value"]
                .as_str()
                .is_some_and(|value| value.starts_with("ENC[")),
            "secret has unencrypted value: {}",
            relative.display()
        );
        ensure!(
            document["sops"]["mac"]
                .as_str()
                .is_some_and(|mac| mac.starts_with("ENC[")),
            "secret has invalid MAC: {}",
            relative.display()
        );
        let age = document["sops"]["age"]
            .as_vec()
            .context("secret lacks age keys")?;
        let actual: BTreeSet<String> = age
            .iter()
            .map(|entry| {
                entry["recipient"]
                    .as_str()
                    .map(String::from)
                    .context("invalid age key")
            })
            .collect::<Result<_>>()?;
        ensure!(
            actual.len() == age.len(),
            "secret has duplicate recipients: {}",
            relative.display()
        );
        ensure!(
            actual == expected,
            "secret has stale recipients: {}",
            relative.display()
        );
        Ok(())
    }

    fn registry(&self) -> Result<Option<Registry>> {
        match fs::read_to_string(self.registry_path()) {
            Ok(contents) => serde_json::from_str(&contents)
                .map(Some)
                .map_err(Into::into),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(None),
            Err(error) => Err(error.into()),
        }
    }

    fn initialized_registry(&self) -> Result<Registry> {
        ensure!(
            self.config_path().is_file(),
            "secrets repository is only partially initialized"
        );
        let registry = self.registry()?.context("run: just secrets-init")?;
        validate_registry(&registry)?;
        Ok(registry)
    }

    fn registry_path(&self) -> PathBuf {
        self.root.join("secrets/recipients.json")
    }

    fn config_path(&self) -> PathBuf {
        self.root.join(".sops.yaml")
    }

    fn secret_files(&self) -> Result<Vec<PathBuf>> {
        let mut files = Vec::new();
        let secret_root = self.root.join("secrets");
        if !secret_root.exists() {
            return Ok(files);
        }
        for scope in fs::read_dir(secret_root)? {
            let scope = scope?;
            if scope.file_type()?.is_dir() {
                for file in fs::read_dir(scope.path())? {
                    let file = file?;
                    if file.file_type()?.is_file()
                        && file.path().extension().is_some_and(|value| value == "yaml")
                    {
                        files.push(file.path());
                    }
                }
            }
        }
        files.sort();
        Ok(files)
    }

    fn scopes(&self, registry: &Registry, files: &[PathBuf]) -> Result<BTreeSet<String>> {
        let mut scopes = registry
            .devices
            .values()
            .flat_map(|device| device.scopes.iter().cloned())
            .collect::<BTreeSet<_>>();
        for file in files {
            let scope = file
                .parent()
                .and_then(Path::file_name)
                .and_then(|scope| scope.to_str())
                .context("invalid secret scope")?;
            require_name(scope)?;
            scopes.insert(scope.into());
        }
        Ok(scopes)
    }

    fn git_add(&self, paths: impl IntoIterator<Item = PathBuf>) -> Result<()> {
        let args = [
            OsString::from("-C"),
            self.root.clone().into_os_string(),
            OsString::from("add"),
        ]
        .into_iter()
        .chain(paths.into_iter().map(PathBuf::into_os_string));
        cmd("git", args).run()?;
        Ok(())
    }
}

fn key_file() -> Result<PathBuf> {
    Ok(
        PathBuf::from(env::var_os("HOME").context("$HOME is not set")?)
            .join(".config/sops/age/keys.txt"),
    )
}

fn select(prompt: &str, choices: impl IntoIterator<Item = String>) -> Result<String> {
    let choices = choices.into_iter().collect::<Vec<_>>();
    ensure!(!choices.is_empty(), "nothing to select");
    cmd!("fzf", "--prompt", prompt)
        .stdin_bytes(choices.join("\n"))
        .read()
        .context("selection cancelled")
}

fn parse_scopes(scopes: &[String], device: &str) -> Result<BTreeSet<String>> {
    let scopes = if scopes.is_empty() {
        BTreeSet::from(["shared".into(), device.into()])
    } else {
        scopes.iter().cloned().collect()
    };
    ensure!(
        scopes.iter().all(|scope| NAME.is_match(scope)),
        "invalid scopes"
    );
    Ok(scopes)
}

fn require_name(name: &str) -> Result<()> {
    ensure!(NAME.is_match(name), "invalid name: {name}");
    Ok(())
}

fn require_recipient(recipient: &str) -> Result<()> {
    cmd!("age", "--encrypt", "--recipient", recipient)
        .stdin_bytes([])
        .stdout_null()
        .run()
        .with_context(|| format!("invalid age recipient: {recipient}"))?;
    Ok(())
}

fn validate_registry(registry: &Registry) -> Result<()> {
    require_recipient(&registry.admin)?;
    let mut recipients = BTreeSet::from([&registry.admin]);
    for (name, device) in &registry.devices {
        require_name(name)?;
        require_recipient(&device.recipient)?;
        ensure!(
            recipients.insert(&device.recipient),
            "duplicate recipient: {name}"
        );
        ensure!(!device.scopes.is_empty(), "device has no scopes: {name}");
        for scope in &device.scopes {
            require_name(scope)?;
        }
    }
    Ok(())
}

fn recipients_for_scope(registry: &Registry, scope: &str) -> BTreeSet<String> {
    registry
        .devices
        .values()
        .filter(|device| device.scopes.contains(scope))
        .map(|device| &device.recipient)
        .chain(std::iter::once(&registry.admin))
        .cloned()
        .collect()
}

fn config_for(registry: &Registry, scopes: &BTreeSet<String>) -> SopsConfig {
    SopsConfig {
        creation_rules: scopes
            .iter()
            .map(|scope| {
                let age = recipients_for_scope(registry, scope);
                CreationRule {
                    path_regex: format!("^secrets/{}/[^/]+\\.yaml$", scope.replace('.', "\\.")),
                    key_groups: [KeyGroup { age }],
                }
            })
            .collect(),
    }
}

fn json(value: &impl Serialize) -> Result<String> {
    Ok(format!("{}\n", serde_json::to_string_pretty(value)?))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dotted_scopes_are_escaped() {
        let registry = Registry {
            admin: "age1admin".into(),
            devices: BTreeMap::new(),
        };
        let scopes = BTreeSet::from(["lab.vm".into()]);
        assert_eq!(
            config_for(&registry, &scopes).creation_rules[0].path_regex,
            "^secrets/lab\\.vm/[^/]+\\.yaml$"
        );
    }
}
