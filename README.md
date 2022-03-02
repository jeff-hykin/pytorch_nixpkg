
```nix
torch = (
    (builtins.import
        (fetchTarball "https://github.com/jeff-hykin/pytorch_nixpkg/archive/03c3e67807828d86d60ed544925096973a3d7fc3.tar.gz")
        {
            pkgs = main.packages // {
                cudnn_cudatoolkit_11_1 = main.packages.cudnn_cudatoolkit_11_1;
            };
        }
    )
    ({ name = "torch";})
);
```