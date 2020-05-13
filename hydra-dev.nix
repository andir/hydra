{ foreman, mkShell, hydra, docbook_xsl }:

(hydra.overrideAttrs (old: {
#  NIX_LDFLAGS = [ "-lpthread" ];
#  configureFlags = [ "--with-docbook-xsl=${docbook_xsl}/xml/xsl/docbook" ];
  buildInputs = old.buildInputs ++ [
    foreman
  ];

  shellHook = ''
    PATH=$(pwd)/src/hydra-evaluator:$(pwd)/src/script:$(pwd)/src/hydra-eval-jobs:$(pwd)/src/hydra-queue-runner:$PATH
    PERL5LIB=$(pwd)/src/lib:$PERL5LIB
    export HYDRA_HOME="src/"
    mkdir -p .hydra-data
    export HYDRA_DATA="$(pwd)/.hydra-data"
    export HYDRA_DBI='dbi:Pg:dbname=hydra;host=localhost;'
  '';

}))
