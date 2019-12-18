{}:

with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; ref = (if builtins ? getEnv then builtins.getEnv "GIT_BRANCH" else "master"); }))
  ];
};

let

inherit (builtins) concatMap getEnv replaceStrings toJSON;
inherit (dockerTools) buildLayeredImage;
inherit (lib) concatMapStringsSep firstNChars flattenSet dockerRunCmd mkRootfs;
inherit (lib.attrsets) collect isDerivation;
inherit (stdenv) mkDerivation;

rootfs = mkRootfs {
  name = "apache2-php44-rootfs";
  src = ./rootfs;
  inherit curl coreutils findutils apacheHttpdmpmITK apacheHttpd mjHttpErrorPages php44 sendmail s6 execline zlib;
  mjperl5Packages = mjperl5lib;
  ioncube = ioncube.v44;
  zendoptimizer = zendoptimizer.v44;
  s6PortableUtils = s6-portable-utils;
  s6LinuxUtils = s6-linux-utils;
  mimeTypes = mime-types;
  libstdcxx = gcc-unwrapped.lib;
};

dockerArgHints = {
    init = false;
    read_only = true;
    network = "host";
    environment = { HTTPD_PORT = "$SOCKET_HTTP_PORT"; PHP_SECURITY = "${rootfs}/etc/phpsec/$SECURITY_LEVEL"; };
    tmpfs = [
      "/tmp:mode=1777"
      "/run/bin:exec,suid"
      "/run/php44.d:mode=644"
    ];
    ulimits = [
      { name = "stack"; hard = -1; soft = -1; }
    ];
    security_opt = [ "apparmor:unconfined" ];
    cap_add = [ "SYS_ADMIN" ];
    volumes = [
      ({ type = "bind"; source =  "$SITES_CONF_PATH" ; target = "/read/sites-enabled"; read_only = true; })
      ({ type = "bind"; source =  "/opt/etc"; target = "/opt/etc"; read_only = true;})
      ({ type = "bind"; source = "/opcache"; target = "/opcache"; })
      ({ type = "bind"; source = "/home"; target = "/home"; })
      ({ type = "bind"; source = "/opt/postfix/spool/maildrop"; target = "/var/spool/postfix/maildrop"; })
      ({ type = "bind"; source = "/opt/postfix/spool/public"; target = "/var/spool/postfix/public"; })
      ({ type = "bind"; source = "/opt/postfix/lib"; target = "/var/lib/postfix"; })
      ({ type = "tmpfs"; target = "/run"; })
    ];
  };

gitAbbrev = firstNChars 8 (getEnv "GIT_COMMIT");
gitCommit = (getEnv "GIT_COMMIT");
jenkinsBuildUrl = (getEnv "BUILD_URL");
jenkinsJobName = (getEnv "JOB_NAME");
jenkinsBranchName = (getEnv "BRANCH_NAME");
gitlabCommitUrl = "https://gitlab.intr/" + (replaceStrings [jenkinsBranchName ""] ["" ""] jenkinsJobName) + "/commit/" + gitCommit;
in 

pkgs.dockerTools.buildLayeredImage rec {
  maxLayers = 124;
  name = "docker-registry.intr/webservices/apache2-php44";
  tag = "latest";
  contents = [
    rootfs
    tzdata
    locale
    sendmail
    sh
    coreutils
    libjpeg_turbo
    jpegoptim
    (optipng.override{ inherit libpng ;})
    gifsicle nss-certs.unbundled zip
    gcc-unwrapped.lib
    glibc
    zlib
    apacheHttpd
    perl520
    mariadbConnectorC
  ]
  ++ collect isDerivation mjperl5Packages ;
# ++ collect isDerivation php44Packages;
  config = {
    Entrypoint = [ "${rootfs}/init" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=${tzdata}/share/zoneinfo"
      "LOCALE_ARCHIVE_2_27=${locale}/lib/locale/locale-archive"
      "LC_ALL=en_US.UTF-8"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.arg-hints-json = builtins.toJSON dockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd dockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = "${apacheHttpd}/bin/httpd -d ${rootfs}/etc/httpd -k graceful";
      ru.majordomo.ci.jenkins.build.url = if jenkinsBuildUrl != "" then jenkinsBuildUrl + "console" else "none";
      ru.majordomo.ci.gitlab.commit.url = if gitlabCommitUrl != "" then gitlabCommitUrl else "none";
    };
  };
    extraCommands = ''
      set -xe
      ls
      mkdir -p etc
      mkdir -p bin
      mkdir -p usr
      chmod u+w usr
      mkdir -p usr/local
      mkdir -p opt
      ln -s ${php44} opt/php4
      ln -s ${php44} opt/php44 
      ln -s /bin usr/sbin
      ln -s /bin usr/local/bin
    '';

}
