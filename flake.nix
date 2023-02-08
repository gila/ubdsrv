{
  description = "ublk: userspace block device driver";

  inputs.nixpkgs.url = "nixpkgs";

  outputs = { self, nixpkgs }:
    let
      version = builtins.substring 0 8 self.lastModifiedDate;
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

      packages = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          muring = (with pkgs;
            stdenv.mkDerivation rec {
              name = "liburing";
              version = "2.3";
              src = fetchgit {
                url = "http://git.kernel.dk/${name}";
                rev = "liburing-${version}";
                sha256 = "sha256-vN6lLb5kpgHTKDxwibJPS61sdelILETVtJE2BYgp79k=";
              };
            });

          ublk = pkgs.stdenv.mkDerivation {
            name = "ublk";
            src = self;
            nativeBuildInputs = with pkgs; [ autoreconfHook pkg-config ];
            buildInputs = with pkgs; [ packages.${system}.muring gcc ];
          };

        }); # deps
    in {
      packages = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {

          # nix build .#dockerImage
          # docker load < result

          dockerImage = pkgs.dockerTools.buildLayeredImage {
            name = "ublk-srv";
            tag = "latest";
            config = { Cmd = [ "${packages.${system}.ublk}/bin/ublk" ]; };
          };

          default = packages.${system}.ublk;

        });
      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [ deps.${system}.muring gcc fio ];
            shellHook = ''
              ${pkgs.cowsay}/bin/cowsay development shell
            '';
          };
        });
    };
}
