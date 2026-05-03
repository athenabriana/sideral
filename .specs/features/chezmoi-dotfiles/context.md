# chezmoi-dotfiles — Decision Context

## D-01: First-login auto-apply uses `--force` (silent)

**Decision**: The `/etc/profile.d/sideral-chezmoi-defaults.sh` script uses `--force` on the
initial apply. No diff prompts on first login, even for rebased users who may have
customized files.

**Rationale**: User chose simplicity. Brand-new users should get all defaults applied
silently. Rebased users who care about their customizations should use
`ujust apply-defaults` (non-force, interactive) rather than rely on the auto-apply path.

---

## D-02: `.bashrc` and `.zshrc` are chezmoi-managed

**Decision**: Both `.bashrc` and `.zshrc` are included in `/usr/share/sideral/chezmoi/`
as `dot_bashrc` and `dot_zshrc`. The image can update them via `ujust apply-defaults`,
which will prompt the user if they've customized either file.

**Rationale**: User chose consistency — all ten files in the managed table are managed.
The `.bashrc` / `.zshrc` stubs are minimal (mostly comments + `source /etc/bashrc`), so
update conflicts will be rare in practice.
