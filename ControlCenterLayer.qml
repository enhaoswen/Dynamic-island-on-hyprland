import QtQuick
import Quickshell.Io

Item {
    id: controlCenter

    UserConfig {
        id: userConfig
    }

    property bool showCondition: false
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily
    property string currentTime: "00:00"
    property string currentDateLabel: ""
    property int batteryCapacity: 0
    property bool isCharging: false
    property real volumeLevel: -1
    property real brightnessLevel: -1
    property int sliderIntroDelay: 400
    property int currentWorkspace: 1
    property string currentTrack: ""
    property string currentArtist: ""

    property real localVolume: 0.5
    property real localBrightness: 0.5
    property real displayedVolume: 0.5
    property real displayedBrightness: 0.5
    property real pendingVolume: 0.5
    property real pendingBrightness: 0.5
    property real lastAppliedVolume: -1
    property real lastAppliedBrightness: -1
    property bool sliderIntroPending: false
    readonly property real sliderKnobSize: 24
    readonly property color panelColor: "#000000"
    readonly property color moduleColor: "#1c1c1e"
    readonly property color moduleHover: "#232326"
    readonly property color trackColor: "#2c2c2e"
    readonly property color textPrimary: "#f5f5f7"
    readonly property color textSecondary: "#8e8e93"
    readonly property color buttonFill: "#f5f5f7"
    readonly property color buttonFillHover: "#ffffff"
    readonly property color buttonFillPressed: "#e9e9ec"

    readonly property var quickActions: userConfig.controlCenterActions

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function applyBrightnessOutput(text) {
        const match = text.match(/,(\d+)%/);
        if (match) localBrightness = clamp01(parseInt(match[1], 10) / 100);
    }

    function applyVolumeOutput(text) {
        const match = text.match(/([0-9]*\.?[0-9]+)/);
        if (match) localVolume = clamp01(parseFloat(match[1]));
    }

    function flushBrightness(force) {
        const nextValue = clamp01(pendingBrightness);
        if (!force && Math.abs(nextValue - lastAppliedBrightness) < 0.01) return;
        if (brightnessSetter.running) {
            brightnessApplyTimer.restart();
            return;
        }

        lastAppliedBrightness = nextValue;
        brightnessSetter.exec(["brightnessctl", "set", Math.round(nextValue * 100) + "%"]);
    }

    function queueBrightness(value) {
        localBrightness = clamp01(value);
        if (showCondition && !sliderIntroPending) displayedBrightness = localBrightness;
        pendingBrightness = localBrightness;
        brightnessApplyTimer.restart();
    }

    function flushVolume(force) {
        const nextValue = clamp01(pendingVolume);
        if (!force && Math.abs(nextValue - lastAppliedVolume) < 0.01) return;
        if (volumeSetter.running) {
            volumeApplyTimer.restart();
            return;
        }

        lastAppliedVolume = nextValue;
        volumeSetter.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", nextValue.toFixed(2)]);
    }

    function queueVolume(value) {
        localVolume = clamp01(value);
        if (showCondition && !sliderIntroPending) displayedVolume = localVolume;
        pendingVolume = localVolume;
        volumeApplyTimer.restart();
    }

    function syncBrightnessFromLevel(level) {
        if (level < 0) return;
        localBrightness = clamp01(level);
        if (showCondition && !sliderIntroPending) displayedBrightness = localBrightness;
        pendingBrightness = localBrightness;
        lastAppliedBrightness = localBrightness;
    }

    function syncVolumeFromLevel(level) {
        if (level < 0) return;
        localVolume = clamp01(level);
        if (showCondition && !sliderIntroPending) displayedVolume = localVolume;
        pendingVolume = localVolume;
        lastAppliedVolume = localVolume;
    }

    function syncLevelsFromProps() {
        syncBrightnessFromLevel(brightnessLevel);
        syncVolumeFromLevel(volumeLevel);
    }

    anchors.fill: parent
    anchors.margins: 12
    opacity: showCondition ? 1 : 0
    visible: opacity > 0

    onBrightnessLevelChanged: syncBrightnessFromLevel(brightnessLevel)
    onVolumeLevelChanged: syncVolumeFromLevel(volumeLevel)
    onShowConditionChanged: {
        if (showCondition) {
            syncLevelsFromProps();
            displayedBrightness = 0;
            displayedVolume = 0;
            sliderIntroPending = true;
            sliderIntroTimer.interval = sliderIntroDelay;
            sliderIntroTimer.restart();
        } else {
            sliderIntroTimer.stop();
            sliderIntroPending = false;
            displayedBrightness = localBrightness;
            displayedVolume = localVolume;
        }
    }

    Component.onCompleted: {
        syncLevelsFromProps();
        displayedBrightness = localBrightness;
        displayedVolume = localVolume;
        brightnessGetter.exec(["brightnessctl", "-m"]);
        volumeGetter.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
    }

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 240 : 100
            easing.type: Easing.InOutQuad
        }
    }

    Process {
        id: brightnessGetter
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: controlCenter.applyBrightnessOutput(text)
        }
    }

    Process {
        id: volumeGetter
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: controlCenter.applyVolumeOutput(text)
        }
    }

    Process { id: brightnessSetter }
    Process { id: volumeSetter }

    Timer {
        id: brightnessApplyTimer
        interval: 55
        repeat: false
        onTriggered: controlCenter.flushBrightness(false)
    }

    Timer {
        id: volumeApplyTimer
        interval: 55
        repeat: false
        onTriggered: controlCenter.flushVolume(false)
    }

    Timer {
        id: sliderIntroTimer
        interval: controlCenter.sliderIntroDelay
        repeat: false

        onTriggered: {
            controlCenter.sliderIntroPending = false;
            controlCenter.displayedBrightness = controlCenter.localBrightness;
            controlCenter.displayedVolume = controlCenter.localVolume;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: panelColor
    }

    Column {
        anchors.fill: parent
        spacing: 12

        Item {
            width: parent.width
            height: 28

            Item {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 220
                height: parent.height

                Text {
                    id: timeLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: currentTime
                    color: "#f7f8fb"
                    font.pixelSize: 19
                    font.family: heroFontFamily
                    font.weight: Font.Bold
                    font.letterSpacing: -0.45
                }

                Text {
                    anchors.left: timeLabel.right
                    anchors.leftMargin: 10
                    anchors.baseline: timeLabel.baseline
                    text: currentDateLabel
                    color: textSecondary
                    font.pixelSize: 12
                    font.family: textFontFamily
                    font.weight: Font.Medium
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    text: userConfig.controlCenterIcons["charging"]
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.family: iconFontFamily
                    visible: isCharging
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: batteryCapacity + "%"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.family: textFontFamily
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: 28
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        anchors.rightMargin: 2
                        radius: 4
                        color: "transparent"
                        border.color: "#8e8e93"
                        border.width: 1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            radius: 2
                            width: (parent.width - 4) * (batteryCapacity / 100.0)
                            color: {
                                if (batteryCapacity <= 10) return "#ff3b30";
                                if (batteryCapacity <= 20) return "#ffcc00";
                                return "#34c759";
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 2
                        height: 6
                        radius: 1
                        color: "#8e8e93"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 56
            radius: 22
            color: moduleColor

            Item {
                id: actionsLayout
                width: parent.width - 40
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                readonly property real buttonSize: 40
                readonly property real gap: (width - buttonSize * 4) / 5

                Repeater {
                    model: quickActions

                    delegate: Item {
                        width: actionsLayout.buttonSize
                        height: width
                        x: actionsLayout.gap + index * (width + actionsLayout.gap)

                        Process {
                            id: launcher
                            command: ["sh", "-c", modelData.command]
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: actionArea.pressed
                                ? buttonFillPressed
                                : (actionArea.containsMouse ? buttonFillHover : buttonFill)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: "#111214"
                                font.pixelSize: 18
                                font.family: iconFontFamily
                            }
                        }

                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: launcher.running = true
                        }
                    }
                }
            }
        }

        Rectangle {
            id: brightnessCard
            width: parent.width
            height: 76
            radius: 24
            color: brightnessArea.containsMouse ? moduleHover : moduleColor

            Behavior on color {
                ColorAnimation {
                    duration: 130
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 12

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "Display"
                    color: textPrimary
                    font.pixelSize: 13
                    font.family: textFontFamily
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: brightnessTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 22
                    radius: 11
                    color: trackColor
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        width: 18
                        height: 18
                        radius: 9
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: userConfig.controlCenterIcons["brightness"]
                            color: textSecondary
                            font.pixelSize: 13
                            font.family: iconFontFamily
                        }
                    }

                    Rectangle {
                        id: brightnessFill
                        width: 0
                        height: parent.height
                        radius: parent.radius
                        color: "#f5f5f7"

                        Behavior on width {
                            enabled: !brightnessArea.pressed

                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }

                    Rectangle {
                        id: brightnessKnob
                        x: Math.max(0, Math.min(parent.width - width, parent.width * displayedBrightness - width / 2))
                        y: -1
                        width: controlCenter.sliderKnobSize
                        height: controlCenter.sliderKnobSize
                        radius: 12
                        color: "#ffffff"
                        visible: true

                        Behavior on x {
                            enabled: !brightnessArea.pressed

                            NumberAnimation {
                                duration: 130
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Binding {
                        target: brightnessFill
                        property: "width"
                        value: localBrightness <= 0.001
                            ? 0
                            : Math.max(34, Math.min(brightnessTrack.width, brightnessKnob.x + brightnessKnob.width / 2 + 1))
                    }

                    MouseArea {
                        id: brightnessArea
                        anchors.fill: parent
                        hoverEnabled: true

                        function update(mouseX) {
                            controlCenter.queueBrightness(controlCenter.clamp01(mouseX / width));
                        }

                        onPressed: (mouse) => {
                            if (controlCenter.sliderIntroPending) {
                                sliderIntroTimer.stop();
                                controlCenter.sliderIntroPending = false;
                                controlCenter.displayedBrightness = controlCenter.localBrightness;
                                controlCenter.displayedVolume = controlCenter.localVolume;
                            }
                            update(mouse.x);
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) update(mouse.x);
                        }
                        onReleased: {
                            brightnessApplyTimer.stop();
                            controlCenter.flushBrightness(true);
                        }
                        onCanceled: brightnessGetter.exec(["brightnessctl", "-m"])
                    }
                }
            }
        }

        Rectangle {
            id: volumeCard
            width: parent.width
            height: 76
            radius: 24
            color: volumeArea.containsMouse ? moduleHover : moduleColor

            Behavior on color {
                ColorAnimation {
                    duration: 130
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 12

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "Sound"
                    color: textPrimary
                    font.pixelSize: 13
                    font.family: textFontFamily
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: volumeTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 22
                    radius: 11
                    color: trackColor
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        width: 18
                        height: 18
                        radius: 9
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: userConfig.controlCenterIcons["volume"]
                            color: textSecondary
                            font.pixelSize: 13
                            font.family: iconFontFamily
                        }
                    }

                    Rectangle {
                        id: volumeFill
                        width: 0
                        height: parent.height
                        radius: parent.radius
                        color: "#f5f5f7"

                        Behavior on width {
                            enabled: !volumeArea.pressed

                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }

                    Rectangle {
                        id: volumeKnob
                        x: Math.max(0, Math.min(parent.width - width, parent.width * displayedVolume - width / 2))
                        y: -1
                        width: controlCenter.sliderKnobSize
                        height: controlCenter.sliderKnobSize
                        radius: 12
                        color: "#ffffff"
                        visible: true

                        Behavior on x {
                            enabled: !volumeArea.pressed

                            NumberAnimation {
                                duration: 130
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Binding {
                        target: volumeFill
                        property: "width"
                        value: localVolume <= 0.001
                            ? 0
                            : Math.max(34, Math.min(volumeTrack.width, volumeKnob.x + volumeKnob.width / 2 + 1))
                    }

                    MouseArea {
                        id: volumeArea
                        anchors.fill: parent
                        hoverEnabled: true

                        function update(mouseX) {
                            controlCenter.queueVolume(controlCenter.clamp01(mouseX / width));
                        }

                        onPressed: (mouse) => {
                            if (controlCenter.sliderIntroPending) {
                                sliderIntroTimer.stop();
                                controlCenter.sliderIntroPending = false;
                                controlCenter.displayedBrightness = controlCenter.localBrightness;
                                controlCenter.displayedVolume = controlCenter.localVolume;
                            }
                            update(mouse.x);
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) update(mouse.x);
                        }
                        onReleased: {
                            volumeApplyTimer.stop();
                            controlCenter.flushVolume(true);
                        }
                        onCanceled: volumeGetter.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])
                    }
                }
            }
        }
    }
}
