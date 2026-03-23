import QtQuick

Item {
    property string iconText: ""
    property real progress: -1
    property string customText: ""
    property string iconFontFamily: "JetBrainsMono Nerd Font"
    property string textFontFamily: "Inter"
    property string heroFontFamily: "Inter Display"
    readonly property bool showProgress: progress >= 0
    readonly property bool showText: progress < 0 && customText !== ""
    property bool showCondition: false

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 280 : 200
            easing.type: Easing.InOutQuad
        }
    }

    Item {
        anchors.fill: parent
        visible: showProgress

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                text: iconText
                color: "white"
                font.pixelSize: 18
                font.family: iconFontFamily
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: Math.round(progress * 100) + "%"
                color: "white"
                font.pixelSize: 20
                font.family: heroFontFamily
                font.weight: Font.Bold
                font.letterSpacing: -0.35
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            width: 30
            height: 30
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 8
                color: "#111111"
                border.color: "#1f1f1f"
                border.width: 1
            }

            Canvas {
                anchors.fill: parent
                antialiasing: true
                property real progressValue: Math.max(0, Math.min(1, progress))

                onProgressValueChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    var size = Math.min(width, height);
                    var lineWidth = 3.5;
                    var center = size / 2;
                    var radius = (size - lineWidth) / 2 - 0.5;
                    var startAngle = -Math.PI / 2;
                    var endAngle = startAngle + (Math.PI * 2 * progressValue);

                    ctx.clearRect(0, 0, width, height);
                    ctx.lineCap = "round";
                    ctx.lineWidth = lineWidth;

                    ctx.strokeStyle = "rgba(255, 255, 255, 0.16)";
                    ctx.beginPath();
                    ctx.arc(center, center, radius, 0, Math.PI * 2, false);
                    ctx.stroke();

                    ctx.strokeStyle = "#ffffff";
                    ctx.beginPath();
                    ctx.arc(center, center, radius, startAngle, endAngle, false);
                    ctx.stroke();
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 14
        visible: showText

        Text {
            text: iconText
            color: "white"
            font.pixelSize: 18
            font.family: iconFontFamily
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: customText
            color: "white"
            font.pixelSize: 16
            font.family: textFontFamily
            font.weight: Font.DemiBold
            font.letterSpacing: -0.15
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
