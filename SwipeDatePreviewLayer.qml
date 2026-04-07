import QtQuick

Item {
    UserConfig {
        id: userConfig
    }

    property string leadingText: ""
    property string trailingText: ""
    property string heroFontFamily: userConfig.heroFontFamily
    property bool showCondition: false
    property real transitionProgress: 0
    property int textPixelSize: 18
    property real hiddenLeftPadding: 16
    property real hiddenRightPadding: 16

    readonly property real clampedProgress: Math.max(0, Math.min(1, transitionProgress))
    readonly property real dateHiddenX: -dateLabel.implicitWidth - hiddenLeftPadding
    readonly property real dateCenteredX: (width - dateLabel.implicitWidth) / 2
    readonly property real timeCenteredX: (width - timeLabel.implicitWidth) / 2
    readonly property real timeHiddenX: width + hiddenRightPadding
    readonly property real dateX: dateHiddenX + (dateCenteredX - dateHiddenX) * clampedProgress
    readonly property real timeX: timeCenteredX + (timeHiddenX - timeCenteredX) * clampedProgress

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 220 : 140
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        id: dateLabel
        x: dateX
        anchors.verticalCenter: parent.verticalCenter
        text: leadingText
        color: "white"
        font.pixelSize: textPixelSize
        font.family: heroFontFamily
        font.weight: Font.Bold
        font.letterSpacing: -0.35
        wrapMode: Text.NoWrap
    }

    Text {
        id: timeLabel
        visible: trailingText !== ""
        x: timeX
        anchors.verticalCenter: parent.verticalCenter
        text: trailingText
        color: "white"
        font.pixelSize: textPixelSize
        font.family: heroFontFamily
        font.weight: Font.Bold
        font.letterSpacing: -0.35
        wrapMode: Text.NoWrap
    }
}
