{
  description = "Library for quantum-safe cryptographic algorithms";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {nixpkgs, flake-utils, ...}:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      mkLiboqs = {compiler ? "gcc", shared ? true, cmakeFlags ? null}: let
        stdenv = if compiler == "clang" then pkgs.clangStdenv else pkgs.stdenv;
        compilerPkg = if compiler == "clang" then pkgs.clang else pkgs.gcc;
      in
        stdenv.mkDerivation {
          name = "liboqs";
          src = ./.;

          dontFixCmake = true;

          nativeBuildInputs = with pkgs; [cmake ninja doxygen pkg-config graphviz compilerPkg];
          buildInputs = [pkgs.openssl];

          cmakeFlags = if cmakeFlags != null then cmakeFlags else [
            "-GNinja"
            "-DOQS_DIST_BUILD=ON"
            "-DOQS_BUILD_ONLY_LIB=ON"
            "-DBUILD_SHARED_LIBS=${if shared then "ON" else "OFF"}"
          ];
        };

      mkDevShell = compiler: let
        lib = mkLiboqs {inherit compiler;};
      in
        pkgs.mkShell {
          inherit (lib) nativeBuildInputs buildInputs;
          packages = with pkgs; [astyle alejandra];
          shellHook = ''
            export CMAKE_EXPORT_COMPILE_COMMANDS=1
          '';
        };
    in {
      formatter = pkgs.alejandra;

      packages = rec {
        default = gcc-shared;
        gcc-shared = mkLiboqs {};
        clang-shared = mkLiboqs {compiler = "clang";};
        gcc-static = mkLiboqs {shared = false;};
        clang-static = mkLiboqs {compiler = "clang"; shared = false;};
        minimal = mkLiboqs {
          cmakeFlags = [
            "-GNinja"
            "-DOQS_STRICT_WARNINGS=ON"
            "-DOQS_MINIMAL_BUILD=KEM_ml_kem_768;SIG_ml_dsa_65"
          ];
        };
      };

      devShells = rec {
        default = gcc;
        gcc = mkDevShell "gcc";
        clang = mkDevShell "clang";
      };
    });
}
