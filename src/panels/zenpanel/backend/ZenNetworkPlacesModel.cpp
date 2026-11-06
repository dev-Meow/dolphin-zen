#include "ZenNetworkPlacesModel.h"
#include "ZenPlacesMasterModel.h"

#include <KConfigGroup>
#include <KCoreDirLister>
#include <KFilePlacesModel>
#include <KSharedConfig>
#include <QIcon>
#include <QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(zenLog)

ZenNetworkPlacesModel::ZenNetworkPlacesModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_dirLister(new KCoreDirLister(this))
{
    connect(m_dirLister, &KCoreDirLister::itemsAdded, this, &ZenNetworkPlacesModel::onItemsAdded);
    connect(m_dirLister, &KCoreDirLister::itemsDeleted, this, &ZenNetworkPlacesModel::onItemsDeleted);
    connect(m_dirLister, &KCoreDirLister::clear, this, &ZenNetworkPlacesModel::onListerCleared);
}

ZenNetworkPlacesModel::~ZenNetworkPlacesModel() = default;

bool ZenNetworkPlacesModel::isEnabled() const
{
    return m_enabled;
}

void ZenNetworkPlacesModel::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }

    m_enabled = enabled;
    if (m_enabled) {
        m_dirLister->openUrl(QUrl(QStringLiteral("remote:/")), KCoreDirLister::NoFlags);
    } else {
        m_dirLister->stop();
        if (!m_items.isEmpty()) {
            beginResetModel();
            m_items.clear();
            endResetModel();
        }
    }

    Q_EMIT enabledChanged();
}

int ZenNetworkPlacesModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid() || !m_enabled) {
        return 0;
    }
    return m_items.size();
}

QUrl ZenNetworkPlacesModel::effectiveUrl(const KFileItem &item)
{
    const QUrl target = item.targetUrl();
    return target.isValid() ? target : item.url();
}

QString ZenNetworkPlacesModel::itemKey(const KFileItem &item)
{
    return effectiveUrl(item).toString();
}

QHash<int, QByteArray> ZenNetworkPlacesModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[Qt::DisplayRole] = "display";
    roles[Qt::DecorationRole] = "decoration";
    roles[KFilePlacesModel::UrlRole] = "url";
    roles[KFilePlacesModel::HiddenRole] = "isHidden";
    roles[ZenPlacesMasterModel::FormattedPathRole] = "formattedPath";
    roles[ZenPlacesMasterModel::IsEssentialRole] = "isEssential";
    roles[ZenPlacesMasterModel::IsWorkspacePlaceRole] = "isWorkspacePlace";
    roles[ZenPlacesMasterModel::IsPinnedDeviceRole] = "isPinnedDevice";
    roles[ZenPlacesMasterModel::CapacityPercentageRole] = "capacityPercentage";
    roles[ZenPlacesMasterModel::FreeSpaceTextRole] = "freeSpaceText";
    roles[ZenPlacesMasterModel::CanTeardownRole] = "canTeardown";
    return roles;
}

QVariant ZenNetworkPlacesModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return {};
    }

    const KFileItem &item = m_items.at(index.row());

    switch (role) {
    case Qt::DisplayRole:
        return item.text();

    case Qt::DecorationRole:
    case KFilePlacesModel::IconNameRole:
        return item.iconName().isEmpty() ? QStringLiteral("folder-network") : item.iconName();

    case KFilePlacesModel::UrlRole:
        return effectiveUrl(item);

    case KFilePlacesModel::HiddenRole:
    case KFilePlacesModel::GroupHiddenRole:
        return false;

    case ZenPlacesMasterModel::FormattedPathRole:
        return effectiveUrl(item).toDisplayString(QUrl::PreferLocalFile);

    case ZenPlacesMasterModel::IsEssentialRole:
    case ZenPlacesMasterModel::IsWorkspacePlaceRole:
        return false;

    case ZenPlacesMasterModel::IsPinnedDeviceRole: {
        const KConfigGroup group = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelPinnedDevices"));
        return group.readEntry(itemKey(item), false);
    }

    case ZenPlacesMasterModel::CapacityPercentageRole:
        return -1;

    case ZenPlacesMasterModel::FreeSpaceTextRole:
        return QString();

    case ZenPlacesMasterModel::CanTeardownRole:
        return false;

    default:
        return {};
    }
}

bool ZenNetworkPlacesModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return false;
    }

    if (role == ZenPlacesMasterModel::IsPinnedDeviceRole) {
        const KFileItem &item = m_items.at(index.row());
        KConfigGroup group = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelPinnedDevices"));
        group.writeEntry(itemKey(item), value.toBool());
        group.sync();
        Q_EMIT dataChanged(index, index, {ZenPlacesMasterModel::IsPinnedDeviceRole});
        return true;
    }

    return false;
}

void ZenNetworkPlacesModel::onItemsAdded(const QUrl &/*directoryUrl*/, const KFileItemList &items)
{
    if (!m_enabled || items.isEmpty()) {
        return;
    }

    QList<KFileItem> newItems;
    for (const KFileItem &item : items) {
        bool exists = false;
        for (const KFileItem &existing : std::as_const(m_items)) {
            if (existing.url() == item.url()) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            newItems.append(item);
        }
    }

    if (newItems.isEmpty()) {
        return;
    }

    const int first = m_items.size();
    const int last = first + newItems.size() - 1;
    beginInsertRows(QModelIndex(), first, last);
    m_items.append(newItems);
    endInsertRows();

    qCDebug(zenLog) << "[ZenNetworkPlacesModel] Added" << newItems.size() << "entries from remote:/";
}

void ZenNetworkPlacesModel::onItemsDeleted(const KFileItemList &items)
{
    for (const KFileItem &deleted : items) {
        for (int i = 0; i < m_items.size(); ++i) {
            if (m_items.at(i).url() == deleted.url()) {
                beginRemoveRows(QModelIndex(), i, i);
                m_items.removeAt(i);
                endRemoveRows();
                break;
            }
        }
    }
}

void ZenNetworkPlacesModel::onListerCleared()
{
    if (!m_items.isEmpty()) {
        beginResetModel();
        m_items.clear();
        endResetModel();
    }
}

