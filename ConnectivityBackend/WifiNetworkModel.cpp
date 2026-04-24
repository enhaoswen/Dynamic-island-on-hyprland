#include "WifiNetworkModel.h"

#include <optional>

WifiNetworkModel::WifiNetworkModel(QObject *parent)
    : QAbstractListModel(parent) {
}

int WifiNetworkModel::rowCount(const QModelIndex &parent) const {
    return parent.isValid() ? 0 : m_networks.size();
}

QVariant WifiNetworkModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_networks.size())
        return {};

    const NetworkEntry &entry = m_networks.at(index.row());

    switch (role) {
    case SsidRole:
        return entry.ssid;
    case DisplayNameRole:
        return entry.displayName;
    case TypeRole:
        return entry.type;
    case SignalRole:
        return entry.signal;
    case SecureRole:
        return entry.secure;
    case SavedConnectionRole:
        return entry.savedConnection;
    case ConnectedRole:
        return entry.connected;
    default:
        return {};
    }
}

QHash<int, QByteArray> WifiNetworkModel::roleNames() const {
    return {
        {SsidRole, "ssid"},
        {DisplayNameRole, "displayName"},
        {TypeRole, "type"},
        {SignalRole, "signal"},
        {SecureRole, "secure"},
        {SavedConnectionRole, "savedConnection"},
        {ConnectedRole, "connected"},
    };
}

void WifiNetworkModel::setNetworks(const QVector<NetworkEntry> &networks) {
    beginResetModel();
    m_networks = networks;
    endResetModel();
}

void WifiNetworkModel::clear() {
    if (m_networks.isEmpty())
        return;

    beginResetModel();
    m_networks.clear();
    endResetModel();
}

QString WifiNetworkModel::objectPathForSsid(const QString &ssid) const {
    const QString trimmed = ssid.trimmed();
    for (const NetworkEntry &entry : m_networks) {
        if (entry.ssid == trimmed)
            return entry.objectPath;
    }

    return {};
}

std::optional<WifiNetworkModel::NetworkEntry> WifiNetworkModel::networkForSsid(const QString &ssid) const {
    const QString trimmed = ssid.trimmed();
    for (const NetworkEntry &entry : m_networks) {
        if (entry.ssid == trimmed)
            return entry;
    }

    return std::nullopt;
}
