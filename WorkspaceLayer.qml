import QtQuick

Item {
    property int workspaceId: 1
    property string workspaceIcon: ""
    property string iconFontFamily: "JetBrainsMono Nerd Font"
    property string textFontFamily: "Inter"
    property bool showCondition: false

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 14

        Text {
            text: workspaceIcon
            font.pixelSize: 19
            font.family: iconFontFamily
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "Workspace " + workspaceId
            color: "white"
            font.pixelSize: 16
            font.family: textFontFamily
            font.weight: Font.DemiBold
            font.letterSpacing: -0.15
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
