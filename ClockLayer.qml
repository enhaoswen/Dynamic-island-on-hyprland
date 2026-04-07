import QtQuick

Item {
    UserConfig {
        id: userConfig
    }

    property string currentTime: "00:00"
    property string heroFontFamily: userConfig.heroFontFamily
    property bool showCondition: false
    property real contentOffsetX: 0
    property int textPixelSize: 18

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 200
            easing.type: Easing.InOutQuad
        }
    }

    Item {
        width: parent.width
        height: parent.height
        x: contentOffsetX
        clip: true

        Text {
            anchors.centerIn: parent
            text: currentTime
            color: "white"
            font.pixelSize: textPixelSize
            font.family: heroFontFamily
            font.weight: Font.Bold
            font.letterSpacing: -0.35
            wrapMode: Text.NoWrap
        }
    }
}
