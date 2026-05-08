{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  qt6,
  kdePackages,
  quickshell ? null,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "noctalia-shell";
  version = "4.7.6";

  src = fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "noctalia-shell";
    rev = "v${version}";
    hash = lib.fakeHash;
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/etc/xdg/quickshell/noctalia-shell
    cp -r ./* $out/etc/xdg/quickshell/noctalia-shell/
    runHook postInstall
  '';

  meta = with lib; {
    description = "noctalia — Quickshell-based niri shell (bar, launcher, lock screen)";
    homepage = "https://github.com/noctalia-dev/noctalia-shell";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
