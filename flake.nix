{
  description = "apb-formal — APB-lite formal compliance checker toolchain (ADR 0001)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          # Yosys + SymbiYosys + SMT solvers run the proofs; graphviz + nodejs render the
          # spec waveforms (docs/spec/waveforms). gnumake drives the harness.
          packages = [
            pkgs.yosys
            pkgs.sby          # SymbiYosys (provides the `sby` driver)
            pkgs.yices
            pkgs.boolector
            pkgs.z3
            pkgs.gnumake
            pkgs.graphviz
            pkgs.nodejs
          ];
        };
      });
    };
}
