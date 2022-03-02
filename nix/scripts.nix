{ pkgs ? import <nixpkgs> { },  hdf5, mpi, zlib, cudatoolkit, cudnn, magma, libuv }:

{
  install-h5py-mpi = pkgs.writeScriptBin "install-h5py-mpi" ''
      #!/usr/bin/env sh

      export CC=${mpi}/bin/mpicc
      export HDF5_DIR=${hdf5}/
      export HDF5_MPI=ON

      export NUMPY_INCLUDE=$(python -c 'import numpy; print(numpy.get_include())')
      export CPATH="$NUMPY_INCLUDE:$CPATH"
      export CPATH="${hdf5.dev}/include:$CPATH"

      echo "Checking h5py installation..."
      python -m pip install --quiet --no-binary=h5py h5py
      echo "Done checking h5py installation"
    '';

  install-pytorch =
    let
      pytorch-repo = pkgs.fetchgit {
        url = "https://github.com/pytorch/pytorch.git";
        rev = "56b43f4fec1f76953f15a627694d4bba34588969";
        sha256 = "1cx1r0qadx6c5jbvi9df64ssbdpb11vimysg227364rcbyhdhijv";
        deepClone = true;
      };
    in pkgs.writeScriptBin "install-pytorch" ''
      #!/usr/bin/env sh

      PYTORCH_REPO_DIR=$(pwd)/.venv/repos/$(basename ${pytorch-repo})

      echo "Checking pytorch installation..."
      [ -d $PYTORCH_REPO_DIR ] && echo "Pytorch already installed" && exit 0

      cp -r ${pytorch-repo} $PYTORCH_REPO_DIR
      chmod -R gu+rw $PYTORCH_REPO_DIR

      pushd $PYTORCH_REPO_DIR

      # library paths
      export CPATH="${hdf5.dev}/include:${mpi}/include:${cudatoolkit}/include:${cudnn}/include:${magma}/include:${libuv}/include:$CPATH"
      export LD_LIBRARY_PATH="${hdf5}/lib:${mpi}/lib:${cudatoolkit}/lib:${cudnn}/lib:${magma}/lib:${libuv}/lib"

      export CMAKE_PREFIX_PATH="${hdf5}:${hdf5.dev}:${mpi}:${cudatoolkit}:${cudnn}:${magma}:${libuv}:$CMAKE_PREFIX_PATH"

      python setup.py install

      popd
    '';

  pip-freeze = pkgs.writeScriptBin "pip-freeze" ''
    #!/usr/bin/env sh

    python -m pip freeze | grep -v h5py
  '';

  check-cuda = pkgs.writeScriptBin "check-cuda" ''
    #!/usr/bin/env sh

    python -c 'import torch; print(torch.cuda.is_available())'
  '';
}
