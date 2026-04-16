#pragma once

#include <QAbstractListModel>
#include <QVector>
#include <optional>

class WifiNetworkModel final : public QAbstractListModel {
    Q_OBJECT

public:
    struct NetworkEntry {
        QString objectPath;
        QString ssid;
        QString displayName;
        int signal = 0;
        bool secure = false;
        bool savedConnection = false;
        bool connected = false;
    };

    enum Roles {
        SsidRole = Qt::UserRole + 1,
        DisplayNameRole,
        SignalRole,
        SecureRole,
        SavedConnectionRole,
        ConnectedRole
    };

    explicit WifiNetworkModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setNetworks(const QVector<NetworkEntry> &networks);
    void clear();

    QString objectPathForSsid(const QString &ssid) const;
    std::optional<NetworkEntry> networkForSsid(const QString &ssid) const;

private:
    QVector<NetworkEntry> m_networks;
};
