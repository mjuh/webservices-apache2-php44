{ ref ? "master" }:

with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; inherit ref; }))
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

php44DockerArgHints = lib.phpDockerArgHints { php = php44; };

in 

pkgs.dockerTools.buildLayeredImage rec {
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
      ru.majordomo.docker.arg-hints-json = builtins.toJSON php44DockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd php44DockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = "${apacheHttpd}/bin/httpd -d ${rootfs}/etc/httpd -k graceful";
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
      ln -s /bin usr/bin
      ln -s /bin usr/sbin
      ln -s /bin usr/local/bin
      mkdir tmp
      chmod 1777 tmp
    '';
}
