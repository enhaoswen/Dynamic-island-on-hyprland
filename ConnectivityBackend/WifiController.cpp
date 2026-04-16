#include "WifiController.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <QDBusReply>
#include <QDBusVariant>
#include <QMap>
#include <QMetaType>
#include <QSet>
#include <QVariant>
#include <QUuid>
#include <algorithm>

using ConnectionSettingsMap = WifiController::ConnectionSettingsMap;
using ObjectPathList = QList<QDBusObjectPath>;

Q_DECLARE_METATYPE(ConnectionSettingsMap)
Q_DECLARE_METATYPE(ObjectPathList)

namespace {

constexpr auto kDbusService = "org.freedesktop.DBus";
constexpr auto kDbusPath = "/org/freedesktop/DBus";
constexpr auto kDbusInterface = "org.freedesktop.DBus";
constexpr auto kDbusPropertiesInterface = "org.freedesktop.DBus.Properties";
constexpr auto kNetworkManagerService = "org.freedesktop.NetworkManager";
constexpr auto kNetworkManagerPath = "/org/freedesktop/NetworkManager";
constexpr auto kNetworkManagerInterface = "org.freedesktop.NetworkManager";
constexpr auto kNetworkManagerDeviceInterface = "org.freedesktop.NetworkManager.Device";
constexpr auto kNetworkManagerWirelessInterface = "org.freedesktop.NetworkManager.Device.Wireless";
constexpr auto kNetworkManagerAccessPointInterface = "org.freedesktop.NetworkManager.AccessPoint";
constexpr auto kNetworkManagerSettingsPath = "/org/freedesktop/NetworkManager/Settings";
constexpr auto kNetworkManagerSettingsInterface = "org.freedesktop.NetworkManager.Settings";
constexpr auto kNetworkManagerSettingsConnectionInterface = "org.freedesktop.NetworkManager.Settings.Connection";
constexpr auto kIwdService = "net.connman.iwd";
constexpr auto kConnmanService = "net.connman";
constexpr auto kRootPath = "/";

constexpr uint kWifiDeviceType = 2;
constexpr uint kAccessPointPrivacyFlag = 0x1;

QDBusArgument &operator<<(QDBusArgument &argument, const ConnectionSettingsMap &settings) {
    argument.beginMap(QMetaType::fromType<QString>(), QMetaType::fromType<QVariantMap>());
    for (auto it = settings.cbegin(); it != settings.cend(); ++it) {
        argument.beginMapEntry();
        argument << it.key() << it.value();
        argument.endMapEntry();
    }
    argument.endMap();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, ConnectionSettingsMap &settings) {
    settings.clear();
    argument.beginMap();
    while (!argument.atEnd()) {
        QString key;
        QVariantMap value;
        argument.beginMapEntry();
        argument >> key >> value;
        argument.endMapEntry();
        settings.insert(key, value);
    }
    argument.endMap();
    return argument;
}

QVariant unwrapVariant(const QVariant &variant) {
    if (variant.metaType().id() == qMetaTypeId<QDBusVariant>())
        return qvariant_cast<QDBusVariant>(variant).variant();
    return variant;
}

QString decodeSsid(const QByteArray &ssidBytes) {
    if (ssidBytes.isEmpty())
        return {};

    const QString utf8 = QString::fromUtf8(ssidBytes);
    return utf8.contains(QChar::ReplacementCharacter) ? QString::fromLatin1(ssidBytes) : utf8;
}

QByteArray byteArrayFromVariant(const QVariant &variant) {
    const QVariant raw = unwrapVariant(variant);

    if (raw.metaType().id() == QMetaType::QByteArray)
        return raw.toByteArray();

    if (raw.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = qvariant_cast<QDBusArgument>(raw);
        return qdbus_cast<QByteArray>(argument);
    }

    if (raw.metaType().id() == QMetaType::QVariantList) {
        QByteArray bytes;
        const QVariantList values = raw.toList();
        bytes.reserve(values.size());
        for (const QVariant &value : values)
            bytes.append(static_cast<char>(value.toUInt()));
        return bytes;
    }

    return {};
}

ConnectionSettingsMap connectionSettingsFromVariant(const QVariant &variant) {
    const QVariant raw = unwrapVariant(variant);

    if (raw.metaType().id() == qMetaTypeId<ConnectionSettingsMap>())
        return qvariant_cast<ConnectionSettingsMap>(raw);

    if (raw.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = qvariant_cast<QDBusArgument>(raw);
        return qdbus_cast<ConnectionSettingsMap>(argument);
    }

    return {};
}

ObjectPathList objectPathsFromVariant(const QVariant &variant) {
    const QVariant raw = unwrapVariant(variant);

    if (raw.metaType().id() == qMetaTypeId<ObjectPathList>())
        return qvariant_cast<ObjectPathList>(raw);

    if (raw.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = qvariant_cast<QDBusArgument>(raw);
        return qdbus_cast<ObjectPathList>(argument);
    }

    if (raw.metaType().id() == QMetaType::QStringList) {
        ObjectPathList paths;
        for (const QString &path : raw.toStringList())
            paths.append(QDBusObjectPath(path));
        return paths;
    }

    return {};
}

QString objectPathFromVariant(const QVariant &variant) {
    const QVariant raw = unwrapVariant(variant);

    if (raw.metaType().id() == qMetaTypeId<QDBusObjectPath>())
        return qvariant_cast<QDBusObjectPath>(raw).path();

    if (raw.metaType().id() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = qvariant_cast<QDBusArgument>(raw);
        return qdbus_cast<QDBusObjectPath>(argument).path();
    }

    return raw.toString();
}

QString labelForSsid(const QString &ssid) {
    const QString trimmed = ssid.trimmed();
    return trimmed.isEmpty() ? QStringLiteral("Hidden network") : trimmed;
}

bool isValidPath(const QString &path) {
    return !path.isEmpty() && path != QLatin1String(kRootPath);
}

QString titleCaseBackendName(const QString &backendName) {
    if (backendName == QLatin1String("iwd"))
        return QStringLiteral("iwd");
    if (backendName == QLatin1String("connman"))
        return QStringLiteral("ConnMan");
    if (backendName == QLatin1String("networkmanager"))
        return QStringLiteral("NetworkManager");
    return QStringLiteral("Wi-Fi");
}

} // namespace

WifiController::WifiController(QObject *parent)
    : QObject(parent) {
    qDBusRegisterMetaType<ConnectionSettingsMap>();
    qRegisterMetaType<ConnectionSettingsMap>("ConnectionSettingsMap");

    m_stateRefreshTimer.setSingleShot(true);
    m_stateRefreshTimer.setInterval(80);
    connect(&m_stateRefreshTimer, &QTimer::timeout, this, &WifiController::refreshStateInternal);

    m_networkRefreshTimer.setSingleShot(true);
    m_networkRefreshTimer.setInterval(120);
    connect(&m_networkRefreshTimer, &QTimer::timeout, this, [this]() {
        refreshNetworksInternal(false, true);
    });

    m_scanTimeoutTimer.setSingleShot(true);
    m_scanTimeoutTimer.setInterval(5000);
    connect(&m_scanTimeoutTimer, &QTimer::timeout, this, [this]() {
        setScanningState(false);
        refreshNetworksInternal(false, true);
    });

    QDBusConnection::systemBus().connect(
        kDbusService,
        kDbusPath,
        kDbusInterface,
        "NameOwnerChanged",
        this,
        SLOT(handleNameOwnerChanged(QString,QString,QString))
    );

    detectBackend();
}

QString WifiController::backendName() const {
    return m_backendName;
}

bool WifiController::supported() const {
    return m_supported;
}

bool WifiController::readOnly() const {
    return m_readOnly;
}

bool WifiController::available() const {
    return m_available;
}

bool WifiController::enabled() const {
    return m_enabled;
}

bool WifiController::busy() const {
    return m_busy;
}

bool WifiController::scanning() const {
    return m_scanning;
}

QString WifiController::currentSsid() const {
    return m_currentSsid;
}

QString WifiController::statusText() const {
    return m_statusText;
}

QString WifiController::infoMessage() const {
    return m_infoMessage;
}

QString WifiController::errorMessage() const {
    return m_errorMessage;
}

QString WifiController::unsupportedReason() const {
    return m_unsupportedReason;
}

QAbstractItemModel *WifiController::networks() {
    return &m_networks;
}

void WifiController::refreshState() {
    if (m_backendName == QLatin1String("networkmanager")) {
        refreshStateInternal();
        return;
    }

    detectBackend();
}

void WifiController::refreshNetworks(bool rescan) {
    refreshNetworksInternal(rescan, false);
}

void WifiController::setEnabled(bool enabled) {
    clearMessages();

    if (!m_supported) {
        setErrorMessage(m_unsupportedReason.isEmpty() ? QStringLiteral("Wi-Fi control is unavailable.") : m_unsupportedReason);
        return;
    }

    if (!m_available || !isValidPath(m_wifiDevicePath)) {
        setErrorMessage(QStringLiteral("No Wi-Fi device is available."));
        return;
    }

    m_actionInProgress = true;
    updateBusyState();

    QString failure;
    const bool changed = setProperty(
        kNetworkManagerService,
        kNetworkManagerPath,
        kNetworkManagerInterface,
        QStringLiteral("WirelessEnabled"),
        enabled,
        &failure
    );

    m_actionInProgress = false;
    updateBusyState();

    if (!changed) {
        setErrorMessage(failure.isEmpty() ? QStringLiteral("Unable to update Wi-Fi state.") : failure);
        return;
    }

    setInfoMessage(enabled ? QStringLiteral("Wi-Fi turned on.") : QStringLiteral("Wi-Fi turned off."));
    refreshStateInternal();
}

void WifiController::disconnectCurrent() {
    clearMessages();

    if (!m_supported) {
        setErrorMessage(m_unsupportedReason.isEmpty() ? QStringLiteral("Wi-Fi control is unavailable.") : m_unsupportedReason);
        return;
    }

    if (!m_available || !isValidPath(m_wifiDevicePath)) {
        setErrorMessage(QStringLiteral("No Wi-Fi device is available."));
        return;
    }

    m_actionInProgress = true;
    updateBusyState();

    const QDBusMessage reply = callMethod(
        kNetworkManagerService,
        m_wifiDevicePath,
        kNetworkManagerDeviceInterface,
        QStringLiteral("Disconnect")
    );

    m_actionInProgress = false;
    updateBusyState();

    if (reply.type() == QDBusMessage::ErrorMessage) {
        setErrorMessage(errorTextForReply(reply, QStringLiteral("Unable to disconnect Wi-Fi.")));
        return;
    }

    setInfoMessage(QStringLiteral("Disconnected from Wi-Fi."));
    refreshStateInternal();
}

void WifiController::connectToNetwork(const QString &ssid, const QString &password) {
    clearMessages();

    const QString trimmedSsid = ssid.trimmed();
    if (trimmedSsid.isEmpty()) {
        setErrorMessage(QStringLiteral("Hidden networks are not supported in this panel yet."));
        return;
    }

    if (!m_supported) {
        setErrorMessage(m_unsupportedReason.isEmpty() ? QStringLiteral("Wi-Fi control is unavailable.") : m_unsupportedReason);
        return;
    }

    if (!m_available || !isValidPath(m_wifiDevicePath)) {
        setErrorMessage(QStringLiteral("No Wi-Fi device is available."));
        return;
    }

    if (!m_enabled) {
        setErrorMessage(QStringLiteral("Turn on Wi-Fi first."));
        return;
    }

    const auto selectedNetwork = m_networks.networkForSsid(trimmedSsid);
    if (!selectedNetwork.has_value()) {
        setErrorMessage(QStringLiteral("Selected network is no longer available."));
        return;
    }

    if (selectedNetwork->connected)
        return;

    const QString accessPointPath = selectedNetwork->objectPath;
    m_actionInProgress = true;
    updateBusyState();

    bool ok = false;
    if (selectedNetwork->savedConnection) {
        ok = activateSavedConnection(trimmedSsid, accessPointPath);
    } else {
        ok = addAndActivateConnection(trimmedSsid, accessPointPath, password, selectedNetwork->secure);
    }

    m_actionInProgress = false;
    updateBusyState();

    if (!ok)
        return;

    m_savedConnectionsDirty = true;
    setInfoMessage(QStringLiteral("Connecting to %1...").arg(trimmedSsid));
    refreshStateInternal();
}

void WifiController::clearMessages() {
    setInfoMessage({});
    setErrorMessage({});
}

void WifiController::handleNameOwnerChanged(const QString &name, const QString &, const QString &) {
    if (name == QLatin1String(kNetworkManagerService)
            || name == QLatin1String(kIwdService)
            || name == QLatin1String(kConnmanService)) {
        detectBackend();
    }
}

void WifiController::handleManagerPropertiesChanged(const QString &interfaceName, const QVariantMap &, const QStringList &) {
    if (interfaceName != QLatin1String(kNetworkManagerInterface))
        return;

    m_stateRefreshTimer.start();
}

void WifiController::handleDevicePropertiesChanged(const QString &interfaceName, const QVariantMap &changedProperties, const QStringList &) {
    if (interfaceName == QLatin1String(kNetworkManagerDeviceInterface)) {
        m_stateRefreshTimer.start();
        return;
    }

    if (interfaceName != QLatin1String(kNetworkManagerWirelessInterface))
        return;

    if (changedProperties.contains(QStringLiteral("LastScan"))) {
        setScanningState(false);
        m_scanTimeoutTimer.stop();
    }

    m_networkRefreshTimer.start();
}

void WifiController::handleAccessPointAdded(const QDBusObjectPath &) {
    m_networkRefreshTimer.start();
}

void WifiController::handleAccessPointRemoved(const QDBusObjectPath &) {
    m_networkRefreshTimer.start();
}

void WifiController::handleDeviceAdded(const QDBusObjectPath &) {
    m_stateRefreshTimer.start();
}

void WifiController::handleDeviceRemoved(const QDBusObjectPath &) {
    m_stateRefreshTimer.start();
}

void WifiController::handleNewConnection(const QDBusObjectPath &) {
    m_savedConnectionsDirty = true;
    m_stateRefreshTimer.start();
    m_networkRefreshTimer.start();
}

void WifiController::handleConnectionRemoved(const QDBusObjectPath &) {
    m_savedConnectionsDirty = true;
    m_stateRefreshTimer.start();
    m_networkRefreshTimer.start();
}

void WifiController::detectBackend() {
    QDBusConnectionInterface *busInterface = QDBusConnection::systemBus().interface();
    if (!busInterface) {
        clearUnsupportedState(QStringLiteral("unsupported"), false, QStringLiteral("System D-Bus is unavailable."));
        return;
    }

    const bool hasNetworkManager = busInterface->isServiceRegistered(kNetworkManagerService);
    const bool hasIwd = busInterface->isServiceRegistered(kIwdService);
    const bool hasConnman = busInterface->isServiceRegistered(kConnmanService);

    if (!m_managerSignalsConnected) {
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            kNetworkManagerPath,
            kDbusPropertiesInterface,
            "PropertiesChanged",
            this,
            SLOT(handleManagerPropertiesChanged(QString,QVariantMap,QStringList))
        );
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            kNetworkManagerPath,
            kNetworkManagerInterface,
            "DeviceAdded",
            this,
            SLOT(handleDeviceAdded(QDBusObjectPath))
        );
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            kNetworkManagerPath,
            kNetworkManagerInterface,
            "DeviceRemoved",
            this,
            SLOT(handleDeviceRemoved(QDBusObjectPath))
        );
        m_managerSignalsConnected = true;
    }

    if (!m_settingsSignalsConnected) {
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            kNetworkManagerSettingsPath,
            kNetworkManagerSettingsInterface,
            "NewConnection",
            this,
            SLOT(handleNewConnection(QDBusObjectPath))
        );
        QDBusConnection::systemBus().connect(
            kNetworkManagerService,
            kNetworkManagerSettingsPath,
            kNetworkManagerSettingsInterface,
            "ConnectionRemoved",
            this,
            SLOT(handleConnectionRemoved(QDBusObjectPath))
        );
        m_settingsSignalsConnected = true;
    }

    if (hasNetworkManager) {
        setBackendName(QStringLiteral("networkmanager"));
        setSupported(true);
        setReadOnly(false);
        setUnsupportedReason({});
        refreshStateInternal();
        return;
    }

    disconnectDeviceSignals();
    m_savedConnectionsBySsid.clear();
    m_savedConnectionsDirty = true;
    m_stateRefreshTimer.stop();
    m_networkRefreshTimer.stop();
    m_scanTimeoutTimer.stop();
    setScanningState(false);
    m_actionInProgress = false;
    updateBusyState();
    setEnabledState(false);
    setCurrentSsid({});
    m_networks.clear();
    m_wifiDevicePath.clear();

    if (hasIwd) {
        clearUnsupportedState(
            QStringLiteral("iwd"),
            true,
            QStringLiteral("Detected iwd, but this panel currently only supports NetworkManager.")
        );
        return;
    }

    if (hasConnman) {
        clearUnsupportedState(
            QStringLiteral("connman"),
            true,
            QStringLiteral("Detected ConnMan, but this panel currently only supports NetworkManager.")
        );
        return;
    }

    clearUnsupportedState(
        QStringLiteral("unsupported"),
        false,
        QStringLiteral("No supported Wi-Fi backend was detected.")
    );
}

void WifiController::refreshStateInternal() {
    if (m_backendName != QLatin1String("networkmanager")) {
        updateStatusText();
        return;
    }

    const QString previousDevicePath = m_wifiDevicePath;
    const ObjectPathList devices = objectPathsFromVariant(getProperty(
        kNetworkManagerService,
        kNetworkManagerPath,
        kNetworkManagerInterface,
        QStringLiteral("Devices")
    ));

    QString nextWifiDevicePath;
    for (const QDBusObjectPath &devicePath : devices) {
        const uint deviceType = getProperty(
            kNetworkManagerService,
            devicePath.path(),
            kNetworkManagerDeviceInterface,
            QStringLiteral("DeviceType")
        ).toUInt();

        if (deviceType == kWifiDeviceType) {
            nextWifiDevicePath = devicePath.path();
            break;
        }
    }

    m_wifiDevicePath = nextWifiDevicePath;
    if (previousDevicePath != m_wifiDevicePath)
        reconnectDeviceSignals(m_wifiDevicePath);

    setSupported(true);
    setReadOnly(false);
    setUnsupportedReason({});

    const bool wirelessEnabled = getProperty(
        kNetworkManagerService,
        kNetworkManagerPath,
        kNetworkManagerInterface,
        QStringLiteral("WirelessEnabled")
    ).toBool();
    setEnabledState(wirelessEnabled);

    if (!isValidPath(m_wifiDevicePath)) {
        setScanningState(false);
        setAvailable(false);
        setCurrentSsid({});
        m_networks.clear();
        updateStatusText();
        return;
    }

    setAvailable(true);

    if (!wirelessEnabled) {
        setScanningState(false);
        setCurrentSsid({});
        m_networks.clear();
        updateStatusText();
        return;
    }

    if (m_savedConnectionsDirty)
        reloadSavedConnections();

    const QString activeAccessPointPath = objectPathFromVariant(getProperty(
        kNetworkManagerService,
        m_wifiDevicePath,
        kNetworkManagerWirelessInterface,
        QStringLiteral("ActiveAccessPoint")
    ));

    if (isValidPath(activeAccessPointPath)) {
        const QString activeSsid = decodeSsid(byteArrayFromVariant(getProperty(
            kNetworkManagerService,
            activeAccessPointPath,
            kNetworkManagerAccessPointInterface,
            QStringLiteral("Ssid")
        )));
        setCurrentSsid(activeSsid);
        if (!activeSsid.isEmpty() && m_infoMessage.startsWith(QStringLiteral("Connecting to ")))
            setInfoMessage({});
    } else {
        setCurrentSsid({});
    }

    updateStatusText();
    refreshNetworksInternal(false, true);
}

void WifiController::refreshNetworksInternal(bool rescan, bool triggeredBySignal) {
    if (!m_supported || !m_available || !m_enabled || !isValidPath(m_wifiDevicePath)) {
        m_networks.clear();
        if (!triggeredBySignal)
            setScanningState(false);
        updateStatusText();
        return;
    }

    if (rescan) {
        clearMessages();
        const QDBusMessage scanReply = callMethod(
            kNetworkManagerService,
            m_wifiDevicePath,
            kNetworkManagerWirelessInterface,
            QStringLiteral("RequestScan"),
            {QVariant::fromValue(QVariantMap {})}
        );

        if (scanReply.type() == QDBusMessage::ErrorMessage) {
            setScanningState(false);
            setErrorMessage(errorTextForReply(scanReply, QStringLiteral("Unable to scan for nearby Wi-Fi networks.")));
        } else {
            setScanningState(true);
            m_scanTimeoutTimer.start();
        }
    }

    const QDBusMessage reply = callMethod(
        kNetworkManagerService,
        m_wifiDevicePath,
        kNetworkManagerWirelessInterface,
        QStringLiteral("GetAllAccessPoints")
    );

    if (reply.type() == QDBusMessage::ErrorMessage) {
        if (!triggeredBySignal)
            setScanningState(false);
        setErrorMessage(errorTextForReply(reply, QStringLiteral("Unable to load nearby Wi-Fi networks.")));
        return;
    }

    const ObjectPathList accessPoints = objectPathsFromVariant(reply.arguments().value(0));
    QMap<QString, WifiNetworkModel::NetworkEntry> networksByKey;

    for (const QDBusObjectPath &accessPoint : accessPoints) {
        const QString accessPointPath = accessPoint.path();
        const QString ssid = decodeSsid(byteArrayFromVariant(getProperty(
            kNetworkManagerService,
            accessPointPath,
            kNetworkManagerAccessPointInterface,
            QStringLiteral("Ssid")
        )));
        const int signal = getProperty(
            kNetworkManagerService,
            accessPointPath,
            kNetworkManagerAccessPointInterface,
            QStringLiteral("Strength")
        ).toInt();
        const uint flags = getProperty(
            kNetworkManagerService,
            accessPointPath,
            kNetworkManagerAccessPointInterface,
            QStringLiteral("Flags")
        ).toUInt();
        const uint wpaFlags = getProperty(
            kNetworkManagerService,
            accessPointPath,
            kNetworkManagerAccessPointInterface,
            QStringLiteral("WpaFlags")
        ).toUInt();
        const uint rsnFlags = getProperty(
            kNetworkManagerService,
            accessPointPath,
            kNetworkManagerAccessPointInterface,
            QStringLiteral("RsnFlags")
        ).toUInt();
        const bool secure = (flags & kAccessPointPrivacyFlag) != 0 || wpaFlags != 0 || rsnFlags != 0;
        const bool connected = !m_currentSsid.isEmpty() && ssid == m_currentSsid;
        const QString key = ssid.isEmpty() ? QStringLiteral("__hidden__") : ssid;

        WifiNetworkModel::NetworkEntry nextEntry;
        nextEntry.objectPath = accessPointPath;
        nextEntry.ssid = ssid;
        nextEntry.displayName = labelForSsid(ssid);
        nextEntry.signal = signal;
        nextEntry.secure = secure;
        nextEntry.savedConnection = m_savedConnectionsBySsid.contains(ssid);
        nextEntry.connected = connected;

        const auto existing = networksByKey.constFind(key);
        if (existing == networksByKey.cend()
                || nextEntry.connected
                || (!existing->connected && nextEntry.signal > existing->signal)) {
            networksByKey.insert(key, nextEntry);
        }
    }

    QVector<WifiNetworkModel::NetworkEntry> orderedNetworks = networksByKey.values().toVector();
    std::sort(orderedNetworks.begin(), orderedNetworks.end(), [](const auto &left, const auto &right) {
        if (left.connected != right.connected)
            return left.connected;
        if (left.signal != right.signal)
            return left.signal > right.signal;
        return QString::localeAwareCompare(left.displayName, right.displayName) < 0;
    });

    m_networks.setNetworks(orderedNetworks);
    if (!triggeredBySignal)
        setScanningState(false);
    updateStatusText();
}

void WifiController::reloadSavedConnections() {
    m_savedConnectionsBySsid.clear();

    const QDBusMessage reply = callMethod(
        kNetworkManagerService,
        kNetworkManagerSettingsPath,
        kNetworkManagerSettingsInterface,
        QStringLiteral("ListConnections")
    );

    if (reply.type() == QDBusMessage::ErrorMessage) {
        m_savedConnectionsDirty = true;
        return;
    }

    const ObjectPathList connectionPaths = objectPathsFromVariant(reply.arguments().value(0));
    for (const QDBusObjectPath &connectionPath : connectionPaths) {
        const QDBusMessage settingsReply = callMethod(
            kNetworkManagerService,
            connectionPath.path(),
            kNetworkManagerSettingsConnectionInterface,
            QStringLiteral("GetSettings")
        );

        if (settingsReply.type() == QDBusMessage::ErrorMessage || settingsReply.arguments().isEmpty())
            continue;

        const ConnectionSettingsMap settings = connectionSettingsFromVariant(settingsReply.arguments().constFirst());
        const QVariantMap connectionSection = settings.value(QStringLiteral("connection"));
        if (connectionSection.value(QStringLiteral("type")).toString() != QLatin1String("802-11-wireless"))
            continue;

        const QVariantMap wirelessSection = settings.value(QStringLiteral("802-11-wireless"));
        QString ssid = decodeSsid(byteArrayFromVariant(wirelessSection.value(QStringLiteral("ssid"))));
        if (ssid.isEmpty())
            ssid = connectionSection.value(QStringLiteral("id")).toString().trimmed();

        if (!ssid.isEmpty())
            m_savedConnectionsBySsid.insert(ssid, connectionPath.path());
    }

    m_savedConnectionsDirty = false;
}

void WifiController::reconnectDeviceSignals(const QString &devicePath) {
    if (m_connectedDeviceSignalPath == devicePath)
        return;

    disconnectDeviceSignals();

    if (!isValidPath(devicePath))
        return;

    QDBusConnection::systemBus().connect(
        kNetworkManagerService,
        devicePath,
        kDbusPropertiesInterface,
        "PropertiesChanged",
        this,
        SLOT(handleDevicePropertiesChanged(QString,QVariantMap,QStringList))
    );
    QDBusConnection::systemBus().connect(
        kNetworkManagerService,
        devicePath,
        kNetworkManagerWirelessInterface,
        "AccessPointAdded",
        this,
        SLOT(handleAccessPointAdded(QDBusObjectPath))
    );
    QDBusConnection::systemBus().connect(
        kNetworkManagerService,
        devicePath,
        kNetworkManagerWirelessInterface,
        "AccessPointRemoved",
        this,
        SLOT(handleAccessPointRemoved(QDBusObjectPath))
    );

    m_connectedDeviceSignalPath = devicePath;
}

void WifiController::disconnectDeviceSignals() {
    if (m_connectedDeviceSignalPath.isEmpty())
        return;

    QDBusConnection::systemBus().disconnect(
        kNetworkManagerService,
        m_connectedDeviceSignalPath,
        kDbusPropertiesInterface,
        "PropertiesChanged",
        this,
        SLOT(handleDevicePropertiesChanged(QString,QVariantMap,QStringList))
    );
    QDBusConnection::systemBus().disconnect(
        kNetworkManagerService,
        m_connectedDeviceSignalPath,
        kNetworkManagerWirelessInterface,
        "AccessPointAdded",
        this,
        SLOT(handleAccessPointAdded(QDBusObjectPath))
    );
    QDBusConnection::systemBus().disconnect(
        kNetworkManagerService,
        m_connectedDeviceSignalPath,
        kNetworkManagerWirelessInterface,
        "AccessPointRemoved",
        this,
        SLOT(handleAccessPointRemoved(QDBusObjectPath))
    );

    m_connectedDeviceSignalPath.clear();
}

QVariant WifiController::getProperty(const QString &service, const QString &path, const QString &interfaceName, const QString &propertyName) const {
    const QDBusMessage reply = callMethod(
        service,
        path,
        kDbusPropertiesInterface,
        QStringLiteral("Get"),
        {interfaceName, propertyName}
    );

    if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().isEmpty())
        return {};

    return unwrapVariant(reply.arguments().constFirst());
}

bool WifiController::setProperty(const QString &service, const QString &path, const QString &interfaceName, const QString &propertyName, const QVariant &value, QString *errorMessage) const {
    const QDBusMessage reply = callMethod(
        service,
        path,
        kDbusPropertiesInterface,
        QStringLiteral("Set"),
        {interfaceName, propertyName, QVariant::fromValue(QDBusVariant(value))}
    );

    if (reply.type() == QDBusMessage::ErrorMessage) {
        if (errorMessage)
            *errorMessage = errorTextForReply(reply, QStringLiteral("Unable to update Wi-Fi state."));
        return false;
    }

    return true;
}

QDBusMessage WifiController::callMethod(const QString &service, const QString &path, const QString &interfaceName, const QString &methodName, const QList<QVariant> &arguments) const {
    QDBusMessage message = QDBusMessage::createMethodCall(service, path, interfaceName, methodName);
    message.setArguments(arguments);
    return QDBusConnection::systemBus().call(message);
}

void WifiController::setBackendName(const QString &backendName) {
    if (m_backendName == backendName)
        return;

    m_backendName = backendName;
    emit backendNameChanged();
    updateStatusText();
}

void WifiController::setSupported(bool supported) {
    if (m_supported == supported)
        return;

    m_supported = supported;
    emit supportedChanged();
    updateStatusText();
}

void WifiController::setReadOnly(bool readOnly) {
    if (m_readOnly == readOnly)
        return;

    m_readOnly = readOnly;
    emit readOnlyChanged();
}

void WifiController::setAvailable(bool available) {
    if (m_available == available)
        return;

    m_available = available;
    emit availableChanged();
    updateStatusText();
}

void WifiController::setEnabledState(bool enabled) {
    if (m_enabled == enabled)
        return;

    m_enabled = enabled;
    emit enabledChanged();
    updateStatusText();
}

void WifiController::setBusyState(bool busy) {
    if (m_busy == busy)
        return;

    m_busy = busy;
    emit busyChanged();
    updateStatusText();
}

void WifiController::setScanningState(bool scanning) {
    if (m_scanning == scanning)
        return;

    m_scanning = scanning;
    emit scanningChanged();
    updateBusyState();
}

void WifiController::setCurrentSsid(const QString &currentSsid) {
    if (m_currentSsid == currentSsid)
        return;

    m_currentSsid = currentSsid;
    emit currentSsidChanged();
    updateStatusText();
}

void WifiController::setStatusText(const QString &statusText) {
    if (m_statusText == statusText)
        return;

    m_statusText = statusText;
    emit statusTextChanged();
}

void WifiController::setInfoMessage(const QString &infoMessage) {
    if (m_infoMessage == infoMessage)
        return;

    m_infoMessage = infoMessage;
    emit infoMessageChanged();
}

void WifiController::setErrorMessage(const QString &errorMessage) {
    if (m_errorMessage == errorMessage)
        return;

    m_errorMessage = errorMessage;
    emit errorMessageChanged();
}

void WifiController::setUnsupportedReason(const QString &unsupportedReason) {
    if (m_unsupportedReason == unsupportedReason)
        return;

    m_unsupportedReason = unsupportedReason;
    emit unsupportedReasonChanged();
}

void WifiController::updateBusyState() {
    setBusyState(m_actionInProgress || m_scanning);
}

void WifiController::updateStatusText() {
    QString nextStatus;

    if (!m_supported) {
        if (m_backendName == QLatin1String("iwd"))
            nextStatus = QStringLiteral("iwd detected");
        else if (m_backendName == QLatin1String("connman"))
            nextStatus = QStringLiteral("ConnMan detected");
        else
            nextStatus = QStringLiteral("Unavailable");
    } else if (!m_available) {
        nextStatus = QStringLiteral("No device");
    } else if (!m_enabled) {
        nextStatus = QStringLiteral("Off");
    } else if (!m_currentSsid.isEmpty()) {
        nextStatus = m_currentSsid;
    } else if (m_scanning) {
        nextStatus = QStringLiteral("Scanning");
    } else if (m_busy) {
        nextStatus = QStringLiteral("Working...");
    } else {
        nextStatus = QStringLiteral("On");
    }

    setStatusText(nextStatus);
}

void WifiController::clearUnsupportedState(const QString &backendName, bool available, const QString &reason) {
    setBackendName(backendName);
    setSupported(false);
    setReadOnly(true);
    setAvailable(available);
    setEnabledState(false);
    setCurrentSsid({});
    setUnsupportedReason(reason);
    updateStatusText();
}

void WifiController::clearSupportedState() {
    setBackendName(QStringLiteral("networkmanager"));
    setSupported(true);
    setReadOnly(false);
    setUnsupportedReason({});
}

QString WifiController::errorTextForReply(const QDBusMessage &reply, const QString &fallback) const {
    if (reply.type() != QDBusMessage::ErrorMessage)
        return fallback;

    const QString message = reply.errorMessage().trimmed();
    if (!message.isEmpty())
        return message;

    const QString errorName = reply.errorName().trimmed();
    if (!errorName.isEmpty())
        return errorName;

    return fallback;
}

bool WifiController::activateSavedConnection(const QString &ssid, const QString &accessPointPath) {
    const QString connectionPath = m_savedConnectionsBySsid.value(ssid);
    if (!isValidPath(connectionPath)) {
        setErrorMessage(QStringLiteral("Saved Wi-Fi connection details are unavailable."));
        return false;
    }

    const QString specificObjectPath = isValidPath(accessPointPath) ? accessPointPath : QString::fromLatin1(kRootPath);
    const QDBusMessage reply = callMethod(
        kNetworkManagerService,
        kNetworkManagerPath,
        kNetworkManagerInterface,
        QStringLiteral("ActivateConnection"),
        {
            QVariant::fromValue(QDBusObjectPath(connectionPath)),
            QVariant::fromValue(QDBusObjectPath(m_wifiDevicePath)),
            QVariant::fromValue(QDBusObjectPath(specificObjectPath))
        }
    );

    if (reply.type() == QDBusMessage::ErrorMessage) {
        setErrorMessage(errorTextForReply(reply, QStringLiteral("Unable to activate the saved Wi-Fi connection.")));
        return false;
    }

    return true;
}

bool WifiController::addAndActivateConnection(const QString &ssid, const QString &accessPointPath, const QString &password, bool secure) {
    if (!isValidPath(accessPointPath)) {
        setErrorMessage(QStringLiteral("Selected network is no longer available."));
        return false;
    }

    if (secure && password.trimmed().isEmpty()) {
        setErrorMessage(QStringLiteral("Enter a password first."));
        return false;
    }

    ConnectionSettingsMap settings;

    QVariantMap connectionSection;
    connectionSection.insert(QStringLiteral("id"), ssid);
    connectionSection.insert(QStringLiteral("type"), QStringLiteral("802-11-wireless"));
    connectionSection.insert(QStringLiteral("uuid"), QUuid::createUuid().toString(QUuid::WithoutBraces));
    connectionSection.insert(QStringLiteral("autoconnect"), false);
    settings.insert(QStringLiteral("connection"), connectionSection);

    QVariantMap wirelessSection;
    wirelessSection.insert(QStringLiteral("ssid"), QByteArray(ssid.toUtf8()));
    wirelessSection.insert(QStringLiteral("mode"), QStringLiteral("infrastructure"));
    settings.insert(QStringLiteral("802-11-wireless"), wirelessSection);

    QVariantMap ipv4Section;
    ipv4Section.insert(QStringLiteral("method"), QStringLiteral("auto"));
    settings.insert(QStringLiteral("ipv4"), ipv4Section);

    QVariantMap ipv6Section;
    ipv6Section.insert(QStringLiteral("method"), QStringLiteral("auto"));
    settings.insert(QStringLiteral("ipv6"), ipv6Section);

    if (secure) {
        QVariantMap securitySection;
        securitySection.insert(QStringLiteral("key-mgmt"), QStringLiteral("wpa-psk"));
        securitySection.insert(QStringLiteral("psk"), password);
        settings.insert(QStringLiteral("802-11-wireless-security"), securitySection);
    }

    const QDBusMessage reply = callMethod(
        kNetworkManagerService,
        kNetworkManagerPath,
        kNetworkManagerInterface,
        QStringLiteral("AddAndActivateConnection"),
        {
            QVariant::fromValue(settings),
            QVariant::fromValue(QDBusObjectPath(m_wifiDevicePath)),
            QVariant::fromValue(QDBusObjectPath(accessPointPath))
        }
    );

    if (reply.type() == QDBusMessage::ErrorMessage) {
        setErrorMessage(errorTextForReply(reply, QStringLiteral("Unable to connect to the selected Wi-Fi network.")));
        return false;
    }

    return true;
}
