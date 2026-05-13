# Prevent doublesourcing
if [ -z "$SIDERAL_MOTD_SOURCED" ]; then
  SIDERAL_MOTD_SOURCED="Y"
  if test -d "$HOME"; then
    if test ! -e "$HOME"/.config/no-show-user-motd; then
      if test -s "/etc/user-motd"; then
        cat /etc/user-motd
      fi
    fi
  fi
fi
