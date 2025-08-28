{
  description = "Zig development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
            zls  # Zig Language Server
            lldb  # LLVM debugger
          ];

          shellHook = ''
            echo "Zig development environment loaded"
            echo "Zig version: $(zig version)"
            echo "ZLS (Zig Language Server) is available for IDE integration"
          '';
        };

        # Optional: provide zig as a package
        packages.default = pkgs.zig;
      });
}