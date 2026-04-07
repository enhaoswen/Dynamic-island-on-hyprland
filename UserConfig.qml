import QtQuick

QtObject {
    id: userConfig

    property string wallpaperPath: "/home/dan/.config/hypr/wallpaper.png"
    property real workspaceOverviewWindowRadius: 12
    property string iconFontFamily: "JetBrainsMono Nerd Font"
    property string textFontFamily: "Inter"
    property string heroFontFamily: "Inter Display"
    property string timeFontFamily: "Inter Display"

    // Set these to `0` if you want to disable the in-overview key handling.
    property int overviewCloseKey: Qt.Key_Escape
    property int overviewPreviousWorkspaceKey: Qt.Key_Left
    property int overviewNextWorkspaceKey: Qt.Key_Right

    // This registers a Hyprland global shortcut action for the workspace overview.
    // `overviewGlobalShortcutTriggerDescription` is only the display label.
    // If you want Win+Tab:
    // `bind = SUPER, TAB, global, quickshell:dynamic-island-overview`
    // If you want Win+P:
    // `bind = SUPER, P, global, quickshell:dynamic-island-overview`
    property bool overviewGlobalShortcutEnabled: true
    property string overviewGlobalShortcutAppid: "quickshell"
    property string overviewGlobalShortcutName: "dynamic-island-overview"
    property string overviewGlobalShortcutDescription: "Toggle Dynamic Island workspace overview"
    property string overviewGlobalShortcutTriggerDescription: "Win+Tab"

    // Mouse buttons in this file use simple numbers:
    // 1 = left click, 2 = middle click, 3 = right click.
    // These fields are meant to use the simple numbers above, not Qt's raw enum values.

    // Workspace overview mouse bindings.
    property int workspaceOverviewWorkspaceActivateButton: 1
    property int workspaceOverviewWindowDragButton: 1
    property int workspaceOverviewWindowFocusButton: 1
    property int workspaceOverviewWindowCloseButton: 3

    // Dynamic Island mouse bindings.
    // Supported click actions:
    // "none", "toggleExpandedPlayer", "openExpandedPlayer", "closeExpandedPlayer",
    // "toggleControlCenter", "openControlCenter", "closeControlCenter",
    // "toggleOverview", "openOverview", "closeOverview",
    // "toggleLyrics", "showLyrics", "showTime", "restoreRestingCapsule"
    property int dynamicIslandSwipeButton: 1
    property int dynamicIslandPrimaryButton: 1
    property string dynamicIslandPrimaryAction: "toggleExpandedPlayer"
    property int dynamicIslandSecondaryButton: 3
    property string dynamicIslandSecondaryAction: "toggleControlCenter"

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

    function mouseButton(button) {
        switch (button) {
        case 1:
            return Qt.LeftButton;
        case 2:
            return Qt.MiddleButton;
        case 3:
            return Qt.RightButton;
        default:
            return typeof button === "number" ? button : Qt.NoButton;
        }
    }

    function mouseButtonsMask(buttons) {
        if (buttons === undefined || buttons === null)
            return Qt.NoButton;

        if (Array.isArray(buttons)) {
            let mask = Qt.NoButton;
            for (let index = 0; index < buttons.length; index++)
                mask |= mouseButton(buttons[index]);
            return mask;
        }

        return mouseButton(buttons);
    }
}
