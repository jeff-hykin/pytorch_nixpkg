# 
# setup
# 
let 
    # 
    # pick which frozen version of nixpkgs to default to
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
    
    pytorchRepo = pinnedNix.fetchgit {
        url = "https://github.com/pytorch/pytorch.git";
        rev = "56b43f4fec1f76953f15a627694d4bba34588969";
        sha256 = "1cx1r0qadx6c5jbvi9df64ssbdpb11vimysg227364rcbyhdhijv";
        deepClone = true;
    };
    
    hdf5Drv = (pinnedNix.hdf5.overrideAttrs
        (
            oldHdf5: rec {
                pname = "hdf5";
                version = "1.12.0";
                src = builtins.fetchurl {
                    url="https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.12/${pname}-${version}/src/${pname}-${version}.tar.bz2";
                    sha256 = "0qazfslkqbmzg495jafpvqp0khws3jkxa0z7rph9qvhacil6544p";
                };
            }
        )
    );
    
    defaults = {
        pythonModules  = [];
        python         = pinnedNix.python38;
        mpi            = pinnedNix.mpi;
        zlib           = pinnedNix.zlib;
        libuv          = pinnedNix.libuv;
        openmpi        = pinnedNix.openmpi;
        magma          = pinnedNix.magma;
        cudatoolkit    = pinnedNix.cudatoolkit_11_1;
        cudnn          = pinnedNix.cudnn_cudatoolkit_11_1;
        writeText      = pinnedNix.writeText;
        writeTextFile  = pinnedNix.writeTextFile;
        writeScriptBin = pinnedNix.writeScriptBin;
        concatStrings  = pinnedNix.concatStrings;
        stdenv         = pinnedNix.stdenv;
        hdf5           = (hdf5Drv.override
            {
                mpiSupport         = true; 
                stdenv             = pinnedNix.stdenv ;
                fetchurl           = pinnedNix.fetchurl ;
                removeReferencesTo = pinnedNix.removeReferencesTo ;
                mpi                = pinnedNix.mpi ;
                zlib               = pinnedNix.zlib;
            }
        );
    };
# 
# actual function being exported
# 
in
    args@{
        requirements   ? null,
        buildInputs    ? [],
        installPhase   ? "",
        shellHook      ? "",
        cudatoolkit    ? defaults.cudatoolkit   ,
        cudnn          ? defaults.cudnn         ,
        pythonModules  ? defaults.pythonModules ,
        hdf5           ? defaults.hdf5          ,
        python         ? defaults.python        ,
        openmpi        ? defaults.openmpi       ,
        zlib           ? defaults.zlib          ,
        magma          ? defaults.magma         ,
        writeText      ? defaults.writeText     ,
        writeTextFile  ? defaults.writeTextFile ,
        writeScriptBin ? defaults.writeScriptBin,
        concatStrings  ? defaults.concatStrings ,
        lib            ? defaults.lib           ,
        stdenv         ? defaults.stdenv        ,
        ...
    }:
        let
            # push the cuda toolkit into the other tools
            argsWithOverrides = args // {
                requirements =
                    if
                        (args.requirements != null)
                    then
                        ''python -m pip install --quiet -r '${args.requirements}' ''
                    else
                        "# no-op"
                ;
                openmpi = args.openmpi.override {
                    cudaSupport = true; 
                    cudatoolkit = args.cudatoolkit;
                };
                magma = args.magma.override {
                    cudatoolkit = args.cudatoolkit;
                };
            };
            
            paths = {
                basePipRequirements = (argsWithOverrides.writeTextFile 
                    ({
                        name = "requirements.txt";
                        text = (builtins.readFile ./requirements.txt);
                    })
                );
                h5pyMpiInstaller = (argsWithOverrides.writeScriptBin
                    ("install-h5py-mpi")
                    (''
                        #!/usr/bin/env sh

                        export CC="${argsWithOverrides.openmpi}/bin/mpicc"
                        export HDF5_DIR="${argsWithOverrides.hdf5}/"
                        export HDF5_MPI=ON

                        export NUMPY_INCLUDE="$(python -c 'import numpy; print(numpy.get_include())')"
                        export CPATH="$NUMPY_INCLUDE:$CPATH"
                        export CPATH="${argsWithOverrides.hdf5.dev}/include:$CPATH"

                        echo "Checking h5py installation..."
                        python -m pip install --quiet --no-binary=h5py h5py
                        echo "Done checking h5py installation"
                    '')
                );
                pytorchInstaller = (argsWithOverrides.writeScriptBin
                    ("install-pytorch")
                    (''
                        #!/usr/bin/env sh

                        PYTORCH_REPO_DIR="$(pwd)/.venv/repos/$(basename "${pytorchRepo}")"

                        echo "Checking pytorch installation..."
                        [ -d $PYTORCH_REPO_DIR ] && echo "Pytorch already installed" && exit 0

                        cp -r "${pytorchRepo}" "$PYTORCH_REPO_DIR"
                        chmod -R gu+rw "$PYTORCH_REPO_DIR"

                        pushd "$PYTORCH_REPO_DIR"

                        # library paths
                        export CPATH="${argsWithOverrides.hdf5.dev}/include:${argsWithOverrides.openmpi}/include:${argsWithOverrides.cudatoolkit}/include:${argsWithOverrides.cudnn}/include:${argsWithOverrides.magma}/include:${argsWithOverrides.libuv}/include:$CPATH"
                        export LD_LIBRARY_PATH="${argsWithOverrides.hdf5}/lib:${argsWithOverrides.openmpi}/lib:${argsWithOverrides.cudatoolkit}/lib:${argsWithOverrides.cudnn}/lib:${argsWithOverrides.magma}/lib:${argsWithOverrides.libuv}/lib"

                        export CMAKE_PREFIX_PATH="${argsWithOverrides.hdf5}:${argsWithOverrides.hdf5.dev}:${argsWithOverrides.openmpi}:${argsWithOverrides.cudatoolkit}:${argsWithOverrides.cudnn}:${argsWithOverrides.magma}:${argsWithOverrides.libuv}:$CMAKE_PREFIX_PATH"

                        python setup.py install

                        popd
                    '')
                );
                checkCuda = (argsWithOverrides.writeScriptBin
                    ("check-cuda")
                    (''
                        #!/usr/bin/env sh

                        python -c 'import torch; print(torch.cuda.is_available())'
                    '')
                );
                pipFreeze = (argsWithOverrides.writeScriptBin
                    ("pip-freeze")
                    (''
                        #!/usr/bin/env sh

                        python -m pip freeze | grep -v h5py
                    '')
                );
            };
            
            installPythonModules = (argsWithOverrides.concatStrings
                (builtins.map
                    (
                        eachPythonModule:
                            (''
                            
                                REPO_PATH="$(pwd)/.venv/repos/$(basename '${eachPythonModule}')"

                                if [ ! -d $REPO_PATH ]; then
                                    cp -r '${eachPythonModule}' "$REPO_PATH"
                                    chmod -R gu+rw "$REPO_PATH"
                                fi

                                export PYTHONPATH="$PYTHONPATH:$REPO_PATH"
                                
                            '')
                    )
                    (argsWithOverrides.pythonModules)
                )
            );
            
            pythonPathExport = 
                if
                    lib != null
                then
                    "export PYTHONPATH=$PYTHONPATH:${builtins.toString lib}"
                else
                    "# no-op"
            ;
            
            scriptsList = [
                paths.h5pyMpiInstaller
                paths.pytorchInstaller
                paths.pipFreeze
                paths.checkCuda
            ];
            
        in
            (stdenv.mkDerivation
                ({
                    name = "pytorch";

                    buildInputs = [
                        argsWithOverrides.cudatoolkit
                        argsWithOverrides.cudnn
                        argsWithOverrides.hdf5
                        argsWithOverrides.hdf5.dev
                        argsWithOverrides.libuv
                        argsWithOverrides.magma
                        argsWithOverrides.openmpi
                        argsWithOverrides.python
                        argsWithOverrides.zlib
                    ] ++ scriptsList ++ argsWithOverrides.buildInputs ;

                    src = argsWithOverrides.lib;

                    phases = "installPhase";

                    installPhase = ''
                        mkdir "$out";

                        cp -r "$src/"* "$out/"

                        ${argsWithOverrides.installPhase}
                    '';

                    shellHook = ''
                        unset name

                        # Keep track of project directory
                        export PROJECT_DIR="$(pwd)"

                        # Libraries setup
                        [ -z LD_LIBRARY_PATH ] && export LD_LIBRARY_PATH=""
                        export LD_LIBRARY_PATH="${argsWithOverrides.hdf5}:$LD_LIBRARY_PATH"
                        export LD_LIBRARY_PATH="${argsWithOverrides.openmpi}/lib:$LD_LIBRARY_PATH"
                        export LD_LIBRARY_PATH="${argsWithOverrides.python38}/lib:$LD_LIBRARY_PATH"
                        export LD_LIBRARY_PATH="${argsWithOverrides.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"
                        export LD_LIBRARY_PATH="${argsWithOverrides.zlib}/lib:$LD_LIBRARY_PATH"

                        # CUDA and magma path
                        export LD_LIBRARY_PATH="${argsWithOverrides.cudatoolkit}/lib:${argsWithOverrides.cudnn}/lib:${argsWithOverrides.magma}/lib:$LD_LIBRARY_PATH"

                        # Python virtual environment setup
                        echo 'Initializing python virtual environment (this may take a while)...'
                        [ ! -d $(pwd)/.venv ] && ${argsWithOverrides.python}/bin/python -m venv $(pwd)/.venv && mkdir $(pwd)/.venv/repos
                        source $(pwd)/.venv/bin/activate
                        python -m pip install --quiet -U pip
                        [ -z TEMPDIR ] && export TEMPDIR=$(pwd)/.pip-temp
                        [ -z PIP_CACHE_DIR ] && export PIP_CACHE_DIR=$TEMP_DIR
                        python -m pip install --quiet -r '${paths.basePipRequirements}'
                        
                        # Install shell user's locally defined pip requirements list
                        ${argsWithOverrides.requirements}

                        # Build h5py with mpi
                        "${paths.h5pyMpiInstaller}/bin/install-h5py-mpi"


                        "${paths.pytorchInstaller}/bin/install-pytorch"

                        # Install project python modules and dependencies
                        ${pythonPathExport}
                        ${installPythonModules}

                        # Display if Cuda can be used from pytorch
                        echo "Checking if CUDA is available:"
                        "${paths.checkCuda}/bin/check-cuda"

                        ${argsWithOverrides.shellHook}
                    '';

                    requirements = null;
                })
            )