
```nix
torch = (
    (builtins.import
        (fetchTarball "https://github.com/jeff-hykin/pytorch_nixpkg/archive/db4ca5e8ebdeaeae98283a65b94e553735bf5543.tar.gz")
        {
            pkgs = main.packages // {
                cudnn_cudatoolkit_11_1 = main.packages.cudnn_cudatoolkit_11_1;
            };
        }
    )
    ({ name = "torch";})
);
```