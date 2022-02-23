{ nixpkgs ? (import ./common.nix).nixpkgs }:

with nixpkgs;

let
  domain = "php44.ru";
  phpVersion = "php" + lib.versions.major php44.version
    + lib.versions.minor php44.version;
  containerStructureTestConfig = ./tests/container-structure-test.yaml;
  image = callPackage ./default.nix { inherit nixpkgs; };

in maketestPhp {
  php = php44;
  inherit image;
  rootfs = ./rootfs;
  inherit containerStructureTestConfig;
  testSuite = [
    (dockerNodeTest {
      description = "Copy phpinfo.";
      action = "execute";
      command = "cp -v ${phpinfo} /home/u12/${domain}/www/phpinfo.php";
    })
    (dockerNodeTest {
      description = "Fetch phpinfo.";
      action = "succeed";
      command = runCurl "http://${domain}/phpinfo.php"
        "/tmp/xchg/coverage-data/phpinfo.html";
    })
    (dockerNodeTest {
      description = "Fetch server-status.";
      action = "succeed";
      command = runCurl "http://127.0.0.1/server-status"
        "/tmp/xchg/coverage-data/server-status.html";
    })
    (dockerNodeTest {
      description = "Copy JSON.php.";
      action = "succeed";
      command = "cp -v ${./tests/JSON.php} /home/u12/${domain}/www/JSON.php";
    })
    (dockerNodeTest {
      description = "Copy phpinfo-json.php.";
      action = "succeed";
      command =
        "cp -v ${./tests/phpinfo-json.php} /home/u12/${domain}/www/phpinfo-json.php";
    })
    (dockerNodeTest {
      description = "Fetch phpinfo-json.php.";
      action = "succeed";
      command = runCurl "http://${domain}/phpinfo-json.php"
        "/tmp/xchg/coverage-data/phpinfo.json";
    })
    (dockerNodeTest {
      description = "Run deepdiff against PHP on Upstart.";
      action = "succeed";
      command = testDiffPy {
        inherit pkgs;
        sampleJson = (./tests/. + "/${phpVersion}.json");
        output = "/tmp/xchg/coverage-data/deepdiff.json";
      };
    })
    (dockerNodeTest {
      description = "Run deepdiff against PHP on Upstart with excludes.";
      action = "succeed";
      command = testDiffPy {
        inherit pkgs;
        sampleJson = (./tests/. + "/${phpVersion}.json");
        output = "/tmp/xchg/coverage-data/deepdiff-with-excludes.json";
        excludes = import ./tests/diff-to-skip.nix;
      };
    })
    (dockerNodeTest {
      description = "Copy bitrix_server_test.php.";
      action = "succeed";
      command =
        "cp -v ${bitrixServerTest} /home/u12/${domain}/www/bitrix_server_test.php";
    })
    (dockerNodeTest {
      description = "Run Bitrix test.";
      action = "succeed";
      command = runCurl "http://${domain}/bitrix_server_test.php"
        "/tmp/xchg/coverage-data/bitrix_server_test.html";
    })
    (dockerNodeTest {
      description = "Run container structure test.";
      action = "succeed";
      command = containerStructureTest {
        inherit image pkgs;
        config = containerStructureTestConfig;
      };
    })
    (dockerNodeTest {
      description = "Copy parser3.cgi";
      action = "succeed";
      command = "cp -v ${parser3}/parser3.cgi /home/u12/${domain}/www/parser3.cgi";
    })
    (dockerNodeTest {
      description = "help parser3.cgi";
      action = "succeed";
      command = ''#!{bash}/bin/bash
          docker exec `docker ps --format '{{ .Names }}' ` /home/u12/${domain}/www/parser3.cgi -h | grep Parser
      '';
    })
    (dockerNodeTest {
      description = "Perl version";
      action = "succeed";
      command = ''#!{bash}/bin/bash
          docker exec `docker ps --format '{{ .Names }}' ` perl -v | grep 'v5.20'
      '';
    })
    (dockerNodeTest {
      description = "Spiner test";
      action = "succeed";
      command = runCurlGrep "127.0.0.1" "refresh";
    })
    (dockerNodeTest {
      description = "404 test";
      action = "succeed";
      command = runCurlGrep "127.0.0.1/non-existent" "' 404'";
    })
    (dockerNodeTest {
      description = "404 mj-error test";
      action = "succeed";
      command = runCurlGrep "127.0.0.1/non-existent" "majordomo";
    })
    (dockerNodeTest {
      description = "Copy mysqlconnect.php";
      action = "succeed";
      command = "cp -v ${./tests/mysqlconnect.php} /home/u12/${domain}/www/mysqlconnect.php";
    })
    (dockerNodeTest {
      description = "Test mysqlconnect with old password hash";
      action = "succeed";
      command = "curl http://${domain}/mysqlconnect.php | grep success";
    })
    (dockerNodeTest {
      description = "deepdiff iterable_item_removed";
      action = "succeed";
      command = "jq .iterable_item_removed /tmp/xchg/coverage-data/deepdiff-with-excludes.json | grep null ";
    })
  ];
} { }
