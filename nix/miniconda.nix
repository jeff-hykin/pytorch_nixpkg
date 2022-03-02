{ pkgs ? import <nixpkgs> { }, basePackages, pytorchPackages }: 

with pkgs;

# Installs miniconda to help with building PyTorch from source.

stdenv.mkDerivation rec {
  pname = "miniconda";
  version = "py38_4.9.2";

  src = writeTextFile rec {
    name = "miniconda-installer";
    destination = "/${name}.sh";
    text = builtins.readFile (
      builtins.fetchurl {
        url = "https://repo.anaconda.com/miniconda/Miniconda3-${version}-Linux-x86_64.sh";
        sha256 = "1314b90489f154602fd794accfc90446111514a5a72fe1f71ab83e07de9504a7";
      }
    );
  };

  installPhase = ''
    sh ${src}/${name}.sh -b -p $out


    ${if (builtins.length basePackages) == 0 then "# no-op" else "conda install ${builtins.concatStringsSep " " basePackages}"}

    ${if (builtins.length pytorchPackages) == 0 then "# no-op" else "conda install -c pytorch ${builtins.concatStringsSep " " pytorchPackages}"}
  '';

  configurePhase = "";
  buildPhase = "";
  doCheck = false;
}
