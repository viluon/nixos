{ lib
, stdenv
, fetchFromGitHub
, python3
, zip
, git
, netcat-gnu
, writeShellScript
}:

let
  netcatHost = writeShellScript "netcat-host.sh" ''
    exec ${netcat-gnu}/bin/nc 192.168.122.110 5000
  '';
in
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
    zip
    git
    python3
    netcat-gnu
  ];

  buildInputs = [
    python3
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

    # Make the get-ext-id.py script executable
    chmod +x platform/chrome/get-ext-id.py

    # Fix the shebang in get-ext-id.py to use our Python
    substituteInPlace platform/chrome/get-ext-id.py \
      --replace "#!/usr/bin/env python3" "#!${python3}/bin/python3"

    # Patch the native messaging JSON files to use our netcat script
    substituteInPlace platform/firefox/linux_entra_sso.json \
      --replace '"/usr/local/lib/linux-entra-sso/linux-entra-sso.py"' '"${netcatHost}"'

    substituteInPlace platform/chrome/linux_entra_sso.json \
      --replace '"/usr/local/lib/linux-entra-sso/linux-entra-sso.py"' '"${netcatHost}"'
  '';

  buildPhase = ''
    echo "Building linux-entra-sso extensions and package..."

    # Build extensions like the Makefile does
    make package

    # Use the Makefile's local-install approach to properly set up the JSON files
    # This handles the extension ID computation and JSON patching correctly
    HOME=$PWD/fake-home make local-install-firefox
    HOME=$PWD/fake-home make local-install-chrome

    # List what was actually built for debugging
    echo "Built files:"
    find build -name "*.xpi" -o -name "*.zip" | sort
    echo "Local install files:"
    find fake-home -name "*.json" | sort
    echo "Chrome JSON content:"
    cat fake-home/.config/google-chrome/NativeMessagingHosts/linux_entra_sso.json
  '';

  installPhase = ''
    echo "Installing linux-entra-sso..."

    # Create flattened directory structure
    mkdir -p $out/{firefox,chrome,extensions}

    # Install browser extensions
    cp build/Linux-Entra-SSO-*.firefox.xpi $out/firefox/linux-entra-sso.xpi
    cp build/Linux-Entra-SSO-*.chrome.zip $out/chrome/linux-entra-sso.zip

    # Use the properly configured JSON files from local-install
    # These have been processed by the Makefile's local-install targets
    cp fake-home/.mozilla/native-messaging-hosts/linux_entra_sso.json \
       $out/firefox/

    cp fake-home/.config/google-chrome/NativeMessagingHosts/linux_entra_sso.json \
       $out/chrome/

    # Get Chrome extension ID from the built extension and store it
    CHROME_EXT_ID=$(${python3}/bin/python3 platform/chrome/get-ext-id.py build/chrome/)
    echo "$CHROME_EXT_ID" > $out/chrome/extension-id.txt
  '';

  meta = with lib; {
    description = "Entra ID SSO via Microsoft Identity Broker on Linux";
    homepage = "https://github.com/siemens/linux-entra-sso";
    license = licenses.mpl20;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
