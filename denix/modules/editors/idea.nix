{ delib, host, lib, pkgs, unstable-pkgs, ... }:
delib.module {
  name = "editors.idea";

  options = delib.singleEnableOption host.codingFeatured;

  home.ifEnabled =
    let
      idea = unstable-pkgs.jetbrains.idea;

      ideaWithGpu = pkgs.symlinkJoin {
        inherit (idea) name meta;
        paths = [ idea ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/intellij-idea \
            --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:${lib.makeLibraryPath [ pkgs.libglvnd ]} \
            --suffix XDG_DATA_DIRS : /run/opengl-driver/share
        '';
      };

      m = builtins.match "^([^.]*\\.[^.]*).*$" idea.version;
      version-suffix = if m == null then idea.version else builtins.head m;
    in
    {
      home.packages = [ ideaWithGpu ];

      xdg.configFile."JetBrains/IntelliJIdea${version-suffix}/idea64.vmoptions".text = ''
        -Xmx6144m
        -Dawt.toolkit.name=WLToolkit
        -Dsun.java2d.vulkan=true
      '';
    };
}
