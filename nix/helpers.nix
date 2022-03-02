{ lib }:

with builtins;
with lib;

{
  # Returns shell command string for taking a list of
  # python module derivation paths and copying them to the virtual env's repos
  # directory. Also updates the PYTHONPATH environment variable
  # with the copied repo's pat.
  install-python-modules = 
    let
      install-python-module =
        (pythonModule: ''

          REPO_PATH=$(pwd)/.venv/repos/$(basename ${pythonModule})

          if [ ! -d $REPO_PATH ]; then
            cp -r ${pythonModule} $REPO_PATH
            chmod -R gu+rw $REPO_PATH
          fi

          export PYTHONPATH=$PYTHONPATH:$REPO_PATH

        '');
    in 
      (pythonModules: concatStrings (map install-python-module pythonModules));
}
