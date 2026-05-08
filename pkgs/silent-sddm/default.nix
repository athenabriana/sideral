{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "silent-sddm";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "uiriansan";
    repo = "SilentSDDM";
    rev = "v${version}";
    hash = lib.fakeHash;
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/sddm/themes/silent
    cp -r . $out/share/sddm/themes/silent/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Customizable SDDM theme — vendored upstream from uiriansan/SilentSDDM";
    homepage = "https://github.com/uiriansan/SilentSDDM";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
