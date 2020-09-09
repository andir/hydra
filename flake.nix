{
  description = "A Nix-based continuous build system";

  inputs.nixpkgs.url = "nixpkgs/nixos-20.03";

  outputs = { self, nixpkgs, nix }:
    let

      version = "${builtins.readFile ./version}.${builtins.substring 0 8 self.lastModifiedDate}.${self.shortRev or "DIRTY"}";

      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlay nix.overlay ];
      };

      # NixOS configuration used for VM tests.
      hydraServer =
        { config, pkgs, ... }:
        { imports = [ self.nixosModules.hydraTest ];

          virtualisation.memorySize = 1024;
          virtualisation.writableStore = true;

          environment.systemPackages = [ pkgs.perlPackages.LWP pkgs.perlPackages.JSON ];

          nix = {
            # Without this nix tries to fetch packages from the default
            # cache.nixos.org which is not reachable from this sandboxed NixOS test.
            binaryCaches = [];
          };
        };

    in rec {

      # A Nixpkgs overlay that provides a 'hydra' package.
      overlay = final: prev: {

        hydra = with final; let

          perlDeps = buildEnv {
            name = "hydra-perl-deps";
            paths = with perlPackages; lib.closePropagation
              [ ModulePluggable
                CatalystActionREST
                CatalystAuthenticationStoreDBIxClass
                CatalystDevel
                CatalystDispatchTypeRegex
                CatalystPluginAccessLog
                CatalystPluginAuthorizationRoles
                CatalystPluginCaptcha
                CatalystPluginSessionStateCookie
                CatalystPluginSessionStoreFastMmap
                CatalystPluginStackTrace
                CatalystPluginUnicodeEncoding
                CatalystTraitForRequestProxyBase
                CatalystViewDownload
                CatalystViewJSON
                CatalystViewTT
                CatalystXScriptServerStarman
                CatalystXRoleApplicator
                CryptRandPasswd
                DBDPg
                DBDSQLite
                DataDump
                DateTime
                DigestSHA1
                EmailMIME
                EmailSender
                FileSlurp
                IOCompress
                IPCRun
                JSON
                JSONAny
                JSONXS
                LWP
                LWPProtocolHttps
                NetAmazonS3
                NetPrometheus
                NetStatsd
                PadWalker
                Readonly
                SQLSplitStatement
                SetScalar
                Starman
                SysHostnameLong
                TermSizeAny
                TestMore
                TextDiff
                TextTable
                XMLSimple
                YAML
                (buildPerlPackage {
                  pname = "Catalyst-Authentication-Store-LDAP";
                  version = "1.016";
                  src = fetchurl {
                    url = "mirror://cpan/authors/id/I/IL/ILMARI/Catalyst-Authentication-Store-LDAP-1.016.tar.gz";
                    sha256 = "0cm399vxqqf05cjgs1j5v3sk4qc6nmws5nfhf52qvpbwc4m82mq8";
                  };
                  propagatedBuildInputs = [ NetLDAP CatalystPluginAuthentication ClassAccessorFast ];
                  buildInputs = let
                    NetLDAPServerTest = buildPerlPackage {
                      pname = "Net-LDAP-Server-Test";
                      version = "0.22";
                      src = fetchurl {
                        url = "mirror://cpan/authors/id/K/KA/KARMAN/Net-LDAP-Server-Test-0.22.tar.gz";
                        sha256 = "13idip7jky92v4adw60jn2gcc3zf339gsdqlnc9nnvqzbxxp285i";
                      };
                      propagatedBuildInputs = let

                        NetLDAPSID = buildPerlPackage {
                          pname = "Net-LDAP-SID";
                          version = "0.0001";
                          src = fetchurl {
                            url = "mirror://cpan/authors/id/K/KA/KARMAN/Net-LDAP-SID-0.001.tar.gz";
                            sha256 = "1mnnpkmj8kpb7qw50sm8h4sd8py37ssy2xi5hhxzr5whcx0cvhm8";
                          };
                        };

                        NetLDAPServer = buildPerlPackage {
                          pname = "Net-LDAP-Server";
                          version = "0.43";
                          src = fetchurl {
                            url = "mirror://cpan/authors/id/A/AA/AAR/Net-LDAP-Server-0.43.tar.gz";
                            sha256 = "0qmh3cri3fpccmwz6bhwp78yskrb3qmalzvqn0a23hqbsfs4qv6x";
                          };
                          propagatedBuildInputs = [
                            NetLDAP ConvertASN1
                          ];
                        };
                      in [ NetLDAP NetLDAPServer TestMore DataDump NetLDAPSID ];
                      buildInputs = [ ];
                    };
                  in [ TestMore TestMockObject TestException NetLDAPServerTest ];
                })
                final.nix
                final.nix.perl-bindings
                git
              ];
          };

        in stdenv.mkDerivation {

          name = "hydra-${version}";

          src = self;

          buildInputs =
            [ makeWrapper autoconf automake libtool unzip nukeReferences pkgconfig libpqxx
              gitAndTools.topGit mercurial darcs subversion bazaar openssl bzip2 libxslt
              perlDeps perl final.nix
              boost
              postgresql_11
              (if lib.versionAtLeast lib.version "20.03pre"
               then nlohmann_json
               else nlohmann_json.override { multipleHeaders = true; })
            ];

          checkInputs = [
            foreman
          ];

          hydraPath = lib.makeBinPath (
            [ subversion openssh final.nix coreutils findutils pixz
              gzip bzip2 lzma gnutar unzip git gitAndTools.topGit mercurial darcs gnused bazaar
            ] ++ lib.optionals stdenv.isLinux [ rpm dpkg cdrkit ] );

          configureFlags = [ "--with-docbook-xsl=${docbook_xsl}/xml/xsl/docbook" ];

          shellHook = ''
            PATH=$(pwd)/src/hydra-evaluator:$(pwd)/src/script:$(pwd)/src/hydra-eval-jobs:$(pwd)/src/hydra-queue-runner:$PATH
            PERL5LIB=$(pwd)/src/lib:$PERL5LIB
            export HYDRA_HOME="src/"
            mkdir -p .hydra-data
            export HYDRA_DATA="$(pwd)/.hydra-data"
            export HYDRA_DBI='dbi:Pg:dbname=hydra;host=localhost;port=64444'
          '';

          preConfigure = "autoreconf -vfi";

          NIX_LDFLAGS = [ "-lpthread" ];

          enableParallelBuilding = true;

          doCheck = true;

          preCheck = ''
            patchShebangs .
            export LOGNAME=''${LOGNAME:-foo}
          '';

          postInstall = ''
            mkdir -p $out/nix-support

            for i in $out/bin/*; do
                read -n 4 chars < $i
                if [[ $chars =~ ELF ]]; then continue; fi
                wrapProgram $i \
                    --prefix PERL5LIB ':' $out/libexec/hydra/lib:$PERL5LIB \
                    --prefix PATH ':' $out/bin:$hydraPath \
                    --set HYDRA_RELEASE ${version} \
                    --set HYDRA_HOME $out/libexec/hydra \
                    --set NIX_RELEASE ${final.nix.name or "unknown"}
            done
          '';

          dontStrip = true;

          meta.description = "Build of Hydra on ${system}";
          passthru.perlDeps = perlDeps;
        };
      };

      hydraJobs = {

        build.x86_64-linux = packages.x86_64-linux.hydra;

        manual =
          pkgs.runCommand "hydra-manual-${version}" {}
          ''
            mkdir -p $out/share
            cp -prvd ${pkgs.hydra}/share/doc $out/share/

            mkdir $out/nix-support
            echo "doc manual $out/share/doc/hydra" >> $out/nix-support/hydra-build-products
          '';

        tests.install.x86_64-linux =
          with import (nixpkgs + "/nixos/lib/testing-python.nix") { system = "x86_64-linux"; };
          simpleTest {
            machine = hydraServer;
            testScript =
              ''
                machine.wait_for_job("hydra-init")
                machine.wait_for_job("hydra-server")
                machine.wait_for_job("hydra-evaluator")
                machine.wait_for_job("hydra-queue-runner")
                machine.wait_for_open_port("3000")
                machine.succeed("curl --fail http://localhost:3000/")
              '';
          };

        tests.api.x86_64-linux =
          with import (nixpkgs + "/nixos/lib/testing-python.nix") { system = "x86_64-linux"; };
          simpleTest {
            machine = { pkgs, ... }: {
              imports = [ hydraServer ];
              # No caching for PathInput plugin, otherwise we get wrong values
              # (as it has a 30s window where no changes to the file are considered).
              services.hydra-dev.extraConfig = ''
                path_input_cache_validity_seconds = 0
              '';
            };
            testScript =
              let dbi = "dbi:Pg:dbname=hydra;user=root;"; in
              ''
                machine.wait_for_job("hydra-init")

                # Create an admin account and some other state.
                machine.succeed(
                    """
                        su - hydra -c "hydra-create-user root --email-address 'alice@example.org' --password foobar --role admin"
                        mkdir /run/jobset /tmp/nix
                        chmod 755 /run/jobset /tmp/nix
                        cp ${./tests/api-test.nix} /run/jobset/default.nix
                        chmod 644 /run/jobset/default.nix
                        chown -R hydra /run/jobset /tmp/nix
                """
                )

                machine.succeed("systemctl stop hydra-evaluator hydra-queue-runner")
                machine.wait_for_job("hydra-server")
                machine.wait_for_open_port("3000")

                # Run the API tests.
                machine.succeed(
                    "su - hydra -c 'perl -I ${pkgs.hydra.perlDeps}/lib/perl5/site_perl ${./tests/api-test.pl}' >&2"
                )
              '';
        };

        tests.notifications.x86_64-linux =
          with import (nixpkgs + "/nixos/lib/testing-python.nix") { system = "x86_64-linux"; };
          simpleTest {
            machine = { pkgs, ... }: {
              imports = [ hydraServer ];
              services.hydra-dev.extraConfig = ''
                <influxdb>
                  url = http://127.0.0.1:8086
                  db = hydra
                </influxdb>
              '';
              services.influxdb.enable = true;
            };
            testScript = ''
              machine.wait_for_job("hydra-init")

              # Create an admin account and some other state.
              machine.succeed(
                  """
                      su - hydra -c "hydra-create-user root --email-address 'alice@example.org' --password foobar --role admin"
                      mkdir /run/jobset
                      chmod 755 /run/jobset
                      cp ${./tests/api-test.nix} /run/jobset/default.nix
                      chmod 644 /run/jobset/default.nix
                      chown -R hydra /run/jobset
              """
              )

              # Wait until InfluxDB can receive web requests
              machine.wait_for_job("influxdb")
              machine.wait_for_open_port("8086")

              # Create an InfluxDB database where hydra will write to
              machine.succeed(
                  "curl -XPOST 'http://127.0.0.1:8086/query' "
                  + "--data-urlencode 'q=CREATE DATABASE hydra'"
              )

              # Wait until hydra-server can receive HTTP requests
              machine.wait_for_job("hydra-server")
              machine.wait_for_open_port("3000")

              # Setup the project and jobset
              machine.succeed(
                  "su - hydra -c 'perl -I ${pkgs.hydra.perlDeps}/lib/perl5/site_perl ${./tests/setup-notifications-jobset.pl}' >&2"
              )

              # Wait until hydra has build the job and
              # the InfluxDBNotification plugin uploaded its notification to InfluxDB
              machine.wait_until_succeeds(
                  "curl -s -H 'Accept: application/csv' "
                  + "-G 'http://127.0.0.1:8086/query?db=hydra' "
                  + "--data-urlencode 'q=SELECT * FROM hydra_build_status' | grep success"
              )
            '';
        };

        tests.ldap.x86_64-linux =
          with import (nixpkgs + "/nixos/lib/testing-python.nix") { system = "x86_64-linux"; };
          makeTest {
            machine = { pkgs, ... }: {
              imports = [ hydraServer ];

              services.openldap = {
                enable = true;
                suffix = "dc=example";
                rootdn = "cn=root,dc=example";
                rootpw = "notapassword";
                database = "bdb";
                dataDir = "/var/lib/openldap";
                extraDatabaseConfig = ''
                '';

                declarativeContents = ''
                  dn: dc=example
                  dc: example
                  o: Root
                  objectClass: top
                  objectClass: dcObject
                  objectClass: organization

                  dn: ou=users,dc=example
                  ou: users
                  description: All users
                  objectClass: top
                  objectClass: organizationalUnit

                  dn: cn=user,ou=users,dc=example
                  objectClass: organizationalPerson
                  objectClass: inetOrgPerson
                  sn: user
                  cn: user
                  mail: user@example
                  userPassword: foobar
                '';
              };
              systemd.services.hdyra-server.environment.CATALYST_DEBUG = "1";
              systemd.services.hydra-server.environment.HYDRA_LDAP_CONFIG = pkgs.writeText "config.yaml"
                # example config based on https://metacpan.org/source/ILMARI/Catalyst-Authentication-Store-LDAP-1.016/README#L103
                ''
                  credential:
                    class: Password
                    password_field: password
                    password_type: self_check
                  store:
                    class: LDAP
                    ldap_server: localhost
                    ldap_server_options.timeout: 30
                    binddn: "cn=root,dc=example"
                    bindpw: notapassword
                    start_tls: 0
                    start_tls_options.verify:  none
                    user_basedn: "ou=users,dc=example"
                    user_filter: "(&(objectClass=inetOrgPerson)(cn=%s))"
                    user_scope: one
                    user_field: cn
                    user_search_options:
                      deref: always
                    use_roles: 0
                    role_basedn: "ou=groups,ou=OxObjects,dc=yourcompany,dc=com"
                    role_filter: "(&(objectClass=posixGroup)(memberUid=%s))"
                    role_scope: one
                    role_field: uid
                    role_value: dn
                    role_search_options:
                      deref: always
                  '';
              networking.firewall.enable = false;
            };
            testScript = ''
              machine.wait_for_unit("openldap.service")
              machine.wait_for_job("hydra-init")
              machine.wait_for_open_port("3000")
              machine.succeed(
                  "curl --fail http://localhost:3000/login -H 'Accept: application/json' -H 'Referer: http://localhost:3000' --data 'username=user&password=foobar'"
              )
              machine.fail(
                  "curl --fail http://localhost:3000/login -H 'Accept: application/json' -H 'Referer: http://localhost:3000' --data 'username=user&password=wrongpassword'"
              )
            '';
          };

        container = nixosConfigurations.container.config.system.build.toplevel;
      };

      checks.x86_64-linux.build = hydraJobs.build.x86_64-linux;
      checks.x86_64-linux.install = hydraJobs.tests.install.x86_64-linux;

      packages.x86_64-linux.hydra = pkgs.hydra;
      defaultPackage.x86_64-linux = pkgs.hydra;

      nixosModules.hydra = {
        imports = [ ./hydra-module.nix ];
        nixpkgs.overlays = [ self.overlay nix.overlay ];
      };

      nixosModules.hydraTest = {
        imports = [ self.nixosModules.hydra ];

        services.hydra-dev.enable = true;
        services.hydra-dev.hydraURL = "http://hydra.example.org";
        services.hydra-dev.notificationSender = "admin@hydra.example.org";

        systemd.services.hydra-send-stats.enable = false;

        services.postgresql.enable = true;
        services.postgresql.package = pkgs.postgresql_11;

        # The following is to work around the following error from hydra-server:
        #   [error] Caught exception in engine "Cannot determine local time zone"
        time.timeZone = "UTC";

        nix.extraOptions = ''
          allowed-uris = https://github.com/
        '';
      };

      nixosModules.hydraProxy = {
        services.httpd = {
          enable = true;
          adminAddr = "hydra-admin@example.org";
          extraConfig = ''
            <Proxy *>
              Order deny,allow
              Allow from all
            </Proxy>

            ProxyRequests     Off
            ProxyPreserveHost On
            ProxyPass         /apache-errors !
            ErrorDocument 503 /apache-errors/503.html
            ProxyPass         /       http://127.0.0.1:3000/ retry=5 disablereuse=on
            ProxyPassReverse  /       http://127.0.0.1:3000/
          '';
        };
      };

      nixosConfigurations.container = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules =
          [ self.nixosModules.hydraTest
            self.nixosModules.hydraProxy
            { system.configurationRevision = self.rev;

              boot.isContainer = true;
              networking.useDHCP = false;
              networking.firewall.allowedTCPPorts = [ 80 ];
              networking.hostName = "hydra";

              services.hydra-dev.useSubstitutes = true;
            }
          ];
      };

    };
}
