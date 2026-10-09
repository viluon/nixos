{ rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "kitty-cpu-tabs";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
}
