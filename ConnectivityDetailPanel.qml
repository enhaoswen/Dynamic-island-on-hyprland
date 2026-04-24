import QtQuick

Item {
    id: root

    property var provider: null
    property string panelKind: "wifi"
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property string heroFontFamily: textFontFamily
    property real presentationProgress: 1

    readonly property bool isWifi: panelKind === "wifi"
    readonly property bool isBluetooth: panelKind === "bluetooth"

    function safeString(value) {
        return value === undefined || value === null ? "" : String(value);
    }

    function wifiEntryVisible(connected) {
        if (!root.provider) return false;
        return !(connected && root.provider.wifiEnabled && safeString(root.provider.wifiCurrentSsid).length > 0);
    }

    function bluetoothDeviceVisible(device, section) {
        return root.provider && root.provider.bluetoothDeviceMatchesSection
            ? root.provider.bluetoothDeviceMatchesSection(device, section)
            : false;
    }

    function focusPromptField() {
        if (wifiPasswordPrompt.visible) {
            wifiPasswordField.forceActiveFocus();
            return;
        }

        if (bluetoothPairingPrompt.visible && bluetoothSecretField.visible)
            bluetoothSecretField.forceActiveFocus();
    }

    Timer {
        id: promptFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.focusPromptField()
    }

    Connections {
        target: root.provider
        ignoreUnknownSignals: true

        function onWifiPendingPasswordSsidChanged() {
            promptFocusTimer.restart();
        }

        function onBluetoothPairingActiveChanged() {
            promptFocusTimer.restart();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: "#1c1c1e"
        opacity: 0.9
    }

    Item {
        id: contentRoot
        anchors.fill: parent
        anchors.margins: 16
        opacity: 0.45 + root.presentationProgress * 0.55

        Behavior on opacity {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 24

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.isWifi ? "Wi-Fi" : "Bluetooth"
                color: "#f5f5f7"
                font.pixelSize: 15
                font.family: root.heroFontFamily
                font.weight: Font.Bold
            }
        }

        Column {
            id: topSection
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headerRow.bottom
            anchors.topMargin: 14
            spacing: 10

            Rectangle {
                width: parent.width
                height: visible ? 64 : 0
                radius: 16
                color: "transparent"
                visible: root.isWifi && root.provider && root.provider.wifiEnabled && root.provider.wifiCurrentSsid.length > 0

                MouseArea {
                    anchors.fill: parent
                    enabled: root.provider
                        && root.provider.wifiSupported
                        && root.provider.wifiAvailable
                        && !root.provider.wifiBusy
                    onClicked: {
                        if (root.provider)
                            root.provider.disconnectWifi();
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 14

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.provider ? root.provider.wifiGlyph : ""
                        color: "#0a84ff"
                        font.pixelSize: 16
                        font.family: root.iconFontFamily
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        text: root.provider ? root.provider.wifiCurrentSsid : ""
                        color: "#f5f5f7"
                        font.pixelSize: 12
                        font.family: root.textFontFamily
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.bottom: parent.bottom
                        text: "Connected"
                        color: "#9da0a8"
                        font.pixelSize: 11
                        font.family: root.textFontFamily
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✓"
                        color: "#34c759"
                        font.pixelSize: 18
                        font.family: root.textFontFamily
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.wifiAvailabilityMessage.length > 0 && root.isWifi
                text: root.provider ? root.provider.wifiAvailabilityMessage : ""
                color: "#9b9da4"
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.wifiInfoMessage.length > 0 && root.isWifi
                text: root.provider ? root.provider.wifiInfoMessage : ""
                color: "#6ea8ff"
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.wifiError.length > 0 && root.isWifi
                text: root.provider ? root.provider.wifiError : ""
                color: "#ff7c72"
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.bluetoothAvailabilityMessage.length > 0 && root.isBluetooth
                text: root.provider ? root.provider.bluetoothAvailabilityMessage : ""
                color: "#9b9da4"
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.bluetoothInfoMessage.length > 0 && root.isBluetooth
                text: root.provider ? root.provider.bluetoothInfoMessage : ""
                color: "#6ea8ff"
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.provider && root.provider.bluetoothError.length > 0 && root.isBluetooth
                text: root.provider ? root.provider.bluetoothError : ""
                color: "#ff7c72"
                font.pixelSize: 11
                font.family: root.textFontFamily
                wrapMode: Text.Wrap
            }

            Rectangle {
                id: bluetoothPairingPrompt
                width: parent.width
                height: visible
                    ? ((root.provider && root.provider.bluetoothPairingRequiresInput)
                        ? 122
                        : ((root.provider && root.provider.bluetoothPairingRequiresConfirmation) ? 110 : 82))
                    : 0
                radius: 16
                color: "#323236"
                visible: root.isBluetooth && root.provider && root.provider.bluetoothPairingActive
                clip: true

                onVisibleChanged: {
                    if (visible)
                        promptFocusTimer.restart();
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 12

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 10

                        Text {
                            width: parent.width
                            text: root.provider ? root.provider.bluetoothPairingTitle : ""
                            color: "#f5f5f7"
                            font.pixelSize: 12
                            font.family: root.textFontFamily
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.provider ? root.provider.bluetoothPairingMessage : ""
                            color: "#d2d4da"
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            wrapMode: Text.Wrap
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: 8
                        visible: root.provider
                            && (root.provider.bluetoothPairingRequiresInput
                                || root.provider.bluetoothPairingRequiresConfirmation)

                        Rectangle {
                            id: bluetoothSecretFieldFrame
                            width: visible
                                ? Math.max(0, parent.width - bluetoothPrimaryButton.width - bluetoothCancelButton.width - 16)
                                : 0
                            height: 34
                            radius: 12
                            color: "#212226"
                            border.color: "#3f4046"
                            border.width: 1
                            visible: root.provider && root.provider.bluetoothPairingRequiresInput

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.provider && root.provider.bluetoothPairingNumericInput
                                    ? "Passkey"
                                    : "PIN"
                                color: "#7f828a"
                                font.pixelSize: 11
                                font.family: root.textFontFamily
                                visible: bluetoothSecretField.text.length === 0 && !bluetoothSecretField.activeFocus
                            }

                            TextInput {
                                id: bluetoothSecretField
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                height: Math.min(parent.height - 8, implicitHeight + 2)
                                color: "#f5f5f7"
                                font.pixelSize: 11
                                font.family: root.textFontFamily
                                verticalAlignment: TextInput.AlignVCenter
                                topPadding: 0
                                bottomPadding: 0
                                leftPadding: 0
                                rightPadding: 0
                                clip: true
                                selectByMouse: true
                                cursorVisible: activeFocus
                                inputMethodHints: root.provider && root.provider.bluetoothPairingNumericInput
                                    ? Qt.ImhDigitsOnly
                                    : Qt.ImhNoPredictiveText
                                maximumLength: root.provider && root.provider.bluetoothPairingNumericInput ? 6 : 16
                                text: root.provider ? root.provider.bluetoothPendingSecretValue : ""
                                onTextChanged: {
                                    if (root.provider)
                                        root.provider.bluetoothPendingSecretValue = text;
                                }
                                Keys.onReturnPressed: {
                                    if (root.provider)
                                        root.provider.submitBluetoothPairingSecret();
                                }
                            }
                        }

                        Rectangle {
                            id: bluetoothPrimaryButton
                            width: root.provider && root.provider.bluetoothPairingRequiresInput ? 50 : 76
                            height: 34
                            radius: 12
                            color: "#0a84ff"

                            Text {
                                anchors.centerIn: parent
                                text: root.provider && root.provider.bluetoothPairingRequiresConfirmation
                                    ? "Confirm"
                                    : "Pair"
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.family: root.textFontFamily
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (!root.provider)
                                        return;

                                    if (root.provider.bluetoothPairingRequiresConfirmation)
                                        root.provider.confirmBluetoothPairing();
                                    else
                                        root.provider.submitBluetoothPairingSecret();
                                }
                            }
                        }

                        Rectangle {
                            id: bluetoothCancelButton
                            width: 58
                            height: 34
                            radius: 12
                            color: "#4a4b50"

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: "#f5f5f7"
                                font.pixelSize: 11
                                font.family: root.textFontFamily
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.provider)
                                        root.provider.cancelBluetoothPairing();
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: wifiPasswordPrompt
                width: parent.width
                height: visible ? 92 : 0
                radius: 16
                color: "#323236"
                visible: root.isWifi && root.provider && root.provider.wifiPendingPasswordSsid.length > 0
                clip: true

                onVisibleChanged: {
                    if (visible)
                        promptFocusTimer.restart();
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 12

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.right: parent.right
                        text: "Enter password for " + (root.provider ? root.provider.wifiPendingPasswordSsid : "")
                        color: "#f5f5f7"
                        font.pixelSize: 12
                        font.family: root.textFontFamily
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: joinButton.left
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        height: 34
                        radius: 12
                        color: "#212226"
                        border.color: "#3f4046"
                        border.width: 1

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password"
                            color: "#7f828a"
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            visible: root.provider && root.provider.wifiPendingPasswordValue.length === 0 && !wifiPasswordField.activeFocus
                        }

                        TextInput {
                            id: wifiPasswordField
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            height: Math.min(parent.height - 8, implicitHeight + 2)
                            color: "#f5f5f7"
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            echoMode: TextInput.Password
                            verticalAlignment: TextInput.AlignVCenter
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0
                            rightPadding: 0
                            clip: true
                            selectByMouse: true
                            cursorVisible: activeFocus
                            text: root.provider ? root.provider.wifiPendingPasswordValue : ""
                            onTextChanged: {
                                if (root.provider)
                                    root.provider.wifiPendingPasswordValue = text;
                            }
                            Keys.onReturnPressed: {
                                if (root.provider)
                                    root.provider.submitWifiPassword();
                            }
                        }
                    }

                    Rectangle {
                        id: joinButton
                        anchors.right: cancelButton.left
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        width: 50
                        height: 34
                        radius: 12
                        color: "#0a84ff"

                        Text {
                            anchors.centerIn: parent
                            text: "Join"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.provider)
                                    root.provider.submitWifiPassword();
                            }
                        }
                    }

                    Rectangle {
                        id: cancelButton
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 50
                        height: 34
                        radius: 12
                        color: "#4a4b50"

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: "#f5f5f7"
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.provider)
                                    root.provider.clearWifiPrompt();
                            }
                        }
                    }
                }
            }
        }

        Flickable {
            id: contentFlick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topSection.bottom
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentColumn
                width: contentFlick.width
                spacing: 8

                Text {
                    width: parent.width
                    visible: root.isWifi && root.provider
                        && root.provider.wifiSupported
                        && root.provider.wifiAvailable
                        && !root.provider.wifiEnabled
                    text: "Turn on Wi-Fi to see nearby networks."
                    color: "#9b9da4"
                    font.pixelSize: 12
                    font.family: root.textFontFamily
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    visible: root.isWifi && root.provider && root.provider.wifiListRunning
                    text: "Scanning nearby networks..."
                    color: "#9b9da4"
                    font.pixelSize: 12
                    font.family: root.textFontFamily
                }

                Repeater {
                    model: root.isWifi && root.provider ? root.provider.wifiNetworks : null

                    delegate: Rectangle {
                        width: contentColumn.width
                        height: visible ? 52 : 0
                        radius: 14
                        color: "transparent"
                        visible: root.wifiEntryVisible(connected)
                        clip: true

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.provider
                                && root.provider.wifiSupported
                                && root.provider.wifiAvailable
                                && root.provider.wifiEnabled
                                && !root.provider.wifiBusy
                            onClicked: {
                                if (!root.provider) return;
                                root.provider.connectWifiNetwork({
                                    ssid: ssid,
                                    type: type,
                                    secure: secure,
                                    savedConnection: savedConnection,
                                    connected: connected
                                });
                            }
                        }

                        Item {
                            anchors.fill: parent
                            anchors.margins: 12

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.provider ? root.provider.wifiGlyph : ""
                                color: connected ? "#0a84ff" : "#868991"
                                font.pixelSize: 14
                                font.family: root.iconFontFamily
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 26
                                anchors.top: parent.top
                                anchors.right: rightInfo.left
                                anchors.rightMargin: 8
                                text: displayName
                                color: "#f5f5f7"
                                font.pixelSize: 12
                                font.family: root.textFontFamily
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 26
                                anchors.bottom: parent.bottom
                                anchors.right: rightInfo.left
                                anchors.rightMargin: 8
                                text: secure ? "Secure network" : "Open network"
                                color: "#9b9da4"
                                font.pixelSize: 10
                                font.family: root.textFontFamily
                                elide: Text.ElideRight
                            }

                            Row {
                                id: rightInfo
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: signal + "%"
                                    color: "#f0f0f3"
                                    font.pixelSize: 11
                                    font.family: root.textFontFamily
                                    visible: signal >= 0
                                }

                                Text {
                                    text: ""
                                    color: "#8f9198"
                                    font.pixelSize: 11
                                    font.family: root.iconFontFamily
                                    visible: secure
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.isBluetooth && root.provider && root.provider.bluetoothAvailable && !root.provider.bluetoothEnabled
                    text: "Turn on Bluetooth to see nearby devices."
                    color: "#9b9da4"
                    font.pixelSize: 12
                    font.family: root.textFontFamily
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    visible: root.isBluetooth && root.provider
                        && root.provider.bluetoothEnabled
                        && root.provider.bluetoothAdapter
                        && root.provider.bluetoothAdapter.discovering
                    text: "Scanning nearby devices..."
                    color: "#9b9da4"
                    font.pixelSize: 12
                    font.family: root.textFontFamily
                }

                Item {
                    width: parent.width
                    height: btConnectedSection.visible ? btConnectedSection.implicitHeight : 0
                    visible: root.isBluetooth && root.provider && root.provider.countBluetoothDevices("connected") > 0

                    Column {
                        id: btConnectedSection
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: root.provider ? root.provider.bluetoothDeviceValues || [] : []

                            delegate: Rectangle {
                                width: btConnectedSection.width
                                height: visible ? 52 : 0
                                radius: 14
                                color: "transparent"
                                visible: root.bluetoothDeviceVisible(modelData, "connected")

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.provider && root.provider.bluetoothEnabled
                                    onClicked: {
                                        if (root.provider)
                                            root.provider.handleBluetoothDevicePressed(modelData);
                                    }
                                }

                                Item {
                                    anchors.fill: parent
                                    anchors.margins: 12

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.provider ? root.provider.bluetoothGlyph : ""
                                        color: "#0a84ff"
                                        font.pixelSize: 14
                                        font.family: root.iconFontFamily
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 26
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.rightMargin: 24
                                        text: root.provider ? root.provider.bluetoothDeviceName(modelData) : ""
                                        color: "#f5f5f7"
                                        font.pixelSize: 12
                                        font.family: root.textFontFamily
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 26
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.rightMargin: 24
                                        text: "Connected"
                                        color: "#9b9da4"
                                        font.pixelSize: 10
                                        font.family: root.textFontFamily
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "✓"
                                        color: "#34c759"
                                        font.pixelSize: 18
                                        font.family: root.textFontFamily
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: btPairedSection.visible ? btPairedSection.implicitHeight : 0
                    visible: root.isBluetooth && root.provider && root.provider.countBluetoothDevices("paired") > 0

                    Column {
                        id: btPairedSection
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: root.provider ? root.provider.bluetoothDeviceValues || [] : []

                            delegate: Rectangle {
                                width: btPairedSection.width
                                height: visible ? 52 : 0
                                radius: 14
                                color: "transparent"
                                visible: root.bluetoothDeviceVisible(modelData, "paired")

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.provider && root.provider.bluetoothEnabled
                                    onClicked: {
                                        if (root.provider)
                                            root.provider.handleBluetoothDevicePressed(modelData);
                                    }
                                }

                                Item {
                                    anchors.fill: parent
                                    anchors.margins: 12

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.provider ? root.provider.bluetoothGlyph : ""
                                        color: "#0a84ff"
                                        font.pixelSize: 14
                                        font.family: root.iconFontFamily
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 26
                                        anchors.top: parent.top
                                        anchors.right: actionLabel.left
                                        anchors.rightMargin: 8
                                        text: root.provider ? root.provider.bluetoothDeviceName(modelData) : ""
                                        color: "#f5f5f7"
                                        font.pixelSize: 12
                                        font.family: root.textFontFamily
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 26
                                        anchors.bottom: parent.bottom
                                        anchors.right: actionLabel.left
                                        anchors.rightMargin: 8
                                        text: root.provider ? root.provider.bluetoothDeviceSubtitle(modelData) : ""
                                        color: "#9b9da4"
                                        font.pixelSize: 10
                                        font.family: root.textFontFamily
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: actionLabel
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Connect"
                                        color: "#f5f5f7"
                                        font.pixelSize: 11
                                        font.family: root.textFontFamily
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: btAvailableSection.visible ? btAvailableSection.implicitHeight : 0
                    visible: root.isBluetooth && root.provider && root.provider.countBluetoothDevices("available") > 0

                    Column {
                        id: btAvailableSection
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: root.provider ? root.provider.bluetoothDeviceValues || [] : []

                            delegate: Rectangle {
                                width: btAvailableSection.width
                                height: visible ? 52 : 0
                                radius: 14
                                color: "transparent"
                                visible: root.bluetoothDeviceVisible(modelData, "available")

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.provider && root.provider.bluetoothEnabled
                                    onClicked: {
                                        if (root.provider)
                                            root.provider.handleBluetoothDevicePressed(modelData);
                                    }
                                }

                                Item {
                                    anchors.fill: parent
                                    anchors.margins: 12

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.provider ? root.provider.bluetoothGlyph : ""
                                        color: "#7f828a"
                                        font.pixelSize: 14
                                        font.family: root.iconFontFamily
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 26
                                        anchors.top: parent.top
                                        anchors.right: actionLabel.left
                                        anchors.rightMargin: 8
                                        text: root.provider ? root.provider.bluetoothDeviceName(modelData) : ""
                                        color: "#f5f5f7"
                                        font.pixelSize: 12
                                        font.family: root.textFontFamily
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 26
                                        anchors.bottom: parent.bottom
                                        anchors.right: actionLabel.left
                                        anchors.rightMargin: 8
                                        text: root.provider ? root.provider.bluetoothDeviceSubtitle(modelData) : ""
                                        color: "#9b9da4"
                                        font.pixelSize: 10
                                        font.family: root.textFontFamily
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: actionLabel
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData && modelData.pairing ? "Pairing" : "Pair"
                                        color: "#f5f5f7"
                                        font.pixelSize: 11
                                        font.family: root.textFontFamily
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

    }
}
