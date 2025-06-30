{ lib
, stdenv
, fetchFromGitHub
, makeWrapper
, python3
, python3Packages
, zip
, git
}:

stdenv.mkDerivation {
  pname = "linux-entra-sso";
  version = "v1.4.0-dev";

  src = fetchFromGitHub {
    owner = "siemens";
    repo = "linux-entra-sso";
    rev = "2a847cdd6d54add98687f219620a218a85ad4d66";
    hash = "sha256-ttzkOElzCu3z18uDxfL8879+mFi7SawWUuu2MKgGUVA=";
  };

  nativeBuildInputs = [
    makeWrapper
    zip
    git
    python3
  ];

  buildInputs = [
    python3
    python3Packages.pygobject3
    python3Packages.pydbus
  ];

  patchPhase = ''
    # Fix paths for Nix environment
    substituteInPlace Makefile \
      --replace "/usr/local" "$out" \
      --replace "/usr/bin/python3" "${python3}/bin/python3"

    # Disable git commands that would fail in build sandbox
    substituteInPlace Makefile \
      --replace '$(shell git describe --match "v[0-9].[0-9]*" --dirty)' "v1.4.0-nix" \
      --replace '$(shell echo $(RELEASE_TAG) | sed -e s:^v::)' "1.4.0-nix"
  '';

  buildPhase = ''
    echo "Building linux-entra-sso extensions and package..."

    # The Makefile's package target builds both Firefox and Chrome extensions
    # It creates build/Linux-Entra-SSO-*.firefox.xpi and build/Linux-Entra-SSO-*.chrome.zip
    make package

    # List what was actually built for debugging
    echo "Built files:"
    find build -name "*.xpi" -o -name "*.zip" | sort
  '';

  installPhase = ''
    echo "Installing linux-entra-sso..."

    # Install native messaging host
    make install DESTDIR=$out prefix="" \
      python3_bin=${python3}/bin/python3 \
      firefox_nm_dir=lib/mozilla/native-messaging-hosts \
      chrome_nm_dir=etc/opt/chrome/native-messaging-hosts \
      chromium_nm_dir=etc/chromium/native-messaging-hosts \
      chrome_ext_dir=share/google-chrome/extensions

    # Install browser extensions
    mkdir -p $out/share/linux-entra-sso/{firefox,chrome,extensions}

    # Copy all built extensions to a general directory
    if ls build/*.xpi 1> /dev/null 2>&1; then
      cp build/*.xpi $out/share/linux-entra-sso/extensions/
    fi
    if ls build/*.zip 1> /dev/null 2>&1; then
      cp build/*.zip $out/share/linux-entra-sso/extensions/
    fi

    # Install Firefox extension with a predictable name
    if ls build/Linux-Entra-SSO-*.firefox.xpi 1> /dev/null 2>&1; then
      cp build/Linux-Entra-SSO-*.firefox.xpi $out/share/linux-entra-sso/firefox/linux-entra-sso.xpi
    fi

    # Install Chrome extension with a predictable name
    if ls build/Linux-Entra-SSO-*.chrome.zip 1> /dev/null 2>&1; then
      cp build/Linux-Entra-SSO-*.chrome.zip $out/share/linux-entra-sso/chrome/linux-entra-sso.zip
    fi

    # Wrap the Python script to ensure proper runtime dependencies
    wrapProgram $out/libexec/linux-entra-sso/linux-entra-sso.py \
      --prefix PYTHONPATH : "${python3Packages.pygobject3}/${python3.sitePackages}" \
      --prefix PYTHONPATH : "${python3Packages.pydbus}/${python3.sitePackages}"
  '';

  meta = with lib; {
    description = "Entra ID SSO via Microsoft Identity Broker on Linux";
    homepage = "https://github.com/siemens/linux-entra-sso";
    license = licenses.mpl20;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
