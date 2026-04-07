import QtQuick

Item {
    UserConfig {
        id: userConfig
    }

    property string iconText: ""
    property string iconFontFamily: userConfig.iconFontFamily
    property bool slideFromLyrics: false
    property real transitionProgress: 0
    property bool showCondition: false
    property real hiddenRightPadding: 16
    readonly property real clampedProgress: Math.max(0, Math.min(1, transitionProgress))
    readonly property real revealProgress: slideFromLyrics ? (1 - clampedProgress) : 1
    readonly property real contentX: slideFromLyrics ? (width + hiddenRightPadding) * clampedProgress : 0

    anchors.fill: parent
    clip: true
    opacity: showCondition ? revealProgress : 0

    Behavior on opacity {
        enabled: !slideFromLyrics

        NumberAnimation {
            duration: showCondition ? 220 : 150
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        x: contentX
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        text: iconText
        color: "white"
        font.pixelSize: 18
        font.family: iconFontFamily
        horizontalAlignment: Text.AlignHCenter
    }
}
