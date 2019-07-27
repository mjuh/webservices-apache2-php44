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

  php4 = stdenv.mkDerivation rec {
      name = "php-4.4.9";
      sha256 = "1hjn2sdm8sn8xsd1y5jlarx3ddimdvm56p1fxaj0ydm3dgah5i9a";
      enableParallelBuilding = true;
      nativeBuildInputs = [ pkgconfig autoconf213 ];
      hardeningDisable = [ "fortify" "stackprotector" "pie" "pic" "strictoverflow" "format" "relro" "bindnow" ];
      srcs = [
             ( fetchurl {
                 url = "https://museum.php.net/php4/php-4.4.9.tar.bz2";
                 inherit sha256;
             })
             ./src/ext/standard
      ];
      sourceRoot = "php-4.4.9";
      patches = [
                 ./patch/php4/mj/php4-apache24.patch
                 ./patch/php4/mj/php4-openssl.patch
                 ./patch/php4/mj/php4-domxml.patch
                 ./patch/php4/mj/php4-pcre.patch
                 ./patch/php4/mj/apxs.patch
      ];
      stripDebugList = "bin sbin lib modules";
      outputs = [ "out" ];
      doCheck = false;
      checkTarget = "test";
      buildInputs = [
         autoconf213
         automake
         pkgconfig
         curl
         apacheHttpd.dev
         bison
         bzip2
         flex
         freetype
         gettext
         icu
         libzip
         libjpegv6b
         libmcrypt
         libmhash
         libpng12
         libxml2
         libsodium
         icu.dev
         xorg.libXpm.dev
         libxslt
         connectorc
         pam
         expat
         pcre831
         postgresql
         readline
         sqlite
         uwimap
         zlib
         libiconv
         t1lib
         libtidy
         kerberos
         openssl
         glibc.dev
         glibcLocales
         sablotron
      ];
      CXXFLAGS = "-std=c++11";
      configureFlags = ''
       --disable-maintainer-zts
       --disable-pthreads
       --disable-fpm
       --disable-cgi
       --disable-phpdbg
       --disable-debug
       --disable-memcached-sasl
       --enable-pdo
       --enable-dom
       --enable-inline-optimization
       --enable-dba
       --enable-bcmath
       --enable-soap
       --enable-sockets
       --enable-zip
       --enable-exif
       --enable-ftp
       --enable-mbstring=ru
       --enable-calendar
       --enable-timezonedb
       --enable-gd-native-ttf
       --enable-sysvsem
       --enable-sysvshm
       --enable-opcache
       --enable-wddx
       --enable-magic-quotes
       --enable-memory-limit
       --enable-local-infile
       --enable-force-cgi-redirect
       --enable-xslt
       --enable-dbase
       --with-iconv
       --with-dbase
       --with-xslt-sablot=${sablotron}
       --with-xslt
       --with-expat-dir=${expat}
       --with-kerberos
       --with-ttf
       --with-config-file-scan-dir=/etc/php.d
       --with-pcre-regex=${pcre831}
       --with-imap=${uwimap}
       --with-imap-ssl
       --with-mhash=${libmhash}
       --with-libzip
       --with-curl=${curl.dev}
       --with-curlwrappers
       --with-zlib=${zlib.dev}
       --with-readline=${readline.dev}
       --with-pdo-sqlite=${sqlite.dev}
       --with-pgsql=${postgresql}
       --with-pdo-pgsql=${postgresql}
       --with-gd
       --with-freetype-dir=${freetype.dev}
       --with-png-dir=${libpng12}
       --with-jpeg-dir=${libjpegv6b}
       --with-openssl
       --with-gettext=${glibc.dev}
       --with-xsl=${libxslt.dev}
       --with-mcrypt=${libmcrypt}
       --with-bz2=${bzip2.dev}
       --with-sodium=${libsodium.dev}
       --with-tidy=${html-tidy}
       --with-password-argon2=${libargon2}
       --with-apxs2=${apacheHttpd.dev}/bin/apxs
       --with-mysql=${connectorc}
       --with-dom=${libxml2.dev}
       --with-dom-xslt=${libxslt.dev}
       '';
      preConfigure = ''
        cp -pr ../standard/* ext/standard
        # Don't record the configure flags since this causes unnecessary
        # runtime dependencies
        for i in main/build-defs.h.in scripts/php-config.in; do
          substituteInPlace $i \
            --replace '@CONFIGURE_COMMAND@' '(omitted)' \
            --replace '@CONFIGURE_OPTIONS@' "" \
            --replace '@PHP_LDFLAGS@' ""
        done
        [[ -z "$libxml2" ]] || addToSearchPath PATH $libxml2/bin
        export EXTENSION_DIR=$out/lib/php/extensions
        configureFlags+=(--with-config-file-path=$out/etc \
          --includedir=$dev/include)
        ./buildconf --force
      '';
      postInstall = ''
          sed -i $out/include/php/main/build-defs.h -e '/PHP_INSTALL_IT/d'
      '';     
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
    environment = { HTTPD_PORT = "$SOCKET_HTTP_PORT"; PHP_INI_SCAN_DIR = ":${rootfs}/etc/phpsec/$SECURITY_LEVEL"; };
    tmpfs = [
      "/tmp:mode=1777"
      "/run/bin:exec,suid"
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