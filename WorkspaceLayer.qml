import QtQuick

Item {
    UserConfig {
        id: userConfig
    }

    property int workspaceId: 1
    property string displayText: "Workspace " + workspaceId
    property string textFontFamily: userConfig.textFontFamily
    property bool showCondition: false
    property int textPixelSize: 16
    property bool slideFromLyrics: false
    property bool animateVisibility: true
    property real transitionProgress: 0
    property real horizontalPadding: 14
    property real hiddenRightPadding: 16

    readonly property real clampedProgress: Math.max(0, Math.min(1, transitionProgress))
    readonly property real revealProgress: slideFromLyrics ? (1 - clampedProgress) : 1
    readonly property real textWidth: Math.max(0, width - horizontalPadding * 2)
    readonly property real centeredX: horizontalPadding
    readonly property real hiddenRightX: width + hiddenRightPadding
    readonly property real labelX: slideFromLyrics
        ? centeredX + (hiddenRightX - centeredX) * clampedProgress
        : centeredX

    anchors.fill: parent
    clip: true
    opacity: showCondition ? (animateVisibility ? revealProgress : 1) : 0

    Behavior on opacity {
        enabled: animateVisibility

        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        x: labelX
        width: textWidth
        anchors.verticalCenter: parent.verticalCenter
        text: displayText
        color: "white"
        opacity: revealProgress
        font.pixelSize: textPixelSize
        font.family: textFontFamily
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }
}
