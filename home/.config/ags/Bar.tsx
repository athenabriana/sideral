import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { Variable, bind, execAsync } from "astal"
import Hyprland from "gi://AstalHyprland"
import Battery from "gi://AstalBattery"
import Network from "gi://AstalNetwork"
import AstalBluetooth from "gi://AstalBluetooth"
import Apps from "gi://AstalApps"
import Wp from "gi://AstalWp"

const time = Variable("").poll(1000, "date +'%H:%M'")
const dateStr = Variable("").poll(60000, "date +'%A, %d %B %Y'")

const ICON_TASK = 20
const ICON_SYS  = 16

/* App icon resolver (handles broken/missing icon names) */
function resolveAppIcon(cls: string, appsDb: InstanceType<typeof Apps.Apps>): string {
    if (!cls) return "application-x-executable-symbolic"
    const m = appsDb.fuzzy_query(cls)[0]
    if (m?.iconName) return m.iconName
    const variants = [
        cls,
        cls.toLowerCase(),
        cls.toLowerCase().replace(/\s+/g, "-"),
        cls.toLowerCase().replace(/\./g, "-"),
    ]
    const theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default()!)
    for (const v of variants) if (theme.has_icon(v)) return v
    return "application-x-executable-symbolic"
}

/* ────────────────  Bar modules  ─────────────── */

function Workspaces() {
    const hypr = Hyprland.get_default()
    return (
        <box cssClasses={["workspaces"]}>
            {bind(hypr, "workspaces").as(wss =>
                wss
                    .filter(ws => ws.id > 0)
                    .sort((a, b) => a.id - b.id)
                    .map(ws => (
                        <button
                            cssClasses={bind(hypr, "focusedWorkspace").as(fw =>
                                ws === fw ? ["ws", "focused"] : ["ws"]
                            )}
                            onClicked={() => ws.focus()}
                        >
                            <label label={`${ws.id}`} />
                        </button>
                    ))
            )}
        </box>
    )
}

function Taskbar() {
    const hypr = Hyprland.get_default()
    const apps = new Apps.Apps()
    return (
        <box cssClasses={["taskbar"]}>
            {bind(hypr, "clients").as(clients =>
                clients
                    .filter(c => c.workspace && c.workspace.id > 0)
                    .map(c => (
                        <button
                            cssClasses={bind(hypr, "focusedClient").as(fc =>
                                fc && fc.address === c.address ? ["task", "active"] : ["task"]
                            )}
                            onClicked={() => c.focus()}
                            tooltipText={c.title || c.class || ""}
                        >
                            <image iconName={resolveAppIcon(c.class, apps)} pixelSize={ICON_TASK} />
                        </button>
                    ))
            )}
        </box>
    )
}

function Clock() {
    return (
        <button
            cssClasses={["clock"]}
            onClicked={() => App.toggle_window("control")}
            tooltipText={dateStr()}
        >
            <label label={time()} />
        </button>
    )
}

function SysIcon({ cls, onClick, iconBind, tooltip }: any) {
    return (
        <button
            cssClasses={["sys-icon", ...(cls ? [cls] : [])]}
            onClicked={onClick}
            tooltipText={tooltip}
        >
            <image iconName={iconBind} pixelSize={ICON_SYS} />
        </button>
    )
}

function VolumeIcon() {
    const speaker = Wp.get_default()?.defaultSpeaker
    if (!speaker) return <box />
    return SysIcon({
        cls: "volume",
        onClick: () => App.toggle_window("control"),
        iconBind: bind(speaker, "volumeIcon").as((i: string) => i || "audio-volume-medium-symbolic"),
        tooltip: bind(speaker, "volume").as((v: number) => `${Math.round(v * 100)}%`),
    })
}

function NetworkIcon() {
    const net = Network.get_default()
    if (!net) return <box />
    const iconName = Variable.derive(
        [bind(net, "primary")],
        (primary) => {
            if (primary === Network.Primary.WIRED  && net.wired) return net.wired.iconName || "network-wired-symbolic"
            if (primary === Network.Primary.WIFI   && net.wifi)  return net.wifi.iconName  || "network-wireless-symbolic"
            return "network-offline-symbolic"
        },
    )
    return SysIcon({
        cls: "network",
        onClick: () => App.toggle_window("control"),
        iconBind: iconName(),
        tooltip: bind(net, "primary").as(p =>
            p === Network.Primary.WIFI  ? (net.wifi?.ssid ?? "Wi-Fi") :
            p === Network.Primary.WIRED ? "Wired" : "Offline"
        ),
    })
}

function BatteryIcon() {
    const bat = Battery.get_default()
    if (!bat) return <box />
    return (
        <button
            cssClasses={["sys-icon", "battery"]}
            visible={bind(bat, "isPresent")}
            onClicked={() => App.toggle_window("control")}
            tooltipText={bind(bat, "percentage").as((p: number) => `${Math.round(p * 100)}%`)}
        >
            <image
                iconName={bind(bat, "iconName").as((i: string) => i || "battery-symbolic")}
                pixelSize={ICON_SYS}
            />
        </button>
    )
}

function PowerMini() {
    return (
        <button
            cssClasses={["sys-icon", "power"]}
            onClicked={() => App.toggle_window("control")}
            tooltipText="Quick settings"
        >
            <image iconName="emblem-system-symbolic" pixelSize={ICON_SYS} />
        </button>
    )
}

export default function Bar(gdkmonitor: Gdk.Monitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor
    return (
        <window
            cssClasses={["Bar"]}
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            anchor={TOP | LEFT | RIGHT}
            application={App}
        >
            <centerbox cssClasses={["bar-outer"]}>
                <box halign={Gtk.Align.START} cssClasses={["island", "left"]}>
                    <Workspaces />
                </box>
                <box halign={Gtk.Align.CENTER} cssClasses={["island", "center"]}>
                    <Taskbar />
                </box>
                <box halign={Gtk.Align.END} cssClasses={["island", "right"]}>
                    <VolumeIcon />
                    <NetworkIcon />
                    <BatteryIcon />
                    <Clock />
                    <PowerMini />
                </box>
            </centerbox>
        </window>
    )
}

/* ────────────────  Control Center  ─────────────── */

function VolumeRow() {
    const speaker = Wp.get_default()?.defaultSpeaker
    if (!speaker) return <box />
    return (
        <box cssClasses={["cc-row", "slider-row"]} spacing={10}>
            <button
                onClicked={() => speaker.set_mute(!speaker.mute)}
                tooltipText="Mute"
            >
                <image
                    iconName={bind(speaker, "volumeIcon").as((i: string) => i || "audio-volume-medium-symbolic")}
                    pixelSize={18}
                />
            </button>
            <slider
                hexpand
                min={0}
                max={1}
                value={bind(speaker, "volume")}
                onChangeValue={({ value }) => speaker.set_volume(value)}
            />
            <label
                cssClasses={["cc-value"]}
                label={bind(speaker, "volume").as((v: number) => `${Math.round(v * 100)}%`)}
            />
        </box>
    )
}

function NetworkTile() {
    const net = Network.get_default()
    if (!net) return <box />
    const wifi = net.wifi
    if (!wifi) {
        return (
            <box cssClasses={["cc-tile", "disabled"]}>
                <image iconName="network-wireless-disabled-symbolic" pixelSize={20} />
                <box orientation={Gtk.Orientation.VERTICAL}>
                    <label cssClasses={["cc-tile-title"]} label="Wi-Fi" />
                    <label cssClasses={["cc-tile-sub"]} label="Not available" />
                </box>
            </box>
        )
    }
    return (
        <button
            cssClasses={bind(wifi, "enabled").as(e => e ? ["cc-tile", "on"] : ["cc-tile"])}
            onClicked={() => wifi.set_enabled(!wifi.enabled)}
        >
            <box spacing={8}>
                <image
                    iconName={bind(wifi, "iconName").as((i: string) => i || "network-wireless-symbolic")}
                    pixelSize={20}
                />
                <box orientation={Gtk.Orientation.VERTICAL} halign={Gtk.Align.START}>
                    <label
                        cssClasses={["cc-tile-title"]}
                        halign={Gtk.Align.START}
                        label="Wi-Fi"
                    />
                    <label
                        cssClasses={["cc-tile-sub"]}
                        halign={Gtk.Align.START}
                        label={bind(wifi, "ssid").as((s: string | null) => s || "Off")}
                    />
                </box>
            </box>
        </button>
    )
}

function BluetoothTile() {
    const bt = AstalBluetooth.get_default()
    if (!bt) return <box />
    return (
        <button
            cssClasses={bind(bt, "isPowered").as(p => p ? ["cc-tile", "on"] : ["cc-tile"])}
            onClicked={() => bt.toggle()}
        >
            <box spacing={8}>
                <image
                    iconName={bind(bt, "isPowered").as((p: boolean) =>
                        p ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
                    )}
                    pixelSize={20}
                />
                <box orientation={Gtk.Orientation.VERTICAL} halign={Gtk.Align.START}>
                    <label cssClasses={["cc-tile-title"]} halign={Gtk.Align.START} label="Bluetooth" />
                    <label
                        cssClasses={["cc-tile-sub"]}
                        halign={Gtk.Align.START}
                        label={bind(bt, "isPowered").as((p: boolean) => p ? "On" : "Off")}
                    />
                </box>
            </box>
        </button>
    )
}

function PowerRow() {
    const actions = [
        { label: "Lock",     icon: "system-lock-screen-symbolic",  cmd: "hyprlock" },
        { label: "Logout",   icon: "system-log-out-symbolic",       cmd: "hyprctl dispatch exit" },
        { label: "Suspend",  icon: "media-playback-pause-symbolic", cmd: "systemctl suspend" },
        { label: "Reboot",   icon: "view-refresh-symbolic",         cmd: "systemctl reboot" },
        { label: "Shutdown", icon: "system-shutdown-symbolic",      cmd: "systemctl poweroff" },
    ]
    return (
        <box cssClasses={["cc-power-row"]} spacing={6} homogeneous>
            {actions.map(a => (
                <button
                    cssClasses={["cc-power-btn"]}
                    tooltipText={a.label}
                    onClicked={() => {
                        App.toggle_window("control")
                        execAsync(a.cmd).catch(() => {})
                    }}
                >
                    <image iconName={a.icon} pixelSize={18} />
                </button>
            ))}
        </box>
    )
}

export function ControlCenter() {
    const { TOP, RIGHT } = Astal.WindowAnchor
    return (
        <window
            name="control"
            application={App}
            anchor={TOP | RIGHT}
            marginTop={8}
            marginRight={12}
            keymode={Astal.Keymode.ON_DEMAND}
            cssClasses={["control-window"]}
            visible={false}
        >
            <box cssClasses={["control-card"]} orientation={Gtk.Orientation.VERTICAL} spacing={12}>
                <box cssClasses={["cc-header"]}>
                    <label cssClasses={["cc-title"]} label="Quick Settings" halign={Gtk.Align.START} hexpand />
                    <label cssClasses={["cc-clock"]} label={time()} halign={Gtk.Align.END} />
                </box>

                <VolumeRow />

                <box spacing={8}>
                    <NetworkTile />
                    <BluetoothTile />
                </box>

                <label cssClasses={["cc-section"]} label="Power" halign={Gtk.Align.START} />
                <PowerRow />
            </box>
        </window>
    )
}
