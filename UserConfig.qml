import QtQuick

QtObject {
    id: userConfig

    property string wallpaperPath: "/home/dan/.config/hypr/wallpaper.png"
    property real workspaceOverviewWindowRadius: 12
    property string iconFontFamily: "JetBrainsMono Nerd Font"
    property string textFontFamily: "Inter"
    property string heroFontFamily: "Inter Display"
    property string timeFontFamily: "Inter Display"

    property var scriptPaths: ({
        button_1: "/home/dan/.local/bin/quickshell_script/wifi-menu.sh",
        button_2: "/home/dan/.local/bin/quickshell_script/bluetooth-menu.sh",
        button_3: "/home/dan/.local/bin/quickshell_script/wallpaper-switch.sh",
        button_4: "/home/dan/.local/bin/quickshell_script/powermenu"
    })

    property var controlCenterActions: ([
        { icon: "", command: scriptPaths.button_1 },
        { icon: "", command: scriptPaths.button_2 },
        { icon: "󰋩", command: scriptPaths.button_3 },
        { icon: "󰣇", command: scriptPaths.button_4 }
    ])

    property var controlCenterIcons: ({
        "charging": "",
        "brightness": "󰃟",
        "volume": "󰕾"
    })

    property var statusIcons: ({
        "default": "🎧",
        "notification": "",
        "volume": "󰕾",
        "mute": "󰝟",
        "brightnessLow": "󰃞",
        "brightnessMedium": "󰃟",
        "brightnessHigh": "󰃠",
        "charging": "",
        "discharging": "",
        "capsLockOn": "",
        "capsLockOff": "",
        "bluetooth": "󰋋"
    })
}
