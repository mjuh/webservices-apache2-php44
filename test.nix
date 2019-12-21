{ ref ? "master" }:

with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; inherit ref; }))
  ];
};

maketestPhp {
  php = php44;
  image = callPackage ./default.nix { inherit ref; };
  rootfs = ./rootfs;
  defaultTestSuite = false;
  containerStructureTestConfig = ./container-structure-test.yaml;
}{}
