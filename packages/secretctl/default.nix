{ lib
, rustPlatform
, makeWrapper
, age
, fzf
, git
, openssh
, sops
, ssh-to-age
}:
rustPlatform.buildRustPackage {
  pname = "secretctl";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [
    age
    fzf
    git
    openssh
    sops
    ssh-to-age
  ];
  postInstall = ''
    wrapProgram $out/bin/secretctl \
      --prefix PATH : ${lib.makeBinPath [ age fzf git sops ssh-to-age ]}
  '';
}
