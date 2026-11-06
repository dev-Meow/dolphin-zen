#include "ZenSectionFilterProxy.h"
#include "ZenNetworkPlacesModel.h"
#include "ZenPlacesMasterModel.h"

#include <KConfigGroup>
#include <KFilePlacesModel>
#include <KSharedConfig>
#include <QConcatenateTablesProxyModel>
#include <QUrl>

ZenSectionFilterProxy::ZenSectionFilterProxy(QObject *parent)
: QSortFilterProxyModel(parent)
{
    setDynamicSortFilter(true);
}

ZenSectionFilterProxy::SectionType ZenSectionFilterProxy::sectionType() const
{
    return m_sectionType;
}

QHash<int, QByteArray> ZenSectionFilterProxy::roleNames() const
{
    QHash<int, QByteArray> roles = sourceModel() ? sourceModel()->roleNames() : QSortFilterProxyModel::roleNames();
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

void ZenSectionFilterProxy::setSectionType(SectionType type)
{
    if (m_sectionType != type) {
        beginFilterChange();
        m_sectionType = type;
        endFilterChange();
        if (m_sectionType == Essentials || m_sectionType == Devices) {
            sort(0, Qt::AscendingOrder);
        } else {
            sort(-1);
        }
        Q_EMIT sectionTypeChanged();
    }
}

bool ZenSectionFilterProxy::onlyPinned() const
{
    return m_onlyPinned;
}

void ZenSectionFilterProxy::setOnlyPinned(bool pinned)
{
    if (m_onlyPinned != pinned) {
        beginFilterChange();
        m_onlyPinned = pinned;
        endFilterChange();
        Q_EMIT onlyPinnedChanged();
    }
}

bool ZenSectionFilterProxy::expandNetworkFolder() const
{
    return m_expandNetworkFolder;
}

void ZenSectionFilterProxy::setExpandNetworkFolder(bool expand)
{
    if (m_expandNetworkFolder != expand) {
        beginFilterChange();
        m_expandNetworkFolder = expand;
        endFilterChange();
        Q_EMIT expandNetworkFolderChanged();
    }
}

bool ZenSectionFilterProxy::showHiddenPlaces() const
{
    return m_showHiddenPlaces;
}

void ZenSectionFilterProxy::setShowHiddenPlaces(bool show)
{
    if (m_showHiddenPlaces != show) {
        beginFilterChange();
        m_showHiddenPlaces = show;
        endFilterChange();
        Q_EMIT showHiddenPlacesChanged();
    }
}

int ZenSectionFilterProxy::maxItems() const
{
    return m_maxItems;
}

void ZenSectionFilterProxy::setMaxItems(int max)
{
    if (m_maxItems != max) {
        beginFilterChange();
        m_maxItems = max;
        endFilterChange();
        Q_EMIT maxItemsChanged();
    }
}

bool ZenSectionFilterProxy::isNetworkUrl(const QUrl &url) const
{
    const QString scheme = url.scheme();
    return scheme == QLatin1String("remote")
    || scheme == QLatin1String("smb")
    || scheme == QLatin1String("sftp")
    || scheme == QLatin1String("fish")
    || scheme == QLatin1String("nfs");
}

bool ZenSectionFilterProxy::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    QAbstractItemModel *srcModel = sourceModel();
    if (!srcModel) {
        return false;
    }

    const QModelIndex idx = srcModel->index(sourceRow, 0, sourceParent);
    if (!idx.isValid()) {
        return false;
    }

    // Unwrap QConcatenateTablesProxyModel if present so we can inspect the underlying source model directly
    QModelIndex leafIdx = idx;
    if (const auto *concatProxy = qobject_cast<const QConcatenateTablesProxyModel *>(srcModel)) {
        leafIdx = concatProxy->mapToSource(idx);
    }

    const auto *placesModel = qobject_cast<const KFilePlacesModel *>(leafIdx.model());
    const bool isExpandedNetworkEntry = qobject_cast<const ZenNetworkPlacesModel *>(leafIdx.model()) != nullptr;

    // 1. Check hidden status via native KFilePlacesModel API
    const bool isHidden = placesModel
        ? placesModel->isHidden(leafIdx)
        : srcModel->data(idx, KFilePlacesModel::HiddenRole).toBool();

    const QUrl url = placesModel
        ? placesModel->url(leafIdx)
        : srcModel->data(idx, KFilePlacesModel::UrlRole).toUrl();

    // 2. Classify devices and remote entries using locale-independent KFilePlacesModel::GroupType & Solid checks
    bool isDev = false;
    bool isRemote = isExpandedNetworkEntry || isNetworkUrl(url);
    if (placesModel) {
        const KFilePlacesModel::GroupType grpType = placesModel->groupType(leafIdx);
        isDev = placesModel->isDevice(leafIdx)
            || grpType == KFilePlacesModel::DevicesType
            || grpType == KFilePlacesModel::RemovableDevicesType;
        isRemote = isRemote || grpType == KFilePlacesModel::RemoteType;
    }

    const bool isEssential = srcModel->data(idx, ZenPlacesMasterModel::IsEssentialRole).toBool();
    const bool isWorkspacePlace = srcModel->data(idx, ZenPlacesMasterModel::IsWorkspacePlaceRole).toBool();
    const bool isPinned = srcModel->data(idx, ZenPlacesMasterModel::IsPinnedDeviceRole).toBool();

    switch (m_sectionType) {
        case Essentials:
            // Essential tiles remain visible even if the user hid the duplicate entry in the Workspace Places list
            return isEssential;

        case Trash:
            return url.scheme() == QLatin1String("trash");

        case Devices:
            if (isHidden && !m_showHiddenPlaces) {
                return false;
            }
            // Hardware drives, removable storage, or network shares
            if (!isDev && !isRemote) {
                return false;
            }
            // When network folder expansion is enabled, hide the root "remote:/" container folder itself
            if (m_expandNetworkFolder && !isExpandedNetworkEntry
                && url.scheme() == QLatin1String("remote")
                && (url.path().isEmpty() || url.path() == QLatin1String("/"))) {
                return false;
            }
            // In auto-hide collapsed mode, only keep explicitly pinned devices visible
            if (m_onlyPinned && !isPinned) {
                return false;
            }
            return true;

        case WorkspacePlaces:
            if (isHidden && !m_showHiddenPlaces) {
                return false;
            }
            // Exclude entries that exist exclusively as Essential tiles (isWorkspacePlace == false)
            if (!isWorkspacePlace) {
                return false;
            }
            // Regular bookmarks and places: exclude Trash, Devices, and Remote entries
            if (url.scheme() == QLatin1String("trash") || isDev || isRemote) {
                return false;
            }
            return true;
    }

    return false;
}

bool ZenSectionFilterProxy::lessThan(const QModelIndex &sourceLeft, const QModelIndex &sourceRight) const
{
    if (m_sectionType == Essentials) {
        const auto *master = qobject_cast<const ZenPlacesMasterModel *>(sourceModel());
        if (master) {
            const QString keyLeft = master->placeKey(sourceLeft);
            const QString keyRight = master->placeKey(sourceRight);
            const KConfigGroup group = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelEssentialsOrder"));
            const QStringList order = group.readEntry(QStringLiteral("Order"), QStringList());

            int idxLeft = order.indexOf(keyLeft);
            int idxRight = order.indexOf(keyRight);

            if (idxLeft < 0) {
                idxLeft = 9999 + sourceLeft.row();
            }
            if (idxRight < 0) {
                idxRight = 9999 + sourceRight.row();
            }

            if (idxLeft != idxRight) {
                return idxLeft < idxRight;
            }
        }
    }

    if (m_sectionType == Devices) {
        auto unwrapLeaf = [](const QModelIndex &idx) -> QModelIndex {
            if (const auto *concatProxy = qobject_cast<const QConcatenateTablesProxyModel *>(idx.model())) {
                return concatProxy->mapToSource(idx);
            }
            return idx;
        };

        const QModelIndex leafLeft = unwrapLeaf(sourceLeft);
        const QModelIndex leafRight = unwrapLeaf(sourceRight);

        auto calculateDevicePriority = [](const QModelIndex &leafIdx) -> int {
            const auto *placesModel = qobject_cast<const KFilePlacesModel *>(leafIdx.model());
            const QUrl url = placesModel ? placesModel->url(leafIdx) : leafIdx.data(KFilePlacesModel::UrlRole).toUrl();
            const QString path = url.isLocalFile() ? url.toLocalFile() : QString();
            const QString name = leafIdx.data(Qt::DisplayRole).toString().trimmed().toLower();

            // Priority 0: Root / Main System Partition ("/")
            if (path == QLatin1String("/") || name == QLatin1String("root") || name == QLatin1String("system") || name.startsWith(QLatin1String("root "))) {
                return 0;
            }

            // Priority 5: Low-level system partitions (/boot, /efi) safely placed at the very bottom
            if ((!path.isEmpty() && (path.startsWith(QLatin1String("/boot")) || path.startsWith(QLatin1String("/efi"))))
                || name.contains(QLatin1String("boot")) || name.contains(QLatin1String("efi"))) {
                return 5;
            }

            if (placesModel) {
                const KFilePlacesModel::GroupType grpType = placesModel->groupType(leafIdx);
                // Priority 1: Fixed local partitions / internal drives
                if (grpType == KFilePlacesModel::DevicesType || (placesModel->isDevice(leafIdx) && leafIdx.data(KFilePlacesModel::FixedDeviceRole).toBool())) {
                    return 1;
                }
                // Priority 2: Removable storage devices (USB, external disks, SD cards)
                if (grpType == KFilePlacesModel::RemovableDevicesType) {
                    return 2;
                }
            }

            // Priority 3: Root network container "remote:/"
            if (url.scheme() == QLatin1String("remote") && (url.path().isEmpty() || url.path() == QLatin1String("/"))) {
                return 3;
            }

            // Priority 4: Discovered network shares, remote servers & mobile devices (KDE Connect, MTP, Samba, SFTP, NFS)
            return 4;
        };

        const int prioLeft = calculateDevicePriority(leafLeft);
        const int prioRight = calculateDevicePriority(leafRight);

        if (prioLeft != prioRight) {
            return prioLeft < prioRight;
        }

        // Within the same category tier: sort alphabetically by localized display name
        const QString nameLeft = sourceModel()->data(sourceLeft, Qt::DisplayRole).toString();
        const QString nameRight = sourceModel()->data(sourceRight, Qt::DisplayRole).toString();
        const int cmp = QString::localeAwareCompare(nameLeft, nameRight);
        if (cmp != 0) {
            return cmp < 0;
        }
    }

    return QSortFilterProxyModel::lessThan(sourceLeft, sourceRight);
}
