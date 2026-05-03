# sideral default wallpapers

Place a JPEG named `default.jpg` here as the system-default wallpaper
that Noctalia paints on first boot before the user picks their own.

The current image is intentionally absent from the source tree so the
binary asset choice is not bundled into a code-review of niri-shell.
Add the default wallpaper as a separate commit.

The build will succeed without `default.jpg` because Noctalia falls
back to a solid color when no wallpaper is configured. Acceptance
criterion NIR-15b ("wallpaper set on every output at session start")
is met as soon as `default.jpg` lands.
