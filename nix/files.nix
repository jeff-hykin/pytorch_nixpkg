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

    hdf5WithOverrides = (hdf5Drv.override
        {
            mpiSupport         = true; 
            stdenv             = pinnedNix.stdenv ;
            fetchurl           = pinnedNix.fetchurl ;
            removeReferencesTo = pinnedNix.removeReferencesTo ;
            mpi                = pinnedNix.mpi ;
            zlib               = pinnedNix.zlib;
        }
    );
    
    defaults = {
        stdenv        = pinnedNix.stdenv;
        hdf5          = hdf5WithOverrides;
        python        = pinnedNix.python38;
        mpi           = pinnedNix.mpi;
        zlib          = pinnedNix.zlib;
        libuv         = pinnedNix.libuv;
        openmpi       = pinnedNix.openmpi;
        magma         = pinnedNix.magma;
        cudatoolkit   = pinnedNix.cudatoolkit_11_1;
        cudnn         = pinnedNix.cudnn_cudatoolkit_11_1;
        stdenv        = pinnedNix.stdenv;
    };
# 
# actual function being exported
# 
in
    args@{
        stdenv        ? defaults.stdenv         ,
        hdf5          ? defaults.hdf5           ,
        python        ? defaults.python         ,
        openmpi       ? defaults.openmpi        ,
        zlib          ? defaults.zlib           ,
        cudatoolkit   ? defaults.cudatoolkit    ,
        cudnn         ? defaults.cudnn          ,
        magma         ? defaults.magma          ,
        stdev         ? defaults.stdev          ,
        ...
    }:
        let
            # push the cuda toolkit into the other tools
            argsWithOverrides = args // {
                openmpi = openmpi.override {
                    cudaSupport = true; 
                    cudatoolkit = cudatoolkit;
                };
                magma = magma.override {
                    cudatoolkit = cudatoolkit;
                };
            };
        in
            {
                base-env-vars = (pinnedNix.writeText
                    ("base-env-vars")
                    (''
                        # Keep track of project directory
                        export PROJECT_DIR="$(pwd)"

                        # Libraries setup
                        [ -z LD_LIBRARY_PATH ] && export LD_LIBRARY_PATH=""
                        export LD_LIBRARY_PATH="${argsWithOverrides.hdf5}:$LD_LIBRARY_PATH"
                        export LD_LIBRARY_PATH="${argsWithOverrides.openmpi}/lib:$LD_LIBRARY_PATH"
                        export LD_LIBRARY_PATH="${argsWithOverrides.python}/lib:$LD_LIBRARY_PATH"
                        export LD_LIBRARY_PATH="${argsWithOverrides.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"
                        export LD_LIBRARY_PATH="${argsWithOverrides.zlib}/lib:$LD_LIBRARY_PATH"

                        # CUDA and magma path
                        export LD_LIBRARY_PATH="${argsWithOverrides.cudatoolkit}/lib:${argsWithOverrides.cudnn}/lib:${argsWithOverrides.magma}/lib:$LD_LIBRARY_PATH"
                    '')
                );

                base-pip-requirements = pinnedNix.writeTextFile {
                    name = "requirements.txt";
                    text = (builtins.readFile ./requirements.txt);
                };
            }
