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
    # Dummy patch phase - add your patches here
    echo "Patching Makefile..."

    # Example patch: fix paths for Nix
    substituteInPlace Makefile \
      --replace "/usr/local" "$out" \
      --replace "/usr/bin/python3" "${python3}/bin/python3"

    # Add more patches as needed
  '';

  buildPhase = ''
    echo "Building linux-entra-sso package..."
    make package
  '';

  installPhase = ''
    echo "Installing linux-entra-sso..."
    make install DESTDIR=$out prefix="" \
      python3_bin=${python3}/bin/python3 \
      firefox_nm_dir=$out/lib/mozilla/native-messaging-hosts \
      chrome_nm_dir=$out/etc/opt/chrome/native-messaging-hosts \
      chromium_nm_dir=$out/etc/chromium/native-messaging-hosts \
      chrome_ext_dir=$out/share/google-chrome/extensions

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
