import QtQuick

Text {
    property string currentTime: "00:00"
    property string heroFontFamily: "Inter Display"
    property bool showCondition: false

    anchors.centerIn: parent
    text: currentTime
    color: "white"
    font.pixelSize: 18
    font.family: heroFontFamily
    font.weight: Font.Bold
    font.letterSpacing: -0.35
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 200
            easing.type: Easing.InOutQuad
        }
    }
}
