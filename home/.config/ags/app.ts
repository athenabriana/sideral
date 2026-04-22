import { App } from "astal/gtk4"
import GLib from "gi://GLib"
import Bar, { ControlCenter } from "./Bar"

const CSS_PATH = GLib.build_filenamev([
    GLib.get_user_config_dir(),
    "ags",
    "style.css",
])

App.start({
    instanceName: "bar",
    css: CSS_PATH,
    main() {
        for (const m of App.get_monitors()) Bar(m)
        ControlCenter()
    },
})
