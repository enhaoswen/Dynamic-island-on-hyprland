#include "SysBackend.h"
#include <QFile>
#include <QDir>
#include <QDebug>

SysBackend::SysBackend(QObject *parent) : QObject(parent), m_hyprSocket(nullptr), m_paSubscriber(nullptr), m_brightnessWatcher(nullptr), m_capsTimer(nullptr), m_sysfsTimer(nullptr), m_maxBrightness(1.0), m_batteryCap(100), m_batteryStatus("Unknown") {
    setupHyprland();
    setupBattery();
    setupAudio();
    setupBrightness();
    setupKeyboard();
}

SysBackend::~SysBackend() {}

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

    m_sysfsTimer = new QTimer(this);
    connect(m_sysfsTimer, &QTimer::timeout, this, &SysBackend::updateBatterySysfs);
    m_sysfsTimer->start(500);

    updateBatterySysfs();
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
    }

    if (!m_acPath.isEmpty()) {
        QFile acFile(m_acPath + "/online");
        if (acFile.open(QIODevice::ReadOnly)) {
            int isPlugged = acFile.readAll().trimmed().toInt();
            currentStatus = (isPlugged > 0) ? "Charging" : "Discharging";
            acFile.close();
        }
    }

    if (currentCap != m_batteryCap || currentStatus != m_batteryStatus || m_batteryStatus == "Unknown") {
        m_batteryCap = currentCap;
        m_batteryStatus = currentStatus;
        qDebug() << "[Battery] Sysfs:" << m_batteryCap << "% -" << m_batteryStatus;
        emit batteryChanged(m_batteryCap, m_batteryStatus);
    }
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
    m_capsTimer = new QTimer(this);
    connect(m_capsTimer, &QTimer::timeout, this, &SysBackend::updateCapsLock);
    m_capsTimer->start(100); 
}

void SysBackend::updateCapsLock() {
    static int lastState = -1; 
    int currentState = 0;
    
    QDir dir("/sys/class/leds/");
    QStringList capsLeds = dir.entryList(QStringList() << "*capslock*", QDir::Dirs);
    
    for (const QString &led : capsLeds) {
        QFile file("/sys/class/leds/" + led + "/brightness");
        if (file.open(QIODevice::ReadOnly)) {
            if (file.readAll().trimmed().toInt() > 0) {
                currentState = 1; 
                file.close();
                break; 
            }
            file.close();
        }
    }

    if (currentState != lastState) {
        if (lastState != -1) emit capsLockChanged(currentState > 0);
        lastState = currentState;
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