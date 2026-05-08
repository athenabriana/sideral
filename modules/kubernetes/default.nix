{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    kubectl
    kind
    kubernetes-helm
  ];

  environment.sessionVariables = {
    KIND_EXPERIMENTAL_PROVIDER = "podman";
    MINIKUBE_DRIVER = "podman";
  };
}
