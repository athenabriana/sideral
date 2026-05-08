{...}: {
  system.nixos = {
    distroId = "sideral";
    distroName = "sideral";
  };

  environment.etc."containers/policy.json".source = ./src/etc/containers/policy.json;
}
