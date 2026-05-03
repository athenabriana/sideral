# sideral fcitx5 IME wiring — applies to all login shells and graphical
# sessions (sourced by /etc/profile and propagated into the niri Wayland
# session via systemd's user environment). environment.d would also
# work, but profile.d covers ssh/tty logins too without duplication.

export XMODIFIERS=@im=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
