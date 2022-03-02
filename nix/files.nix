{ pkgs ? import <nixpkgs> { }, python, hdf5, mpi, zlib, cudatoolkit, cudnn, magma }:

{
  base-env-vars = pkgs.writeText "base-env-vars" ''
    # Keep track of project directory
    export PROJECT_DIR=$(pwd)

    # Libraries setup
    [ -z LD_LIBRARY_PATH ] && export LD_LIBRARY_PATH=""
    export LD_LIBRARY_PATH=${hdf5}:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${mpi}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.python38}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.zlib}/lib:$LD_LIBRARY_PATH

    # CUDA and magma path
    export LD_LIBRARY_PATH="${cudatoolkit}/lib:${cudnn}/lib:${magma}/lib:$LD_LIBRARY_PATH"
  '';

  base-pip-requirements = pkgs.writeTextFile {
    name = "requirements.txt";
    text = (builtins.readFile ./requirements.txt);
  };
}
