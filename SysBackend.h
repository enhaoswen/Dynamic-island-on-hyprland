#pragma once

#include <QObject>
#include <QtQml/qqml.h>
#include <QLocalSocket>
#include <QProcess>
#include <QFileSystemWatcher>
#include <QString>
#include <QByteArray>
#include <QTimer>

class SysBackend : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit SysBackend(QObject *parent = nullptr);
    ~SysBackend() override;

signals:
    void workspaceChanged(int wsId);
    void capsLockChanged(bool isOn);
    void brightnessChanged(double val);
    void volumeChanged(int volPercentage, bool isMuted);
    void batteryChanged(int capacity, const QString &statusString);
    void bluetoothChanged(bool isConnected);

private slots:
    void handleHyprlandData();
    void handleVolumeEvent();
    void fetchCurrentVolume();
    void updateBrightness();
    void updateCapsLock();
    void updateBatterySysfs();
    void handleAudioRefresh();

private:
    void setupHyprland();
    void setupBattery();
    void setupAudio();
    void setupBrightness();
    void setupKeyboard();
    bool queryBluetoothAudioConnected();
    void checkDefaultAudioDevice();

    bool m_isBluetoothAudio = false;
    QLocalSocket *m_hyprSocket;
    QByteArray m_hyprBuffer;
    QProcess *m_paSubscriber;
    QFileSystemWatcher *m_brightnessWatcher;
    QTimer *m_capsTimer;
    QTimer *m_sysfsTimer;
    QTimer *m_audioDebounceTimer;
    double m_maxBrightness;

    QString m_batteryPath;
    QString m_acPath;
    int m_batteryCap;
    QString m_batteryStatus;

    bool m_isBluetoothAudioConnected;
};