use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::process::{Command, Output, Stdio};

use serde_json::Value;
use tempfile::tempdir;

fn output(command: &mut Command) -> Output {
    command
        .output()
        .unwrap_or_else(|error| panic!("failed to run {command:?}: {error}"))
}

fn succeeds(command: &mut Command) -> Output {
    let output = output(command);
    assert!(
        output.status.success(),
        "{command:?}\nstdout: {}\nstderr: {}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    output
}

fn fails(command: &mut Command) {
    assert!(!output(command).status.success(), "{command:?} succeeded");
}

fn secretctl(root: &Path, home: &Path) -> Command {
    let mut command = Command::new(env!("CARGO_BIN_EXE_secretctl"));
    command.current_dir(root).env("HOME", home);
    command
}

#[test]
fn secrets_workflow() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().join("repo");
    let home = temporary.path().join("home");
    fs::create_dir_all(&root).unwrap();
    fs::create_dir_all(&home).unwrap();

    succeeds(Command::new("git").args(["-C", root.to_str().unwrap(), "init", "-q"]));
    succeeds(secretctl(&root, &home).arg("check"));
    fs::write(root.join(".sops.yaml"), "{}").unwrap();
    fails(secretctl(&root, &home).arg("check"));
    fs::remove_file(root.join(".sops.yaml")).unwrap();
    fs::create_dir_all(root.join("secrets/shared")).unwrap();
    fs::write(root.join("secrets/shared/rogue.yaml"), "value: plaintext\n").unwrap();
    fails(secretctl(&root, &home).arg("init"));
    fs::remove_dir_all(root.join("secrets")).unwrap();

    let alpha = temporary.path().join("alpha");
    let beta = temporary.path().join("beta");
    let gamma = temporary.path().join("gamma");
    succeeds(
        Command::new("ssh-keygen")
            .args(["-q", "-t", "ed25519", "-N", "", "-f"])
            .arg(&alpha)
            .stdin(Stdio::null()),
    );
    succeeds(
        Command::new("ssh-keygen")
            .args(["-q", "-t", "ed25519", "-N", "", "-f"])
            .arg(&gamma)
            .stdin(Stdio::null()),
    );
    fails(
        secretctl(&root, &home)
            .arg("onboard")
            .arg("alpha")
            .arg(alpha.with_extension("pub")),
    );
    succeeds(secretctl(&root, &home).arg("init").stdin(Stdio::null()));
    let registry_path = root.join("secrets/recipients.json");
    let registry_json = fs::read_to_string(&registry_path).unwrap();
    let mut invalid_registry: Value = serde_json::from_str(&registry_json).unwrap();
    invalid_registry["admin"] = serde_json::json!("age1garbage");
    fs::write(
        &registry_path,
        serde_json::to_string_pretty(&invalid_registry).unwrap(),
    )
    .unwrap();
    fails(secretctl(&root, &home).arg("check"));
    fs::write(&registry_path, &registry_json).unwrap();

    succeeds(
        Command::new("ssh-keygen")
            .args(["-q", "-t", "ed25519", "-N", "", "-f"])
            .arg(&beta)
            .stdin(Stdio::null()),
    );
    succeeds(
        secretctl(&root, &home)
            .arg("onboard")
            .arg("alpha")
            .arg(alpha.with_extension("pub")),
    );
    fails(
        secretctl(&root, &home)
            .arg("onboard")
            .arg("alpha-alias")
            .arg(alpha.with_extension("pub")),
    );
    fails(
        secretctl(&root, &home)
            .arg("onboard")
            .arg("invalid")
            .arg(alpha.with_extension("pub"))
            .arg("bad/scope"),
    );
    let shell = std::env::split_paths(&std::env::var_os("PATH").unwrap())
        .map(|directory| directory.join("sh"))
        .find(|path| path.is_file())
        .unwrap();
    let editor = temporary.path().join("editor");
    fs::write(
        &editor,
        format!(
            "#!{}\nprintf 'value: test-secret\\n' > \"$1\"\n",
            shell.display()
        ),
    )
    .unwrap();
    fs::set_permissions(&editor, fs::Permissions::from_mode(0o755)).unwrap();
    let cancelled = root.join("secrets/shared/cancelled.yaml");
    succeeds(
        secretctl(&root, &home)
            .args(["edit", "shared", "cancelled"])
            .env("EDITOR", "true"),
    );
    assert!(!cancelled.exists());
    succeeds(
        secretctl(&root, &home)
            .args(["edit", "shared", "example"])
            .env("EDITOR", editor),
    );
    succeeds(
        secretctl(&root, &home)
            .arg("onboard")
            .arg("beta")
            .arg(beta.with_extension("pub"))
            .args(["shared", "beta"]),
    );
    succeeds(
        secretctl(&root, &home)
            .arg("onboard")
            .arg("lab.vm")
            .arg(gamma.with_extension("pub"))
            .arg("lab.vm"),
    );
    fails(secretctl(&root, &home).arg("init"));
    succeeds(secretctl(&root, &home).arg("check"));
    let tampered = root.join("secrets/shared/tampered.yaml");
    let ciphertext = fs::read_to_string(root.join("secrets/shared/example.yaml")).unwrap();
    fs::write(&tampered, format!("{ciphertext}plaintext: exposed\n")).unwrap();
    fails(secretctl(&root, &home).arg("check"));
    fs::remove_file(tampered).unwrap();

    let secret = root.join("secrets/shared/example.yaml");
    let admin_decryption = succeeds(
        Command::new("sops")
            .args(["decrypt", "--extract", "[\"value\"]"])
            .arg(&secret)
            .env("HOME", &home),
    );
    assert_eq!(admin_decryption.stdout, b"test-secret");

    let alpha_age = temporary.path().join("alpha.age");
    succeeds(
        Command::new("ssh-to-age")
            .arg("-private-key")
            .arg("-i")
            .arg(&alpha)
            .arg("-o")
            .arg(&alpha_age),
    );
    let device_decryption = succeeds(
        Command::new("sops")
            .args(["decrypt", "--extract", "[\"value\"]"])
            .arg(&secret)
            .env("HOME", temporary.path().join("device-home"))
            .env("SOPS_AGE_KEY_FILE", &alpha_age),
    );
    assert_eq!(device_decryption.stdout, b"test-secret");

    let registry: Value =
        serde_json::from_str(&fs::read_to_string(root.join("secrets/recipients.json")).unwrap())
            .unwrap();
    assert!(registry.get("scopes").is_none());
    assert_eq!(
        registry["devices"]["alpha"]["scopes"],
        serde_json::json!(["alpha", "shared"])
    );
    assert_eq!(
        registry["devices"]["beta"]["scopes"],
        serde_json::json!(["beta", "shared"])
    );
    assert_eq!(
        registry["devices"]["lab.vm"]["scopes"],
        serde_json::json!(["lab.vm"])
    );

    let config: Value =
        serde_json::from_str(&fs::read_to_string(root.join(".sops.yaml")).unwrap()).unwrap();
    assert!(
        config["creation_rules"]
            .as_array()
            .unwrap()
            .iter()
            .any(|rule| {
                rule["path_regex"] == serde_json::json!("^secrets/lab\\.vm/[^/]+\\.yaml$")
            })
    );

    let registry_before_failed_offboard = fs::read_to_string(&registry_path).unwrap();
    let config_before_failed_offboard = fs::read_to_string(root.join(".sops.yaml")).unwrap();
    let secret_before_failed_offboard = fs::read_to_string(&secret).unwrap();
    let fake_bin = temporary.path().join("fake-bin");
    fs::create_dir(&fake_bin).unwrap();
    let fake_sops = fake_bin.join("sops");
    fs::write(
        &fake_sops,
        format!(
            "#!{}\nfor argument do file=\"$argument\"; done\nprintf broken > \"$file\"\nexit 1\n",
            shell.display()
        ),
    )
    .unwrap();
    fs::set_permissions(&fake_sops, fs::Permissions::from_mode(0o755)).unwrap();
    let path = std::env::join_paths(
        std::iter::once(fake_bin).chain(std::env::split_paths(&std::env::var_os("PATH").unwrap())),
    )
    .unwrap();
    fails(
        secretctl(&root, &home)
            .arg("offboard")
            .env("FZF_DEFAULT_OPTS", "--filter=alpha")
            .env("PATH", path),
    );
    assert_eq!(
        fs::read_to_string(&registry_path).unwrap(),
        registry_before_failed_offboard
    );
    assert_eq!(
        fs::read_to_string(root.join(".sops.yaml")).unwrap(),
        config_before_failed_offboard
    );
    assert_eq!(
        fs::read_to_string(&secret).unwrap(),
        secret_before_failed_offboard
    );
    fails(
        secretctl(&root, &home)
            .arg("offboard")
            .env("FZF_DEFAULT_OPTS", "--filter=missing"),
    );
    succeeds(
        secretctl(&root, &home)
            .arg("offboard")
            .env("FZF_DEFAULT_OPTS", "--filter=alpha"),
    );
    succeeds(secretctl(&root, &home).arg("check"));
    fails(
        Command::new("sops")
            .args(["decrypt", "--extract", "[\"value\"]"])
            .arg(&secret)
            .env("HOME", temporary.path().join("device-home"))
            .env("SOPS_AGE_KEY_FILE", alpha_age),
    );
    let registry: Value =
        serde_json::from_str(&fs::read_to_string(&registry_path).unwrap()).unwrap();
    assert!(registry["devices"]["alpha"].is_null());

    succeeds(
        secretctl(&root, &home)
            .arg("remove")
            .env("FZF_DEFAULT_OPTS", "--filter=shared/example"),
    );
    assert!(!secret.exists());
    succeeds(secretctl(&root, &home).arg("check"));
}
