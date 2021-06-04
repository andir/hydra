{ counter }:
with import ./config.nix;
{
  job = mkDerivation {
    name = "job-${counter}";
    builder = "/bin/sh";
    args = [
      (builtins.toFile "builder.sh" ''
        #! /bin/sh

        echo ${counter} > $out
      '')
    ];
  };
}
