{ pkgs ? import <nixpkgs> { } }:

let

  mkDerivation = import ../default.nix { inherit pkgs; };

  test_module = import ./test_module.nix { inherit pkgs; };

in mkDerivation {
  name = "example";
  lib = ./lib;

  requirements = pkgs.writeTextFile {
    name = "requirements.txt";
    text = (builtins.readFile ./my-env-requirements.txt);
  };

  pythonModules = [
    test_module
  ];
}
