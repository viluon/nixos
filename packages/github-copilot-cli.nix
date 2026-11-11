{ lib, cacert, github-copilot-cli }:
let
  sslCertDirFlag = "--set-default SSL_CERT_DIR ${cacert}/etc/ssl/certs";
in
github-copilot-cli.overrideAttrs (old: {
  postInstall =
    let
      patched = lib.replaceStrings [ sslCertDirFlag ] [ "" ] old.postInstall;
    in
    assert patched != old.postInstall;
    patched;
})
