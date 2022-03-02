let 
    # 
    # pick which frozen version of nixpkgs to use
    # 
    # 7e9b0dff974c89e070da1ad85713ff3c20b0ca97 # <- alternative
    pinnedNixVersion = "8917ffe7232e1e9db23ec9405248fd1944d0b36f"; # this is a hash of a specific commit
    pinnedNix = (builtins.import 
        (builtins.fetchTarball
            ({
                url=''https://github.com/NixOS/nixpkgs/archive/${pinnedNixVersion}.tar.gz'';
            })
        )
        ({
            config = {
                allowUnfree = true;
            };
        })
    );
in
    {
        pkgs ? pinnedNix
    }: 

        with pkgs;
        with builtins;

        let

            cudatoolkit = cudatoolkit_11_1;
            cudnn       = cudnn_cudatoolkit_11_1;
            python      = python38;
            mpi         = openmpi.override { inherit cudatoolkit; cudaSupport = true; };
            magma       = pkgs.magma.override { inherit cudatoolkit; };
            libuv       = pkgs.libuv;
            hdf5Drv = builtins.import (
                builtins.fetchTarball "https://github.com/eigenfunctor/nix-hdf5-112/archive/master.tar.gz"
            ) { inherit pkgs; };

            hdf5 = hdf5Drv.override {
                inherit stdenv fetchurl removeReferencesTo mpi zlib;
                mpiSupport = true; 
            };

            files = import ./nix/files.nix {
                inherit pkgs python hdf5 mpi zlib cudatoolkit cudnn magma;
            };

            scripts = import ./nix/scripts.nix {
                inherit pkgs hdf5 mpi zlib cudatoolkit cudnn magma libuv;
            };

            helpers = import ./nix/helpers.nix {
                lib = pkgs.lib;
            };

            scriptsList = (map (key: getAttr key scripts) (attrNames scripts));

        in

            args@{
                name ? "pytorch",
                lib ? null,
                requirements ? null,
                buildInputs ? [],
                pythonModules ? [],
                installPhase ? "",
                shellHook ? "",
                ...
            }:

            stdenv.mkDerivation (
                args // {
                    inherit name;

                    buildInputs = [
                        cudatoolkit
                        cudnn
                        hdf5
                        hdf5.dev
                        libuv
                        magma
                        mpi
                        python
                        zlib
                    ] ++ scriptsList ++ buildInputs ;

                    src = lib;

                    phases = "installPhase";

                    installPhase = ''
                        mkdir $out;

                        cp -r $src/* $out/

                        ${installPhase}
                    '';

                    shellHook = ''
                        unset name

                        source ${files.base-env-vars}

                        # Python virtual environment setup
                        echo 'Initializing python virtual environment (this may take a while)...'
                        [ ! -d $(pwd)/.venv ] && ${python}/bin/python -m venv $(pwd)/.venv && mkdir $(pwd)/.venv/repos
                        source $(pwd)/.venv/bin/activate
                        python -m pip install --quiet -U pip
                        [ -z TEMPDIR ] && export TEMPDIR=$(pwd)/.pip-temp
                        [ -z PIP_CACHE_DIR ] && export PIP_CACHE_DIR=$TEMP_DIR
                        python -m pip install --quiet -r ${files.base-pip-requirements}
                        # Install shell user's locally defined pip requirements list
                        ${if (requirements != null) then "python -m pip install --quiet -r ${requirements}" else "# no-op"}

                        # Build h5py with mpi
                        ${scripts.install-h5py-mpi}/bin/install-h5py-mpi


                        ${scripts.install-pytorch}/bin/install-pytorch

                        # Install project python modules and dependencies
                        ${if lib != null then "export PYTHONPATH=$PYTHONPATH:${builtins.toString lib}" else "# no-op"}
                        ${helpers.install-python-modules pythonModules}

                        # Display if Cuda can be used from pytorch
                        echo "Checking if CUDA is available:"
                        ${scripts.check-cuda}/bin/check-cuda

                        ${shellHook}
                    '';

                    requirements = null;
                }
            )
