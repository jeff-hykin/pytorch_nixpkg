
```nix
torch = (
    (builtins.import
        (fetchTarball "https://github.com/jeff-hykin/pytorch_nixpkg/archive/b027a611faa4fab58eb1e97bf93b84a30e694909.tar.gz")
        {
            pkgs = main.packages // {
                cudnn_cudatoolkit_11_1 = main.packages.cudnn_cudatoolkit_11_1;
            };
        }
    )
    ({ name = "torch";})
);
```