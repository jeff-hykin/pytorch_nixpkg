{ pkgs ? import <nixpkgs> { } }:

with pkgs;

# Any nix derivation that has python modules in its directory is a valid dependency.
stdenv.mkDerivation {
  name = "test_module";

  src = ./test_module;

  phases = "installPhase";

  installPhase = ''
    mkdir $out
    cp -r $src $out/test_module
  '';
}
