with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; ref = "master"; }))
  ];
};


let

inherit (builtins) concatMap getEnv toJSON;
inherit (dockerTools) buildLayeredImage;
inherit (lib) concatMapStringsSep firstNChars flattenSet dockerRunCmd buildPhpPackage mkRootfs;
inherit (lib.attrsets) collect isDerivation;
inherit (stdenv) mkDerivation;

  locale = glibcLocales.override {
      allLocales = false;
      locales = ["en_US.UTF-8/UTF-8"];
  };

sh = dash.overrideAttrs (_: rec {
  postInstall = ''
    ln -s dash "$out/bin/sh"
  '';
});

  zendoptimizer = stdenv.mkDerivation rec {
      name = "zend-optimizer-3.3.9";
      src =  fetchurl {
          url = "http://downloads.zend.com/optimizer/3.3.9/ZendOptimizer-3.3.9-linux-glibc23-x86_64.tar.gz";
          sha256 = "1f7c7p9x9p2bjamci04vr732rja0l1279fvxix7pbxhw8zn2vi1d";
      };
      installPhase = ''
                  mkdir -p  $out/
                  tar zxvf  ${src} -C $out/ ZendOptimizer-3.3.9-linux-glibc23-x86_64/data/4_4_x_comp/ZendOptimizer.so
      '';
  };

  pcre831 = stdenv.mkDerivation rec {
      name = "pcre-8.31";
      src = fetchurl {
          url = "https://ftp.pcre.org/pub/pcre/${name}.tar.bz2";
          sha256 = "0g4c0z4h30v8g8qg02zcbv7n67j5kz0ri9cfhgkpwg276ljs0y2p";
      };
      outputs = [ "out" ];
      configureFlags = ''
          --enable-jit
      '';
  };

  libjpegv6b = stdenv.mkDerivation rec {
     name = "libjpeg-6b";
     src = fetchurl {
         url = "http://www.ijg.org/files/jpegsrc.v6b.tar.gz";
         sha256 = "0pg34z6rbkk5kvdz6wirf7g4mdqn5z8x97iaw17m15lr3qjfrhvm";
     };
     buildInputs = [ nasm libtool autoconf213 coreutils ];
     doCheck = true;
     checkTarget = "test";
     configureFlags = ''
          --enable-static
          --enable-shared
     '';
     preBuild = ''
          mkdir -p $out/lib
          mkdir -p $out/bin
          mkdir -p $out/man/man1
          mkdir -p $out/include
     '';
     preInstall = ''
          mkdir -p $out/lib
          mkdir -p $out/bin
          mkdir -p $out/man/man1
          mkdir -p $out/include
     '';
      patches = [
       ./patch/jpeg6b.patch
      ];
  };

  libpng12 = stdenv.mkDerivation rec {
     name = "libpng-1.2.59";
     src = fetchurl {
        url = "mirror://sourceforge/libpng/${name}.tar.xz";
        sha256 = "b4635f15b8adccc8ad0934eea485ef59cc4cae24d0f0300a9a941e51974ffcc7";
     };
     buildInputs = [ zlib ];
     doCheck = true;
     checkTarget = "test";
  };

  connectorc = stdenv.mkDerivation rec {
     name = "mariadb-connector-c-${version}";
     version = "6.1.0";

     src = fetchurl {
         url = "https://downloads.mysql.com/archives/get/file/mysql-connector-c-6.1.0-src.tar.gz";
         sha256 = "0cifddg0i8zm8p7cp13vsydlpcyv37mz070v6l2mnvy0k8cng2na";
         name   = "mariadb-connector-c-${version}-src.tar.gz";
     };

  # outputs = [ "dev" "out" ]; FIXME: cmake variables don't allow that < 3.0
     cmakeFlags = [
            "-DWITH_EXTERNAL_ZLIB=ON"
            "-DMYSQL_UNIX_ADDR=/run/mysqld/mysqld.sock"
     ];

  # The cmake setup-hook uses $out/lib by default, this is not the case here.
     preConfigure = stdenv.lib.optionalString stdenv.isDarwin ''
             cmakeFlagsArray+=("-DCMAKE_INSTALL_NAME_DIR=$out/lib/mariadb")
     '';

     nativeBuildInputs = [ cmake ];
     propagatedBuildInputs = [ openssl zlib ];
     buildInputs = [ libiconv ];
     enableParallelBuilding = true;
  };

rootfs = mkRootfs {
  name = "apache2-php4-rootfs";
  src = ./rootfs;
  inherit curl coreutils findutils apacheHttpdmpmITK apacheHttpd mjHttpErrorPages php4 postfix s6 execline zendoptimizer connectorc mjperl5Packages;
  ioncube = ioncube.v44;
  s6PortableUtils = s6-portable-utils;
  s6LinuxUtils = s6-linux-utils;
  mimeTypes = mime-types;
  libstdcxx = gcc-unwrapped.lib;
};

dockerArgHints = {
    init = false;
    read_only = true;
    network = "host";
    environment = { HTTPD_PORT = "$SOCKET_HTTP_PORT"; PHP_INI_SCAN_DIR = ":${rootfs}/etc/phpsec/$SECURITY_LEVEL"; PHP_SECURITY = "${rootfs}/etc/phpsec/$SECURITY_LEVEL"; };
    tmpfs = [
      "/tmp:mode=1777"
      "/run/bin:exec,suid"
      "/run/php.d:mode=644"
    ];
    ulimits = [
      { name = "stack"; hard = -1; soft = -1; }
    ];
    security_opt = [ "apparmor:unconfined" ];
    cap_add = [ "SYS_ADMIN" ];
    volumes = [
      ({ type = "bind"; source =  "$SITES_CONF_PATH" ; target = "/read/sites-enabled"; read_only = true; })
      ({ type = "bind"; source =  "/etc/passwd" ; target = "/etc/passwd"; read_only = true; })
      ({ type = "bind"; source =  "/etc/group" ; target = "/etc/group"; read_only = true; })
      ({ type = "bind"; source = "/opcache"; target = "/opcache"; })
      ({ type = "bind"; source = "/home"; target = "/home"; })
      ({ type = "bind"; source = "/opt/postfix/spool/maildrop"; target = "/var/spool/postfix/maildrop"; })
      ({ type = "bind"; source = "/opt/postfix/spool/public"; target = "/var/spool/postfix/public"; })
      ({ type = "bind"; source = "/opt/postfix/lib"; target = "/var/lib/postfix"; })
      ({ type = "tmpfs"; target = "/run"; })
    ];
  };

gitAbbrev = firstNChars 8 (getEnv "GIT_COMMIT");

in 

pkgs.dockerTools.buildLayeredImage rec {
  maxLayers = 124;
  name = "docker-registry.intr/webservices/apache2-php4";
  tag = if gitAbbrev != "" then gitAbbrev else "latest";
  contents = [
    rootfs
    tzdata
    locale
    postfix
    sh
    coreutils
    perl
         perlPackages.TextTruncate
         perlPackages.TimeLocal
         perlPackages.PerlMagick
         perlPackages.commonsense
         perlPackages.Mojolicious
         perlPackages.base
         perlPackages.libxml_perl
         perlPackages.libnet
         perlPackages.libintl_perl
         perlPackages.LWP
         perlPackages.ListMoreUtilsXS
         perlPackages.LWPProtocolHttps
         perlPackages.DBI
         perlPackages.DBDmysql
         perlPackages.CGI
         perlPackages.FilePath
         perlPackages.DigestPerlMD5
         perlPackages.DigestSHA1
         perlPackages.FileBOM
         perlPackages.GD
         perlPackages.LocaleGettext
         perlPackages.HashDiff
         perlPackages.JSONXS
         perlPackages.POSIXstrftimeCompiler
         perlPackages.perl
  ];
# ++ collect isDerivation php4Packages;
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
    };
  };
}
