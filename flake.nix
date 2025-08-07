{
  description = "A Nix-flake-based Java development environment";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

  outputs =
    inputs:
    let
      javaVersion = 21; # Change this value to update the whole stack

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ inputs.self.overlays.default ];
            };
          }
        );
    in
    {
      overlays.default =
        final: prev:
        let
          jdk = prev."jdk${toString javaVersion}";
        in
        {
          inherit jdk;
          maven = prev.maven.override { jdk_headless = jdk; };
          gradle = prev.gradle.override { java = jdk; };
          lombok = prev.lombok.override { inherit jdk; };
        };

      devShells = forEachSupportedSystem (
        { pkgs }:
        let
          lwjglLibs = with pkgs; [
            xorg.libX11
            mesa
            libGL
            xorg.libXext
            xorg.libXrender
            glib
            gtk3
            libpulseaudio
            libGLU
          ];
        in
        {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                gcc
                gradle
                jdk
                maven
                ncurses
                patchelf
                zlib
                jdt-language-server
                google-java-format
                jetbrains.idea-community
              ]
              ++ lwjglLibs;

            shellHook =
              let
                loadLombok = "-javaagent:${pkgs.lombok}/share/java/lombok.jar";
                prevOpts = "\${JAVA_TOOL_OPTIONS:+ $JAVA_TOOL_OPTIONS}";
              in
              ''
                export JAVA_TOOL_OPTIONS="${loadLombok}${prevOpts}"
                export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath lwjglLibs}:$LD_LIBRARY_PATH
              '';
          };
        }
      );
    };
}
