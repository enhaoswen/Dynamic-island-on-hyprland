#pragma once

#include <QObject>
#include <QtQml/qqml.h>
#include <QLocalSocket>
#include <QProcess>
#include <QFileSystemWatcher>
#include <QSocketNotifier>
#include <QString>
#include <QByteArray>
#include <QTimer>
#include <QVariantMap>

struct udev;
struct udev_monitor;

class SysBackend : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int batteryCapacity READ batteryCapacity NOTIFY batteryCapacityChanged FINAL)
    Q_PROPERTY(QString batteryStatus READ batteryStatus NOTIFY batteryStatusChanged FINAL)

public:
    explicit SysBackend(QObject *parent = nullptr);
    ~SysBackend() override;

    int batteryCapacity() const;
    QString batteryStatus() const;

signals:
    void workspaceChanged(int wsId);
    void capsLockChanged(bool isOn);
    void brightnessChanged(double val);
    void volumeChanged(int volPercentage, bool isMuted);
    void batteryCapacityChanged(int capacity);
    void batteryStatusChanged(const QString &statusString);
    void batteryChanged(int capacity, const QString &statusString);
    void bluetoothChanged(bool isConnected);

private slots:
    void handleHyprlandData();
    void handleVolumeEvent();
    void fetchCurrentVolume();
    void handleBatteryMonitorEvent();
    void handleBatteryPropertiesChanged(const QString &interfaceName, const QVariantMap &changedProperties, const QStringList &invalidatedProperties);
    void handleUpowerBatteryChanged();
    void updateBrightness();
    void updateCapsLock();
    void updateBatterySysfs();
    void updateBatteryUpower();
    void handleAudioRefresh();

private:
    void setupHyprland();
    void setupBattery();
    void setupBatteryUpower();
    void setupAudio();
    void setupBrightness();
    void setupKeyboard();
    bool queryBluetoothAudioConnected();
    void checkDefaultAudioDevice();
    void updateBatteryState(int capacity, const QString &statusString);
    QString upowerStateToBatteryStatus(uint state) const;

    bool m_isBluetoothAudio = false;
    QLocalSocket *m_hyprSocket;
    QByteArray m_hyprBuffer;
    QProcess *m_paSubscriber;
    QFileSystemWatcher *m_brightnessWatcher;
    QSocketNotifier *m_batteryNotifier;
    QTimer *m_audioDebounceTimer;
    QTimer *m_capsPollTimer;
    double m_maxBrightness;

    QString m_batteryPath;
    QString m_acPath;
    int m_batteryCap;
    QString m_batteryStatus;
    QString m_upowerBatteryPath;
    bool m_hasBatteryState;

    bool m_isBluetoothAudioConnected;
    bool m_capsLockInitialized;
    bool m_capsLockOn;
    struct udev *m_udev;
    struct udev_monitor *m_batteryMonitor;
};
