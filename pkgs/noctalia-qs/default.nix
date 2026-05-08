{
  lib,
  stdenv,
  fetchFromGitHub,
  qt6,
  kdePackages,
  cmake,
  ninja,
  pkg-config,
  ...
}:
stdenv.mkDerivation rec {
  pname = "noctalia-qs";
  version = "0.0.12";

  src = fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "noctalia-qs";
    rev = "v${version}";
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = with kdePackages; [
    qtbase
    qtdeclarative
    qtsvg
    qtwayland
  ];

  meta = with lib; {
    description = "noctalia-qs — Quickshell-aligned helper binary for noctalia-shell";
    homepage = "https://github.com/noctalia-dev/noctalia-qs";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
