{ pkgs, secretctl }:
pkgs.runCommand "secrets"
{
  nativeBuildInputs = [
    pkgs.git
    secretctl
  ];
}
  ''
    cp -r ${../.} repo
    chmod -R u+w repo
    git -C repo init -q
    cd repo
    secretctl check
    touch "$out"
  ''
