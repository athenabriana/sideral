# athens-os-signing — current state

This package currently ships a **permissive placeholder** `/etc/containers/policy.json` (default `insecureAcceptAnything`). It does NOT enforce signature verification on `rpm-ostree rebase`.

This matches athens-os's current "stay unverified" posture (see STATE.md). The image is signed by CI via cosign keyless OIDC, but the consumer side doesn't verify yet — `rpm-ostree rebase ostree-unverified-registry:...` is the canonical install command.

## How to flip to signed-rebase mode

When you decide to enable signed-rebase verification (per spec ACR-27..29):

1. Replace `src/etc/containers/policy.json` with the strict version that scopes a `sigstoreSigned` rule to `ghcr.io/athenabriana/athens-os` against the workflow OIDC identity. Schema:
   ```json
   {
     "default": [{"type": "insecureAcceptAnything"}],
     "transports": {
       "docker": {
         "ghcr.io/athenabriana/athens-os": [
           {
             "type": "sigstoreSigned",
             "fulcio": {
               "caData": "...embed Fulcio root CA...",
               "oidcIssuer": "https://token.actions.githubusercontent.com",
               "subjectEmail": "https://github.com/athenabriana/athens-os/.github/workflows/build.yml@refs/heads/main"
             },
             "rekorPublicKeyPath": "/etc/pki/containers/rekor.pub"
           }
         ]
       }
     }
   }
   ```
2. Optionally ship `/etc/containers/registries.d/ghcr.io.yaml` if Sigstore lookup defaults aren't already pointing at the right cosign endpoint.
3. Rebuild `athens-os-signing` in our Copr; `rpm-ostree upgrade` ships the new policy.
4. Update README's install command from `ostree-unverified-registry:` to `ostree-image-signed:registry:`.

## Why placeholder for now

Shipping the strict rule without consumer verification enabled would break `rpm-ostree rebase ostree-unverified-registry:` — `containers/image` library reads `policy.json` regardless of transport, and a `sigstoreSigned` rule would fail-closed on any unsigned pull. The permissive placeholder is the correct configuration for "stay unverified" mode.
