import QtQuick

Item {
    UserConfig {
        id: userConfig
    }

    property bool showCondition: false
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string iconText: ""
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily

    readonly property string contentText: {
        if (summary !== "" && body !== "" && body !== summary) return summary + "  " + body;
        if (summary !== "") return summary;
        if (body !== "") return body;
        return "New notification";
    }
    readonly property real minimumWidth: 272
    readonly property real maximumWidth: 400
    readonly property real iconSlotWidth: 18
    readonly property real contentSpacing: 13
    readonly property real horizontalPadding: 16
    readonly property real verticalPadding: 7
    readonly property real textBlockWidthAtMaximum: maximumWidth - horizontalPadding * 2 - iconSlotWidth - contentSpacing
    readonly property bool prefersWrappedContent: contentMetrics.advanceWidth > textBlockWidthAtMaximum
    readonly property real preferredWidth: prefersWrappedContent
        ? maximumWidth
        : Math.max(minimumWidth, Math.min(maximumWidth, contentMetrics.advanceWidth + iconSlotWidth + contentSpacing + horizontalPadding * 2))
    readonly property real preferredHeight: prefersWrappedContent ? 68 : 56

    anchors.fill: parent
    anchors.margins: 0
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 280 : 140
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: contentMetrics
        font.family: textFontFamily
        font.pixelSize: 16
        font.weight: Font.DemiBold
        text: contentText
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: horizontalPadding
        anchors.rightMargin: horizontalPadding
        anchors.topMargin: verticalPadding
        anchors.bottomMargin: verticalPadding
        spacing: contentSpacing
        anchors.verticalCenter: parent.verticalCenter

        Text {
            width: iconSlotWidth
            anchors.verticalCenter: parent.verticalCenter
            text: iconText
            color: "#f4f5f7"
            font.pixelSize: 18
            font.family: iconFontFamily
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            width: parent.width - iconSlotWidth - contentSpacing
            height: parent.height

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: contentText
                color: "white"
                font.pixelSize: 16
                font.family: textFontFamily
                font.weight: Font.DemiBold
                font.letterSpacing: -0.15
                width: parent.width
                wrapMode: prefersWrappedContent ? Text.WordWrap : Text.NoWrap
                maximumLineCount: prefersWrappedContent ? 2 : 1
                elide: Text.ElideRight
                lineHeight: 0.95
            }
        }
    }
}
