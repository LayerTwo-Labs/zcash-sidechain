{ pkgs ? import <nixpkgs> {} }:
with pkgs;
let
  withUtils = true;
  withWallet = true;
  withDaemon = true;
  withMining = true;
  withZmq = true;
in
pkgs.llvmPackages_13.stdenv.mkDerivation rec {
  pname = "zcash";
  version = "5.0.0";

  src = fetchFromGitHub {
    owner = "zcash";
    repo  = "zcash";
    rev = "v${version}";
    sha256 = "sha256-YJ5ufo+LYbOTr9SyiEzzp1pcSx6+cHSvDLBOIcx9X+4=";
  };

  nativeBuildInputs = [ autoreconfHook rustup hexdump makeWrapper pkg-config ];
  buildInputs = [ boost175 libevent libsodium utf8cpp ]
    ++ lib.optional withWallet db62
    ++ lib.optional withZmq zeromq;

  # Use the stdenv default phases (./configure; make) instead of the
  # ones from buildRustPackage.
  configurePhase = "configurePhase";
  buildPhase = "buildPhase";
  checkPhase = "checkPhase";
  installPhase = "installPhase";

  postPatch = ''
    # Have to do this here instead of in preConfigure because
    # cargoDepsCopy gets unset after postPatch.
    configureFlagsArray+=("RUST_VENDORED_SOURCES=$NIX_BUILD_TOP/$cargoDepsCopy")
  '';

  configureFlags = [
    "--enable-debug"
    "--enable-online-rust"
    "--disable-tests"
    "--with-boost-libdir=${lib.getLib boost175}/lib"
    "CXXFLAGS=-I${lib.getDev utf8cpp}/include/utf8cpp"
    "RUST_TARGET=${rust.toRustTargetSpec stdenv.hostPlatform}"
  ] ++ lib.optional (!withWallet) "--disable-wallet"
    ++ lib.optional (!withDaemon) "--without-daemon"
    ++ lib.optional (!withUtils) "--without-utils"
    ++ lib.optional (!withMining) "--disable-mining";

  enableParallelBuilding = true;

  # Requires hundreds of megabytes of zkSNARK parameters.
  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/zcash-fetch-params \
        --set PATH ${lib.makeBinPath [ coreutils curl util-linux ]}
  '';

  meta = with lib; {
    description = "Peer-to-peer, anonymous electronic cash system";
    homepage = "https://z.cash/";
    maintainers = with maintainers; [ rht tkerber ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
