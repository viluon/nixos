{ lib
, rustPlatform
, makeWrapper
, git
, gh
, util-linux
}:
rustPlatform.buildRustPackage {
  pname = "starship-pr-ci";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ makeWrapper ];
  postInstall = ''
    wrapProgram $out/bin/starship-pr-ci \
      --prefix PATH : ${lib.makeBinPath [ git gh util-linux ]}
  '';
}
