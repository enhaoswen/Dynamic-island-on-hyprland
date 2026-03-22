#include "SysBackend.h"
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <libudev.h>

SysBackend::SysBackend(QObject *parent)
    : QObject(parent),
      m_hyprSocket(nullptr),
      m_paSubscriber(nullptr),
      m_brightnessWatcher(nullptr),
      m_batteryNotifier(nullptr),
      m_audioDebounceTimer(nullptr),
      m_capsPollTimer(nullptr),
      m_maxBrightness(1.0),
      m_batteryCap(0),
      m_batteryStatus("Unknown"),
      m_upowerBatteryPath(),
      m_hasBatteryState(false),
      m_isBluetoothAudioConnected(false),
      m_capsLockInitialized(false),
      m_capsLockOn(false),
      m_udev(nullptr),
      m_batteryMonitor(nullptr) {
    setupHyprland();
    setupBattery();
    setupAudio();
    setupBrightness();
    setupKeyboard();
}

SysBackend::~SysBackend() {
    if (m_batteryMonitor) udev_monitor_unref(m_batteryMonitor);
    if (m_udev) udev_unref(m_udev);
}

int SysBackend::batteryCapacity() const {
    return m_batteryCap;
}

QString SysBackend::batteryStatus() const {
    return m_batteryStatus;
}

// 1. Hyprland IPC
void SysBackend::setupHyprland() {
    QString signature = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    if (signature.isEmpty()) return;

    QString xdgRuntime = qEnvironmentVariable("XDG_RUNTIME_DIR");
    QString path1 = QString("%1/hypr/%2/.socket2.sock").arg(xdgRuntime, signature);
    QString path2 = QString("/tmp/hypr/%1/.socket2.sock").arg(signature);

    QString targetPath = "";
    if (QFile::exists(path1)) targetPath = path1;
    else if (QFile::exists(path2)) targetPath = path2;
    else return;

    m_hyprSocket = new QLocalSocket(this);
    connect(m_hyprSocket, &QLocalSocket::readyRead, this, &SysBackend::handleHyprlandData);
    
    connect(m_hyprSocket, &QLocalSocket::disconnected, this, [this, targetPath]() { QTimer::singleShot(2000, m_hyprSocket, [this, targetPath](){ m_hyprSocket->connectToServer(targetPath); }); });

    m_hyprSocket->connectToServer(targetPath);
}

void SysBackend::handleHyprlandData() {
    m_hyprBuffer.append(m_hyprSocket->readAll());
    while (m_hyprBuffer.contains('\n')) {
        int idx = m_hyprBuffer.indexOf('\n');
        QString line = QString::fromUtf8(m_hyprBuffer.left(idx)).trimmed();
        m_hyprBuffer.remove(0, idx + 1);

        if (line.startsWith("workspace>>") || line.startsWith("workspacev2>>")) {
            QString data = line.split(">>").last();
            int wsId = data.split(',').first().toInt(); 
            if (wsId > 0) emit workspaceChanged(wsId);
        }
    }
}

// 2. Battery
void SysBackend::setupBattery() {
    QDir dir("/sys/class/power_supply/");
    QStringList supplies = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    
    for (const QString &supply : supplies) {
        if (supply.startsWith("BAT")) {
            m_batteryPath = "/sys/class/power_supply/" + supply;
        } else if (supply.startsWith("AC") || supply.startsWith("ADP")) {
            m_acPath = "/sys/class/power_supply/" + supply; 
        }
    }

    updateBatterySysfs();
    setupBatteryUpower();

    if (!m_udev) {
        m_udev = udev_new();
        if (!m_udev) {
            qWarning() << "[Battery] Failed to create udev context for power_supply monitoring";
            return;
        }
    }

    m_batteryMonitor = udev_monitor_new_from_netlink(m_udev, "udev");
    if (!m_batteryMonitor) {
        qWarning() << "[Battery] Failed to create udev monitor for power_supply monitoring";
        return;
    }

    if (udev_monitor_filter_add_match_subsystem_devtype(m_batteryMonitor, "power_supply", nullptr) < 0 ||
        udev_monitor_enable_receiving(m_batteryMonitor) < 0) {
        qWarning() << "[Battery] Failed to enable udev monitor for power_supply monitoring";
        udev_monitor_unref(m_batteryMonitor);
        m_batteryMonitor = nullptr;
        return;
    }

    const int monitorFd = udev_monitor_get_fd(m_batteryMonitor);
    if (monitorFd < 0) {
        qWarning() << "[Battery] Failed to get udev monitor fd for power_supply monitoring";
        udev_monitor_unref(m_batteryMonitor);
        m_batteryMonitor = nullptr;
        return;
    }

    m_batteryNotifier = new QSocketNotifier(monitorFd, QSocketNotifier::Read, this);
    connect(m_batteryNotifier, &QSocketNotifier::activated, this, &SysBackend::handleBatteryMonitorEvent);
}

void SysBackend::setupBatteryUpower() {
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        qWarning() << "[Battery] System DBus is not available for UPower monitoring";
        return;
    }

    QDBusInterface upower(
        "org.freedesktop.UPower",
        "/org/freedesktop/UPower",
        "org.freedesktop.UPower",
        bus,
        this
    );

    if (!upower.isValid()) {
        qWarning() << "[Battery] UPower service is not available";
        return;
    }

    QDBusReply<QDBusObjectPath> displayDeviceReply = upower.call("GetDisplayDevice");
    if (!displayDeviceReply.isValid()) {
        qWarning() << "[Battery] Failed to get UPower display device:" << displayDeviceReply.error().message();
        return;
    }

    m_upowerBatteryPath = displayDeviceReply.value().path();
    if (m_upowerBatteryPath.isEmpty() || m_upowerBatteryPath == "/") {
        qWarning() << "[Battery] Invalid UPower display device path";
        return;
    }

    const bool changedConnected = bus.connect(
        "org.freedesktop.UPower",
        m_upowerBatteryPath,
        "org.freedesktop.UPower.Device",
        "Changed",
        this,
        SLOT(handleUpowerBatteryChanged())
    );

    const bool propertiesConnected = bus.connect(
        "org.freedesktop.UPower",
        m_upowerBatteryPath,
        "org.freedesktop.DBus.Properties",
        "PropertiesChanged",
        this,
        SLOT(handleBatteryPropertiesChanged(QString,QVariantMap,QStringList))
    );

    if (!changedConnected && !propertiesConnected) {
        qWarning() << "[Battery] Failed to connect to UPower battery change signals";
        m_upowerBatteryPath.clear();
        return;
    }

    updateBatteryUpower();
}

void SysBackend::updateBatteryState(int capacity, const QString &statusString) {
    const bool capacityChanged = !m_hasBatteryState || capacity != m_batteryCap;
    const bool statusChanged = !m_hasBatteryState || statusString != m_batteryStatus;

    if (!capacityChanged && !statusChanged) return;

    m_batteryCap = capacity;
    m_batteryStatus = statusString;
    m_hasBatteryState = true;

    qDebug() << "[Battery] State:" << m_batteryCap << "% -" << m_batteryStatus;

    if (capacityChanged) emit batteryCapacityChanged(m_batteryCap);
    if (statusChanged) emit batteryStatusChanged(m_batteryStatus);
    emit batteryChanged(m_batteryCap, m_batteryStatus);
}

QString SysBackend::upowerStateToBatteryStatus(uint state) const {
    switch (state) {
        case 1:
        case 5:
            return "Charging";
        case 2:
        case 6:
            return "Discharging";
        case 3:
            return "Empty";
        case 4:
            return "Full";
        default:
            return "Unknown";
    }
}

void SysBackend::updateBatterySysfs() {
    int currentCap = m_batteryCap;
    QString currentStatus = m_batteryStatus;

    if (!m_batteryPath.isEmpty()) {
        QFile capFile(m_batteryPath + "/capacity");
        if (capFile.open(QIODevice::ReadOnly)) {
            currentCap = capFile.readAll().trimmed().toInt();
            capFile.close();
        }

        QFile statusFile(m_batteryPath + "/status");
        if (statusFile.open(QIODevice::ReadOnly)) {
            currentStatus = QString::fromUtf8(statusFile.readAll()).trimmed();
            statusFile.close();
        }
    }

    if ((currentStatus.isEmpty() || currentStatus == "Unknown") && !m_acPath.isEmpty()) {
        QFile acFile(m_acPath + "/online");
        if (acFile.open(QIODevice::ReadOnly)) {
            int isPlugged = acFile.readAll().trimmed().toInt();
            currentStatus = (isPlugged > 0) ? "Charging" : "Discharging";
            acFile.close();
        }
    }

    updateBatteryState(currentCap, currentStatus);
}

void SysBackend::updateBatteryUpower() {
    if (m_upowerBatteryPath.isEmpty()) return;

    QDBusInterface batteryProps(
        "org.freedesktop.UPower",
        m_upowerBatteryPath,
        "org.freedesktop.DBus.Properties",
        QDBusConnection::systemBus(),
        this
    );

    if (!batteryProps.isValid()) {
        qWarning() << "[Battery] Failed to create UPower battery properties interface";
        return;
    }

    QDBusReply<QVariant> percentageReply = batteryProps.call("Get", "org.freedesktop.UPower.Device", "Percentage");
    QDBusReply<QVariant> stateReply = batteryProps.call("Get", "org.freedesktop.UPower.Device", "State");

    if (!percentageReply.isValid() || !stateReply.isValid()) {
        qWarning() << "[Battery] Failed to read UPower battery properties";
        return;
    }

    const int currentCap = qRound(percentageReply.value().toDouble());
    const QString currentStatus = upowerStateToBatteryStatus(stateReply.value().toUInt());
    updateBatteryState(currentCap, currentStatus);
}

void SysBackend::handleBatteryMonitorEvent() {
    if (!m_batteryMonitor) return;

    bool shouldRefresh = false;
    udev_device *device = nullptr;
    while ((device = udev_monitor_receive_device(m_batteryMonitor)) != nullptr) {
        shouldRefresh = true;
        udev_device_unref(device);
    }

    if (shouldRefresh) updateBatterySysfs();
}

void SysBackend::handleBatteryPropertiesChanged(const QString &interfaceName, const QVariantMap &changedProperties, const QStringList &invalidatedProperties) {
    Q_UNUSED(invalidatedProperties)

    if (interfaceName != "org.freedesktop.UPower.Device") return;
    if (!changedProperties.contains("Percentage") && !changedProperties.contains("State")) return;

    updateBatteryUpower();
}

void SysBackend::handleUpowerBatteryChanged() {
    updateBatteryUpower();
}

// 3. volume
void SysBackend::setupAudio() {
    m_paSubscriber = new QProcess(this);
    connect(m_paSubscriber, &QProcess::readyReadStandardOutput, this, &SysBackend::handleVolumeEvent);
    m_paSubscriber->start("pactl", QStringList() << "subscribe");
    fetchCurrentVolume();
}

void SysBackend::handleVolumeEvent() {
    QByteArray output = m_paSubscriber->readAllStandardOutput();
    qDebug().noquote() << "[Audio Debug] pactl event:" << output.trimmed();//debug

    if (output.contains("sink") || output.contains("card") || output.contains("server")) {
        fetchCurrentVolume();
        checkDefaultAudioDevice();
    }
}

void SysBackend::fetchCurrentVolume() {
    QProcess wpctl;
    wpctl.start("wpctl", QStringList() << "get-volume" << "@DEFAULT_AUDIO_SINK@");
    wpctl.waitForFinished(500);
    
    QString output = QString::fromUtf8(wpctl.readAllStandardOutput()).trimmed();
    qDebug().noquote() << "[Audio Debug] wpctl output:" << output; 

    if (output.startsWith("Volume:")) {
        bool isMuted = output.contains("[MUTED]");
        QString valStr = output.section(' ', 1, 1);
        int volPercentage = static_cast<int>(valStr.toDouble() * 100);
        
        qDebug() << "[Audio Debug] Emitting volumeChanged:" << volPercentage << "Muted:" << isMuted;
        emit volumeChanged(volPercentage, isMuted);
    }
}

// 4. brightness
void SysBackend::setupBrightness() {
    QString basePath = "/sys/class/backlight/intel_backlight";
    QFile maxFile(basePath + "/max_brightness");
    if (maxFile.open(QIODevice::ReadOnly)) {
        m_maxBrightness = QString::fromUtf8(maxFile.readAll()).trimmed().toDouble();
        maxFile.close();
    }

    QFile bFile(basePath + "/brightness");
    if (bFile.exists()) {
        m_brightnessWatcher = new QFileSystemWatcher(this);
        m_brightnessWatcher->addPath(basePath + "/brightness");
        connect(m_brightnessWatcher, &QFileSystemWatcher::fileChanged, this, &SysBackend::updateBrightness);
        updateBrightness();
    }
}

void SysBackend::updateBrightness() {
    QFile bFile("/sys/class/backlight/intel_backlight/brightness");
    if (bFile.open(QIODevice::ReadOnly)) {
        double current = QString::fromUtf8(bFile.readAll()).trimmed().toDouble();
        bFile.close();
        if (m_maxBrightness > 0) emit brightnessChanged(current / m_maxBrightness);
        
    }
}

// 5. caps lock
void SysBackend::setupKeyboard() {
    updateCapsLock();
    if (!m_capsPollTimer) {
        m_capsPollTimer = new QTimer(this);
        m_capsPollTimer->setInterval(200);
        connect(m_capsPollTimer, &QTimer::timeout, this, &SysBackend::updateCapsLock);
        m_capsPollTimer->start();
    }
}

void SysBackend::updateCapsLock() {
    QProcess hyprctl;
    hyprctl.start("hyprctl", QStringList() << "devices" << "-j");
    if (!hyprctl.waitForFinished(500)) {
        hyprctl.kill();
        hyprctl.waitForFinished(100);
        return;
    }

    const QByteArray output = hyprctl.readAllStandardOutput();
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(output, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) return;

    const QJsonArray keyboards = doc.object().value("keyboards").toArray();
    bool currentState = false;
    for (const QJsonValue &keyboardVal : keyboards) {
        if (keyboardVal.toObject().value("capsLock").toBool()) {
            currentState = true;
            break;
        }
    }

    if (!m_capsLockInitialized) {
        m_capsLockOn = currentState;
        m_capsLockInitialized = true;
        return;
    }

    if (currentState != m_capsLockOn) {
        m_capsLockOn = currentState;
        emit capsLockChanged(m_capsLockOn);
    }
}

void SysBackend::checkDefaultAudioDevice() {
    QProcess pactl;
    pactl.start("pactl", QStringList() << "get-default-sink");
    pactl.waitForFinished(500);
    
    QString sinkName = QString::fromUtf8(pactl.readAllStandardOutput()).trimmed();
    
    bool isBtNow = sinkName.contains("bluez");

    if (isBtNow != m_isBluetoothAudio) {
        m_isBluetoothAudio = isBtNow;
        qDebug() << "[Bluetooth Debug] Default sink:" << sinkName << "-> Is BT:" << m_isBluetoothAudio;
        emit bluetoothChanged(m_isBluetoothAudio);
    }
}
