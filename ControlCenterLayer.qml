import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io

Item {
    id: controlCenter

    signal connectivityPanelRequested(string kind, bool open)

    UserConfig {
        id: userConfig
    }

    property bool showCondition: false
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily
    // ... rest of properties ...

    opacity: showCondition ? 1.0 : 0.0
    scale: showCondition ? 1.0 : 0.12
    transformOrigin: Item.Top

    Behavior on opacity {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutQuint
        }
    }
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
    property bool wifiPanelOpen: false
    property bool bluetoothPanelOpen: false

    property bool wifiEnabled: false
    property string wifiDeviceName: ""
    property string wifiCurrentSsid: ""
    property string wifiInfoMessage: ""
    property string wifiError: ""
    property bool wifiStateRefreshPending: false
    property bool wifiListRefreshPending: false
    property bool wifiListRefreshPendingRescan: false
    property string wifiStateStdout: ""
    property string wifiStateStderr: ""
    property string wifiListStdout: ""
    property string wifiListStderr: ""
    property string wifiActionStdout: ""
    property string wifiActionStderr: ""
    property string wifiActionKind: ""
    property string wifiActionTarget: ""
    property string wifiPendingPasswordSsid: ""
    property string wifiPendingPasswordValue: ""
    property bool wifiPendingPasswordSavedConnection: false
    property var savedWifiSsids: ({})

    property string bluetoothInfoMessage: ""
    property string bluetoothError: ""
    property string bluetoothPairAndConnectPath: ""
    property alias wifiNetworks: wifiNetworksModel

    readonly property real sliderKnobSize: 24
    readonly property color panelColor: "#000000"
    readonly property color moduleColor: "#1c1c1e"
    readonly property color moduleHover: "#232326"
    readonly property color trackColor: "#2c2c2e"
    readonly property color textPrimary: "#f5f5f7"
    readonly property color textSecondary: "#8e8e93"
    readonly property color cardAccent: "#0a84ff"
    readonly property color cardAccentPressed: "#0066d6"
    readonly property color cardFillActive: "#26272b"
    readonly property color cardFillHover: "#222327"
    readonly property color buttonFill: "#f5f5f7"
    readonly property color buttonFillHover: "#ffffff"
    readonly property color buttonFillPressed: "#e9e9ec"
    readonly property string wifiGlyph: ""
    readonly property string bluetoothGlyph: ""
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property var bluetoothDeviceValues: bluetoothAdapter ? bluetoothAdapter.devices.values : []
    readonly property bool wifiBusy: wifiStateProcess.running || wifiListProcess.running || wifiActionProcess.running
    readonly property bool wifiListRunning: wifiListProcess.running
    readonly property bool bluetoothEnabled: bluetoothAdapter ? bluetoothAdapter.enabled : false
    readonly property bool bluetoothBusy: bluetoothAdapter
        ? bluetoothAdapter.state === BluetoothAdapterState.Enabling
            || bluetoothAdapter.state === BluetoothAdapterState.Disabling
        : false
    readonly property bool anyConnectivityPanelOpen: wifiPanelOpen || bluetoothPanelOpen
    readonly property string wifiStatusText: {
        if (!wifiEnabled) return "Off";
        if (wifiCurrentSsid) return wifiCurrentSsid;
        return wifiBusy ? "Working..." : "On";
    }
    readonly property string bluetoothStatusText: buildBluetoothStatusText()

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function trimString(value) {
        if (value === undefined || value === null) return "";
        return String(value).trim();
    }

    function splitNmcliFields(line) {
        const result = [];
        let current = "";
        let escaping = false;

        for (let index = 0; index < line.length; index++) {
            const ch = line[index];
            if (escaping) {
                current += ch;
                escaping = false;
            } else if (ch === "\\") {
                escaping = true;
            } else if (ch === ":") {
                result.push(current);
                current = "";
            } else {
                current += ch;
            }
        }

        result.push(current);
        return result;
    }

    function labelForWifiSsid(ssid) {
        const trimmed = trimString(ssid);
        return trimmed.length > 0 ? trimmed : "Hidden network";
    }

    function firstUsefulLine(text) {
        const lines = String(text || "")
            .split(/\r?\n/)
            .map(line => trimString(line))
            .filter(line => line.length > 0);
        if (lines.length === 0) return "";
        return lines[0].replace(/^Error:\s*/, "");
    }

    function clearWifiPrompt() {
        wifiPendingPasswordSsid = "";
        wifiPendingPasswordValue = "";
        wifiPendingPasswordSavedConnection = false;
    }

    function clearWifiMessages() {
        wifiInfoMessage = "";
        wifiError = "";
    }

    function clearBluetoothMessages() {
        bluetoothInfoMessage = "";
        bluetoothError = "";
    }

    function isConnectivityPanelOpen(kind) {
        if (kind === "wifi") return wifiPanelOpen;
        if (kind === "bluetooth") return bluetoothPanelOpen;
        return false;
    }

    function setConnectivityPanelOpen(kind, open, emitSignal) {
        if (emitSignal === undefined)
            emitSignal = true;

        const nextOpen = !!open;
        let changed = false;

        if (kind === "wifi") {
            changed = wifiPanelOpen !== nextOpen;
            wifiPanelOpen = nextOpen;

            if (nextOpen) {
                if (showCondition) {
                    requestWifiStateRefresh();
                    if (wifiEnabled)
                        requestWifiListRefresh(true);
                }
            } else {
                clearWifiPrompt();
                clearWifiMessages();
            }
        } else if (kind === "bluetooth") {
            changed = bluetoothPanelOpen !== nextOpen;
            bluetoothPanelOpen = nextOpen;

            if (!nextOpen) {
                if (bluetoothAdapter && bluetoothAdapter.discovering)
                    bluetoothAdapter.discovering = false;
                bluetoothScanStopTimer.stop();
                bluetoothPairAndConnectPath = "";
                clearBluetoothMessages();
            }
        } else {
            return;
        }

        if (changed && emitSignal)
            connectivityPanelRequested(kind, nextOpen);
    }

    function toggleConnectivityOverlay(kind) {
        setConnectivityPanelOpen(kind, !isConnectivityPanelOpen(kind));
    }

    function closeConnectivityPanels(emitSignals) {
        if (emitSignals === undefined)
            emitSignals = true;

        setConnectivityPanelOpen("wifi", false, emitSignals);
        setConnectivityPanelOpen("bluetooth", false, emitSignals);
        clearWifiPrompt();
        clearWifiMessages();
        clearBluetoothMessages();
    }

    function requestWifiStateRefresh() {
        if (!showCondition) return;
        if (wifiStateProcess.running) {
            wifiStateRefreshPending = true;
            return;
        }

        wifiStateStdout = "";
        wifiStateStderr = "";
        wifiStateProcess.exec([
            "sh",
            "-lc",
            "nmcli -t -f WIFI general status;"
                + " printf '__QSSEP__\\n';"
                + " nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status;"
                + " printf '__QSSEP__\\n';"
                + " nmcli -t -f NAME,TYPE connection show"
        ]);
    }

    function requestWifiListRefresh(rescan) {
        if (!showCondition) return;
        if (!wifiEnabled) {
            wifiNetworksModel.clear();
            return;
        }

        if (wifiListProcess.running) {
            wifiListRefreshPending = true;
            wifiListRefreshPendingRescan = wifiListRefreshPendingRescan || rescan;
            return;
        }

        wifiListStdout = "";
        wifiListStderr = "";
        wifiListProcess.exec([
            "nmcli",
            "-t",
            "-f",
            "IN-USE,SSID,SIGNAL,SECURITY,BARS",
            "device",
            "wifi",
            "list",
            "--rescan",
            rescan ? "yes" : "no"
        ]);
    }

    function runWifiAction(command, kind, target) {
        if (wifiActionProcess.running) return;

        wifiActionKind = kind;
        wifiActionTarget = target || "";
        wifiActionStdout = "";
        wifiActionStderr = "";
        wifiError = "";
        if (kind !== "connect") wifiInfoMessage = "";
        wifiActionProcess.exec(command);
    }

    function toggleWifiEnabled() {
        clearWifiPrompt();
        runWifiAction(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"], "toggle", wifiEnabled ? "off" : "on");
    }

    function disconnectWifi() {
        if (!wifiDeviceName) {
            wifiError = "No Wi-Fi device is available.";
            return;
        }

        clearWifiPrompt();
        runWifiAction(["nmcli", "device", "disconnect", wifiDeviceName], "disconnect", wifiCurrentSsid);
    }

    function connectWifiNetwork(network) {
        if (!network) return;
        if (!wifiEnabled) {
            wifiError = "Turn on Wi-Fi first.";
            return;
        }
        if (network.connected) return;

        const ssid = trimString(network.ssid);
        const security = trimString(network.security);
        const savedConnection = !!network.savedConnection;

        if (!ssid) {
            wifiError = "Hidden networks are not supported in this panel yet.";
            return;
        }

        clearWifiPrompt();
        wifiError = "";

        if (savedConnection) {
            runWifiAction(["nmcli", "connection", "up", "id", ssid], "connect", ssid);
            return;
        }

        if (security.length === 0) {
            runWifiAction(["nmcli", "device", "wifi", "connect", ssid], "connect", ssid);
            return;
        }

        wifiPendingPasswordSsid = ssid;
        wifiPendingPasswordSavedConnection = false;
        wifiPendingPasswordValue = "";
        wifiInfoMessage = "Enter the password for " + ssid + ".";
    }

    function submitWifiPassword() {
        const ssid = trimString(wifiPendingPasswordSsid);
        if (!ssid) return;

        if (trimString(wifiPendingPasswordValue).length === 0) {
            wifiError = "Enter a password first.";
            return;
        }

        const password = wifiPendingPasswordValue;
        clearWifiPrompt();
        wifiError = "";
        runWifiAction(["nmcli", "device", "wifi", "connect", ssid, "password", password], "connect", ssid);
    }

    function parseWifiStateOutput(text) {
        const sections = String(text || "").split("__QSSEP__");
        const generalStatus = trimString(sections.length > 0 ? sections[0] : "");
        const deviceSection = trimString(sections.length > 1 ? sections[1] : "");
        const savedSection = trimString(sections.length > 2 ? sections[2] : "");

        wifiEnabled = generalStatus.indexOf("enabled") !== -1;

        let detectedDeviceName = "";
        let detectedSsid = "";

        const deviceLines = deviceSection.length > 0 ? deviceSection.split(/\r?\n/) : [];
        for (let index = 0; index < deviceLines.length; index++) {
            const fields = splitNmcliFields(trimString(deviceLines[index]));
            if (fields.length < 4 || fields[1] !== "wifi") continue;

            if (!detectedDeviceName) detectedDeviceName = trimString(fields[0]);

            const state = trimString(fields[2]);
            const connection = trimString(fields[3]);
            if (state.indexOf("connected") === 0) {
                detectedDeviceName = trimString(fields[0]);
                detectedSsid = connection;
                break;
            }
        }

        wifiDeviceName = detectedDeviceName;
        wifiCurrentSsid = wifiEnabled ? detectedSsid : "";

        const saved = {};
        const savedLines = savedSection.length > 0 ? savedSection.split(/\r?\n/) : [];
        for (let index = 0; index < savedLines.length; index++) {
            const fields = splitNmcliFields(trimString(savedLines[index]));
            if (fields.length < 2 || fields[1] !== "802-11-wireless") continue;

            const name = trimString(fields[0]);
            if (name.length > 0) saved[name] = true;
        }
        savedWifiSsids = saved;

        if (!wifiEnabled) {
            clearWifiPrompt();
            wifiNetworksModel.clear();
        }
    }

    function parseWifiListOutput(text) {
        wifiNetworksModel.clear();
        if (!wifiEnabled) return;

        const networksBySsid = {};
        const lines = String(text || "").split(/\r?\n/);

        for (let index = 0; index < lines.length; index++) {
            const line = trimString(lines[index]);
            if (line.length === 0) continue;

            const fields = splitNmcliFields(line);
            if (fields.length < 5) continue;

            const connected = trimString(fields[0]) === "*";
            const ssid = trimString(fields[1]);
            const signal = parseInt(trimString(fields[2]), 10);
            const security = trimString(fields[3]);
            const bars = trimString(fields[4]);
            const key = ssid.length > 0 ? ssid : "__hidden__";
            const nextNetwork = {
                ssid: ssid,
                displayName: labelForWifiSsid(ssid),
                signal: Number.isNaN(signal) ? 0 : signal,
                security: security,
                bars: bars,
                connected: connected,
                secure: security.length > 0,
                savedConnection: !!savedWifiSsids[ssid]
            };

            const currentNetwork = networksBySsid[key];
            if (!currentNetwork
                    || nextNetwork.connected
                    || (!currentNetwork.connected && nextNetwork.signal > currentNetwork.signal)) {
                networksBySsid[key] = nextNetwork;
            }
        }

        const networkKeys = Object.keys(networksBySsid);
        networkKeys.sort((leftKey, rightKey) => {
            const left = networksBySsid[leftKey];
            const right = networksBySsid[rightKey];

            if (left.connected !== right.connected) return left.connected ? -1 : 1;
            if (left.signal !== right.signal) return right.signal - left.signal;
            return left.displayName.localeCompare(right.displayName);
        });

        for (let index = 0; index < networkKeys.length; index++) {
            wifiNetworksModel.append(networksBySsid[networkKeys[index]]);
        }
    }

    function handleWifiMonitorLine(data) {
        const line = trimString(data);
        if (!showCondition || line.length === 0) return;
        wifiMonitorRefreshTimer.restart();
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

    function bluetoothDeviceName(device) {
        if (!device) return "Unknown device";
        const preferred = trimString(device.deviceName);
        if (preferred.length > 0) return preferred;

        const alias = trimString(device.name);
        if (alias.length > 0) return alias;

        const address = trimString(device.address);
        return address.length > 0 ? address : "Unknown device";
    }

    function bluetoothDeviceStateText(device) {
        if (!device) return "";
        if (device.pairing) return "Pairing";

        switch (device.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting";
        case BluetoothDeviceState.Connected:
            return "Connected";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting";
        default:
            break;
        }

        if (device.paired || device.bonded) return "Paired";
        return "Available";
    }

    function bluetoothDeviceSubtitle(device) {
        const parts = [];
        const stateLabel = bluetoothDeviceStateText(device);
        if (stateLabel.length > 0) parts.push(stateLabel);
        if (device && device.batteryAvailable) parts.push(Math.round(device.battery) + "%");
        return parts.join(" • ");
    }

    function bluetoothDeviceMatchesSection(device, section) {
        if (!device) return false;

        const paired = device.paired || device.bonded;
        if (section === "connected") return device.connected;
        if (section === "paired") return !device.connected && paired;
        if (section === "available") return !paired;
        return false;
    }

    function countBluetoothDevices(section) {
        let count = 0;
        const devices = bluetoothDeviceValues || [];

        for (let index = 0; index < devices.length; index++) {
            if (bluetoothDeviceMatchesSection(devices[index], section))
                count += 1;
        }

        return count;
    }

    function buildBluetoothStatusText() {
        if (!bluetoothAdapter) return "Unavailable";
        if (!bluetoothEnabled) return "Off";

        const devices = bluetoothDeviceValues || [];
        const connectedNames = [];

        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];
            if (device && device.connected)
                connectedNames.push(bluetoothDeviceName(device));
        }

        if (connectedNames.length === 1) return connectedNames[0];
        if (connectedNames.length > 1) return connectedNames[0] + " +" + (connectedNames.length - 1);
        if (bluetoothAdapter.discovering) return "Scanning";
        return bluetoothBusy ? "Working..." : "On";
    }

    function toggleBluetoothEnabled() {
        if (!bluetoothAdapter) {
            bluetoothError = "No Bluetooth adapter is available.";
            return;
        }

        bluetoothError = "";
        bluetoothInfoMessage = "";
        bluetoothPairAndConnectPath = "";

        if (bluetoothAdapter.discovering)
            bluetoothAdapter.discovering = false;

        bluetoothAdapter.enabled = !bluetoothAdapter.enabled;
    }

    function toggleBluetoothScan() {
        if (!bluetoothAdapter) {
            bluetoothError = "No Bluetooth adapter is available.";
            return;
        }
        if (!bluetoothEnabled) {
            bluetoothError = "Turn on Bluetooth first.";
            return;
        }

        bluetoothError = "";
        if (bluetoothAdapter.discovering) {
            bluetoothAdapter.discovering = false;
            bluetoothInfoMessage = "";
            bluetoothScanStopTimer.stop();
        } else {
            bluetoothAdapter.discovering = true;
            bluetoothInfoMessage = "Scanning for nearby devices...";
            bluetoothScanStopTimer.restart();
        }
    }

    function handleBluetoothDevicePressed(device) {
        if (!device) return;
        if (!bluetoothAdapter || !bluetoothEnabled) {
            bluetoothError = "Turn on Bluetooth first.";
            return;
        }

        bluetoothError = "";

        if (device.connected) {
            bluetoothInfoMessage = "";
            device.disconnect();
            return;
        }

        if (device.paired || device.bonded) {
            bluetoothInfoMessage = "";
            device.connect();
            return;
        }

        bluetoothPairAndConnectPath = device.dbusPath;
        bluetoothInfoMessage = "Pairing " + bluetoothDeviceName(device) + "...";
        device.pair();
    }

    function forgetBluetoothDevice(device) {
        if (!device) return;
        if (bluetoothPairAndConnectPath === device.dbusPath)
            bluetoothPairAndConnectPath = "";
        device.forget();
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
            sliderIntroPending = true;
            displayedBrightness = localBrightness;
            displayedVolume = localVolume;
            sliderIntroTimer.interval = sliderIntroDelay;
            sliderIntroTimer.restart();
            requestWifiStateRefresh();
            if (!wifiMonitorProcess.running)
                wifiMonitorProcess.running = true;
        } else {
            sliderIntroTimer.stop();
            sliderIntroPending = false;
            displayedBrightness = localBrightness;
            displayedVolume = localVolume;
            closeConnectivityPanels();
            if (wifiMonitorProcess.running)
                wifiMonitorProcess.running = false;
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

    Behavior on displayedBrightness {
        enabled: controlCenter.showCondition && !controlCenter.sliderIntroPending && !brightnessArea.pressed

        NumberAnimation {
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    Behavior on displayedVolume {
        enabled: controlCenter.showCondition && !controlCenter.sliderIntroPending && !volumeArea.pressed

        NumberAnimation {
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    ListModel {
        id: wifiNetworksModel
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

    Process {
        id: wifiStateProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: controlCenter.wifiStateStdout = text
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: controlCenter.wifiStateStderr = text
        }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                controlCenter.parseWifiStateOutput(controlCenter.wifiStateStdout);
            } else {
                controlCenter.wifiError = controlCenter.firstUsefulLine(controlCenter.wifiStateStderr || controlCenter.wifiStateStdout)
                    || "Unable to refresh Wi-Fi state.";
            }

            if (controlCenter.wifiStateRefreshPending) {
                controlCenter.wifiStateRefreshPending = false;
                controlCenter.requestWifiStateRefresh();
            }
        }
    }

    Process {
        id: wifiListProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: controlCenter.wifiListStdout = text
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: controlCenter.wifiListStderr = text
        }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                controlCenter.parseWifiListOutput(controlCenter.wifiListStdout);
            } else if (controlCenter.wifiEnabled) {
                controlCenter.wifiError = controlCenter.firstUsefulLine(controlCenter.wifiListStderr || controlCenter.wifiListStdout)
                    || "Unable to load nearby Wi-Fi networks.";
            }

            if (controlCenter.wifiListRefreshPending) {
                const rescan = controlCenter.wifiListRefreshPendingRescan;
                controlCenter.wifiListRefreshPending = false;
                controlCenter.wifiListRefreshPendingRescan = false;
                controlCenter.requestWifiListRefresh(rescan);
            }
        }
    }

    Process {
        id: wifiActionProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: controlCenter.wifiActionStdout = text
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: controlCenter.wifiActionStderr = text
        }
        onExited: function(exitCode) {
            const detail = controlCenter.firstUsefulLine(controlCenter.wifiActionStderr || controlCenter.wifiActionStdout);

            if (exitCode === 0) {
                switch (controlCenter.wifiActionKind) {
                case "toggle":
                    controlCenter.wifiInfoMessage = controlCenter.wifiActionTarget === "on"
                        ? "Wi-Fi turned on."
                        : "Wi-Fi turned off.";
                    break;
                case "connect":
                    controlCenter.wifiInfoMessage = controlCenter.wifiActionTarget.length > 0
                        ? "Connected to " + controlCenter.wifiActionTarget + "."
                        : "Connection updated.";
                    break;
                case "disconnect":
                    controlCenter.wifiInfoMessage = "Disconnected from Wi-Fi.";
                    break;
                default:
                    controlCenter.wifiInfoMessage = detail;
                    break;
                }
                controlCenter.wifiError = "";
            } else {
                controlCenter.wifiInfoMessage = "";
                controlCenter.wifiError = detail.length > 0 ? detail : "Wi-Fi action failed.";
            }

            controlCenter.requestWifiStateRefresh();
            if (controlCenter.wifiPanelOpen && controlCenter.wifiEnabled)
                controlCenter.requestWifiListRefresh(false);
        }
    }

    Process {
        id: wifiMonitorProcess
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: controlCenter.handleWifiMonitorLine(data)
        }
        onExited: {
            if (controlCenter.showCondition)
                running = true;
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

    Timer {
        id: wifiMonitorRefreshTimer
        interval: 220
        repeat: false
        onTriggered: {
            controlCenter.requestWifiStateRefresh();
            if (controlCenter.wifiPanelOpen && controlCenter.wifiEnabled)
                controlCenter.requestWifiListRefresh(false);
        }
    }

    Timer {
        id: bluetoothScanStopTimer
        interval: 8000
        repeat: false
        onTriggered: {
            if (controlCenter.bluetoothAdapter && controlCenter.bluetoothAdapter.discovering)
                controlCenter.bluetoothAdapter.discovering = false;
            controlCenter.bluetoothInfoMessage = "";
        }
    }

    Connections {
        target: bluetoothAdapter

        function onEnabledChanged() {
            if (!controlCenter.bluetoothAdapter.enabled) {
                controlCenter.bluetoothPairAndConnectPath = "";
                controlCenter.bluetoothInfoMessage = "";
                controlCenter.bluetoothError = "";
                controlCenter.bluetoothScanStopTimer.stop();
            }
        }

        function onDiscoveringChanged() {
            if (!controlCenter.bluetoothAdapter.discovering)
                controlCenter.bluetoothScanStopTimer.stop();
        }
    }

    Component {
        id: bluetoothDeviceDelegate

        Rectangle {
            id: deviceCard
            property var modelData
            property var deviceObject: modelData
            property string section: ""

            width: parent ? parent.width : 0
            height: visible ? 60 : 0
            radius: 16
            color: deviceObject.connected ? "#1f3554" : controlCenter.moduleColor
            visible: controlCenter.bluetoothDeviceMatchesSection(deviceObject, section)

            Behavior on color {
                ColorAnimation {
                    duration: 130
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: controlCenter.bluetoothEnabled
                onClicked: controlCenter.handleBluetoothDevicePressed(deviceCard.deviceObject)
            }

            Item {
                anchors.fill: parent
                anchors.margins: 12

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.right: actionLabel.left
                    anchors.rightMargin: 8
                    text: controlCenter.bluetoothDeviceName(deviceCard.deviceObject)
                    color: controlCenter.textPrimary
                    font.pixelSize: 13
                    font.family: controlCenter.textFontFamily
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.rightMargin: forgetButton.visible ? 64 : 0
                    text: controlCenter.bluetoothDeviceSubtitle(deviceCard.deviceObject)
                    color: controlCenter.textSecondary
                    font.pixelSize: 11
                    font.family: controlCenter.textFontFamily
                    elide: Text.ElideRight
                }

                Text {
                    id: actionLabel
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: deviceCard.deviceObject.pairing
                        ? "Pairing"
                        : (deviceCard.deviceObject.connected
                            ? "Disconnect"
                            : ((deviceCard.deviceObject.paired || deviceCard.deviceObject.bonded) ? "Connect" : "Pair"))
                    color: deviceCard.deviceObject.connected ? "#87b7ff" : "#8e8e93"
                    font.pixelSize: 11
                    font.family: controlCenter.textFontFamily
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: forgetButton
                    width: 46
                    height: 18
                    radius: 9
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    color: "#2c2c2e"
                    visible: deviceCard.deviceObject.paired || deviceCard.deviceObject.bonded

                    Text {
                        anchors.centerIn: parent
                        text: "Forget"
                        color: "#d0d0d4"
                        font.pixelSize: 9
                        font.family: controlCenter.textFontFamily
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: function(mouse) {
                            mouse.accepted = true;
                            controlCenter.forgetBluetoothDevice(deviceCard.deviceObject);
                        }
                    }
                }
            }

            Connections {
                target: deviceObject

                function onPairedChanged() {
                    if (controlCenter.bluetoothPairAndConnectPath !== deviceCard.deviceObject.dbusPath)
                        return;

                    if (deviceCard.deviceObject.paired || deviceCard.deviceObject.bonded) {
                        deviceCard.deviceObject.trusted = true;
                        deviceCard.deviceObject.connect();
                        controlCenter.bluetoothInfoMessage = "Connecting to " + controlCenter.bluetoothDeviceName(deviceCard.deviceObject) + "...";
                    }
                }

                function onPairingChanged() {
                    if (controlCenter.bluetoothPairAndConnectPath !== deviceCard.deviceObject.dbusPath)
                        return;

                    if (!deviceCard.deviceObject.pairing
                            && !(deviceCard.deviceObject.paired || deviceCard.deviceObject.bonded)) {
                        controlCenter.bluetoothPairAndConnectPath = "";
                        controlCenter.bluetoothInfoMessage = "";
                        controlCenter.bluetoothError = "Pairing failed or the device needs a PIN.";
                    }
                }

                function onConnectedChanged() {
                    if (controlCenter.bluetoothPairAndConnectPath !== deviceCard.deviceObject.dbusPath)
                        return;

                    if (deviceCard.deviceObject.connected) {
                        controlCenter.bluetoothPairAndConnectPath = "";
                        controlCenter.bluetoothInfoMessage = "";
                        controlCenter.bluetoothError = "";
                    }
                }
            }
        }
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

        Item {
            width: parent.width
            height: 80

            Row {
                id: connectivityCardsRow
                anchors.fill: parent
                spacing: 12

                Rectangle {
                    id: wifiCard
                    width: (connectivityCardsRow.width - connectivityCardsRow.spacing) / 2
                    height: connectivityCardsRow.height
                    radius: 20
                    color: (wifiCardMouse.containsMouse || wifiPanelOpen) ? "#3a3a3d" : "#343437"

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    MouseArea {
                        id: wifiCardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        text: wifiGlyph
                        color: wifiEnabled ? cardAccent : "#878a92"
                        font.pixelSize: 18
                        font.family: iconFontFamily
                    }

                    Rectangle {
                        id: wifiSwitchTrack
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        width: 34
                        height: 20
                        radius: 10
                        color: wifiEnabled ? "#34c759" : "#63656c"

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            y: 2
                            x: wifiEnabled ? 16 : 2
                            color: "#ffffff"

                            Behavior on x {
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            id: wifiToggleArea
                            anchors.fill: parent
                            enabled: !wifiBusy
                            onClicked: controlCenter.toggleWifiEnabled()
                        }
                    }

                    Item {
                        id: wifiDetailButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 8
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.right: wifiChevron.left
                            anchors.rightMargin: 8
                            anchors.top: parent.top
                            text: "Wi-Fi"
                            color: textPrimary
                            font.pixelSize: 13
                            font.family: textFontFamily
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: wifiChevron.left
                            anchors.rightMargin: 8
                            anchors.bottom: parent.bottom
                            text: wifiEnabled
                                ? (wifiCurrentSsid.length > 0 ? "Connected • " + wifiCurrentSsid : "On")
                                : "Off"
                            color: "#9b9da4"
                            font.pixelSize: 10
                            font.family: textFontFamily
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            id: wifiChevron
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: wifiPanelOpen ? "#c7c9cf" : "#8f9198"
                            font.pixelSize: 17
                            font.family: textFontFamily
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: controlCenter.toggleConnectivityOverlay("wifi")
                        }
                    }
                }

                Rectangle {
                    id: bluetoothCard
                    width: (connectivityCardsRow.width - connectivityCardsRow.spacing) / 2
                    height: connectivityCardsRow.height
                    radius: 20
                    color: (bluetoothCardMouse.containsMouse || bluetoothPanelOpen) ? "#3a3a3d" : "#343437"

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    MouseArea {
                        id: bluetoothCardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        text: bluetoothGlyph
                        color: bluetoothEnabled ? cardAccent : "#878a92"
                        font.pixelSize: 18
                        font.family: iconFontFamily
                    }

                    Rectangle {
                        id: bluetoothSwitchTrack
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        width: 34
                        height: 20
                        radius: 10
                        color: bluetoothEnabled ? "#34c759" : "#63656c"

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            y: 2
                            x: bluetoothEnabled ? 16 : 2
                            color: "#ffffff"

                            Behavior on x {
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            id: bluetoothToggleArea
                            anchors.fill: parent
                            enabled: !bluetoothBusy
                            onClicked: controlCenter.toggleBluetoothEnabled()
                        }
                    }

                    Item {
                        id: bluetoothDetailButton
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 8
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.right: bluetoothChevron.left
                            anchors.rightMargin: 8
                            anchors.top: parent.top
                            text: "Bluetooth"
                            color: textPrimary
                            font.pixelSize: 13
                            font.family: textFontFamily
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: bluetoothChevron.left
                            anchors.rightMargin: 8
                            anchors.bottom: parent.bottom
                            text: !bluetoothEnabled
                                ? "Off"
                                : (countBluetoothDevices("connected") > 0
                                    ? countBluetoothDevices("connected") + " device(s) connected"
                                    : "On")
                            color: "#9b9da4"
                            font.pixelSize: 10
                            font.family: textFontFamily
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            id: bluetoothChevron
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: bluetoothPanelOpen ? "#c7c9cf" : "#8f9198"
                            font.pixelSize: 17
                            font.family: textFontFamily
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: controlCenter.toggleConnectivityOverlay("bluetooth")
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
                        width: controlCenter.displayedBrightness <= 0.001
                            ? 0
                            : Math.max(34, Math.min(brightnessTrack.width, brightnessTrack.width * controlCenter.displayedBrightness + 1))
                        height: parent.height
                        radius: parent.radius
                        color: "#f5f5f7"
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
                    }

                    MouseArea {
                        id: brightnessArea
                        anchors.fill: parent
                        hoverEnabled: true

                        function update(mouseX) {
                            controlCenter.queueBrightness(controlCenter.clamp01(mouseX / width));
                        }

                        onPressed: function(mouse) {
                            if (controlCenter.sliderIntroPending) {
                                sliderIntroTimer.stop();
                                controlCenter.sliderIntroPending = false;
                                controlCenter.displayedBrightness = controlCenter.localBrightness;
                                controlCenter.displayedVolume = controlCenter.localVolume;
                            }
                            update(mouse.x);
                        }
                        onPositionChanged: function(mouse) {
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
                        width: controlCenter.displayedVolume <= 0.001
                            ? 0
                            : Math.max(34, Math.min(volumeTrack.width, volumeTrack.width * controlCenter.displayedVolume + 1))
                        height: parent.height
                        radius: parent.radius
                        color: "#f5f5f7"
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
                    }

                    MouseArea {
                        id: volumeArea
                        anchors.fill: parent
                        hoverEnabled: true

                        function update(mouseX) {
                            controlCenter.queueVolume(controlCenter.clamp01(mouseX / width));
                        }

                        onPressed: function(mouse) {
                            if (controlCenter.sliderIntroPending) {
                                sliderIntroTimer.stop();
                                controlCenter.sliderIntroPending = false;
                                controlCenter.displayedBrightness = controlCenter.localBrightness;
                                controlCenter.displayedVolume = controlCenter.localVolume;
                            }
                            update(mouse.x);
                        }
                        onPositionChanged: function(mouse) {
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
