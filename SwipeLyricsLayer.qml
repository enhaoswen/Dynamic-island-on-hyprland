import QtQuick

Item {
    id: root

    UserConfig {
        id: userConfig
    }

    property string lyricText: ""
    property string timeText: ""
    property string textFontFamily: userConfig.textFontFamily
    property string timeFontFamily: userConfig.timeFontFamily
    property bool showCondition: false
    property bool showSecondaryText: true
    property real transitionProgress: 0
    property int textPixelSize: 16
    property real minimumWidth: 220
    property real maximumWidth: minimumWidth
    property real horizontalPadding: 14
    property real hiddenLeftPadding: 18
    property real hiddenRightPadding: 16
    property string activeLyricText: lyricText
    property string previousLyricText: ""
    property real lyricChangeProgress: 1

    readonly property real clampedProgress: Math.max(0, Math.min(1, transitionProgress))
    readonly property bool lyricMostlyVisible: clampedProgress > 0.92
    readonly property real textWidth: Math.max(0, width - horizontalPadding * 2)
    readonly property real lyricHiddenX: -textWidth - hiddenLeftPadding
    readonly property real centeredX: horizontalPadding
    readonly property real timeHiddenX: width + hiddenRightPadding
    readonly property real lyricX: lyricHiddenX + (centeredX - lyricHiddenX) * clampedProgress
    readonly property real timeX: centeredX + (timeHiddenX - centeredX) * clampedProgress
    readonly property real preferredWidth: Math.max(
        minimumWidth,
        Math.min(Math.max(minimumWidth, maximumWidth), lyricMetrics.advanceWidth + horizontalPadding * 2 + 28)
    )

    onLyricTextChanged: {
        if (lyricText === activeLyricText) return;

        if (activeLyricText === "" || !lyricMostlyVisible) {
            lyricChangeAnimation.stop();
            previousLyricText = "";
            activeLyricText = lyricText;
            lyricChangeProgress = 1;
            return;
        }

        previousLyricText = activeLyricText;
        activeLyricText = lyricText;
        lyricChangeProgress = 0;
        lyricChangeAnimation.restart();
    }

    onShowConditionChanged: {
        if (showCondition) return;
        lyricChangeAnimation.stop();
        previousLyricText = "";
        activeLyricText = lyricText;
        lyricChangeProgress = 1;
    }

    onTransitionProgressChanged: {
        if (lyricMostlyVisible) return;
        lyricChangeAnimation.stop();
        previousLyricText = "";
        activeLyricText = lyricText;
        lyricChangeProgress = 1;
    }

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 220 : 140
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: lyricMetrics
        font.family: textFontFamily
        font.pixelSize: textPixelSize
        font.weight: Font.DemiBold
        text: activeLyricText !== "" ? activeLyricText : lyricText
    }

    SequentialAnimation {
        id: lyricChangeAnimation

        NumberAnimation {
            target: root
            property: "lyricChangeProgress"
            from: 0
            to: 1
            duration: 260
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: root.previousLyricText = ""
        }
    }

    Text {
        visible: previousLyricText !== ""
        x: lyricX
        width: textWidth
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -14 * lyricChangeProgress
        text: previousLyricText
        color: "white"
        opacity: clampedProgress * (1 - lyricChangeProgress)
        font.pixelSize: textPixelSize
        font.family: textFontFamily
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    Text {
        visible: activeLyricText !== ""
        x: lyricX
        width: textWidth
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: previousLyricText !== "" ? 12 * (1 - lyricChangeProgress) : 0
        text: activeLyricText
        color: "white"
        opacity: clampedProgress * (previousLyricText !== "" ? lyricChangeProgress : 1)
        font.pixelSize: textPixelSize
        font.family: textFontFamily
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    Text {
        visible: timeText !== "" && showSecondaryText
        x: timeX
        width: textWidth
        anchors.verticalCenter: parent.verticalCenter
        text: timeText
        color: "white"
        opacity: 1 - clampedProgress
        font.pixelSize: textPixelSize + 1
        font.family: timeFontFamily
        font.weight: Font.Bold
        font.letterSpacing: -0.25
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }
}
