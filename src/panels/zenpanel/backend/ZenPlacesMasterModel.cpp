#include "ZenPlacesMasterModel.h"
#include "zenpanelsettings.h"

#include <KBookmark>
#include <KConfigGroup>
#include <KIO/Global>
#include <KLocalizedString>
#include <KSharedConfig>
#include <KShell>
#include <Solid/StorageAccess>
#include <QLoggingCategory>
#include <QStorageInfo>

Q_DECLARE_LOGGING_CATEGORY(zenLog)

ZenPlacesMasterModel::ZenPlacesMasterModel(QObject *parent)
: KFilePlacesModel(parent)
{
    loadEssentialMetadata();

    // Forward dynamic Solid device state changes (mount/unmount/accessibility) to custom Zen roles
    connect(this, &QAbstractItemModel::dataChanged, this, [this](const QModelIndex &topLeft, const QModelIndex &bottomRight, const QList<int> &roles) {
        if (roles.contains(CapacityPercentageRole)
            || roles.contains(FreeSpaceTextRole)
            || roles.contains(IsEssentialRole)
            || roles.contains(IsWorkspacePlaceRole)
            || roles.contains(IsPinnedDeviceRole)) {
            return;
        }
        if (roles.isEmpty()
            || roles.contains(KFilePlacesModel::CapacityBarRecommendedRole)
            || roles.contains(KFilePlacesModel::DeviceAccessibilityRole)
            || roles.contains(KFilePlacesModel::TeardownAllowedRole)
            || roles.contains(KFilePlacesModel::EjectAllowedRole)
            || roles.contains(KFilePlacesModel::SetupNeededRole)) {
            Q_EMIT dataChanged(topLeft, bottomRight, {CapacityPercentageRole, FreeSpaceTextRole, CanTeardownRole, FormattedPathRole});
        }
    });
}

ZenPlacesMasterModel::~ZenPlacesMasterModel() = default;

QString ZenPlacesMasterModel::placeKey(const QModelIndex &index) const
{
    if (!index.isValid()) {
        return {};
    }

    const KBookmark bm = bookmarkForIndex(index);
    if (!bm.isNull()) {
        const QString id = bm.metaDataItem(QStringLiteral("ID"));
        if (!id.isEmpty()) {
            return id;
        }
    }

    return url(index).toString();
}

QHash<int, QByteArray> ZenPlacesMasterModel::roleNames() const
{
    QHash<int, QByteArray> roles = KFilePlacesModel::roleNames();
    roles[Qt::DisplayRole] = "display";
    roles[Qt::DecorationRole] = "decoration";
    roles[KFilePlacesModel::IconNameRole] = "iconName";
    roles[KFilePlacesModel::UrlRole] = "url";
    roles[KFilePlacesModel::HiddenRole] = "isHidden";
    roles[FormattedPathRole] = "formattedPath";
    roles[IsEssentialRole] = "isEssential";
    roles[IsWorkspacePlaceRole] = "isWorkspacePlace";
    roles[IsPinnedDeviceRole] = "isPinnedDevice";
    roles[CapacityPercentageRole] = "capacityPercentage";
    roles[FreeSpaceTextRole] = "freeSpaceText";
    roles[CanTeardownRole] = "canTeardown";
    return roles;
}

QVariant ZenPlacesMasterModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) {
        return {};
    }

    if (role == IsEssentialRole) {
        const QString id = placeKey(index);
        const KConfigGroup group = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelEssentials"));
        return group.readEntry(id, false);
    }

    if (role == IsWorkspacePlaceRole) {
        const QString id = placeKey(index);
        const KConfigGroup group = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelWorkspacePlaces"));
        return group.readEntry(id, true);
    }

    if (role == IsPinnedDeviceRole) {
        const QString id = placeKey(index);
        const KConfigGroup group = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelPinnedDevices"));
        return group.readEntry(id, false);
    }

    if (role == FormattedPathRole) {
        const QUrl placeUrl = url(index);
        if (placeUrl.isLocalFile()) {
            return KShell::tildeCollapse(placeUrl.toLocalFile());
        }
        return placeUrl.toDisplayString(QUrl::PreferLocalFile);
    }

    if (role == CapacityPercentageRole || role == FreeSpaceTextRole) {
        if (!KFilePlacesModel::data(index, KFilePlacesModel::CapacityBarRecommendedRole).toBool()) {
            return role == CapacityPercentageRole ? QVariant(-1) : QVariant(QString());
        }

        QString mountPath = url(index).toLocalFile();
        if (mountPath.isEmpty() && isDevice(index)) {
            const Solid::Device dev = deviceForIndex(index);
            if (const auto *access = dev.as<Solid::StorageAccess>(); access && access->isAccessible()) {
                mountPath = access->filePath();
            }
        }

        if (mountPath.isEmpty()) {
            return role == CapacityPercentageRole ? QVariant(-1) : QVariant(QString());
        }

        const QStorageInfo storage(mountPath);
        if (!storage.isValid() || !storage.isReady() || storage.bytesTotal() <= 0) {
            return role == CapacityPercentageRole ? QVariant(-1) : QVariant(QString());
        }

        const qint64 totalBytes = storage.bytesTotal();
        const qint64 availableBytes = storage.bytesAvailable();
        const qint64 usedBytes = totalBytes - availableBytes;
        const int percent = qBound(0, qRound((static_cast<double>(usedBytes) * 100.0) / static_cast<double>(totalBytes)), 100);

        if (role == CapacityPercentageRole) {
            return percent;
        }

        return i18nc("@info:tooltip Available space out of total partition size (percent used)",
                     "%1 free of %2 (%3% used)",
                     KIO::convertSize(static_cast<KIO::filesize_t>(qMax<qint64>(0, availableBytes))),
                     KIO::convertSize(static_cast<KIO::filesize_t>(totalBytes)),
                     percent);
    }

    if (role == CanTeardownRole) {
        return isTeardownAllowed(index) || isEjectAllowed(index);
    }

    if (role == Qt::DecorationRole || role == KFilePlacesModel::IconNameRole) {
        const QString nameFromPlaces = KFilePlacesModel::data(index, KFilePlacesModel::IconNameRole).toString();
        if (!nameFromPlaces.isEmpty()) {
            return nameFromPlaces;
        }
        const KBookmark bm = bookmarkForIndex(index);
        if (!bm.isNull() && !bm.icon().isEmpty()) {
            return bm.icon();
        }
        if (isDevice(index)) {
            const Solid::Device dev = deviceForIndex(index);
            if (dev.isValid() && !dev.icon().isEmpty()) {
                return dev.icon();
            }
        }
        return KFilePlacesModel::data(index, Qt::DecorationRole);
    }

    return KFilePlacesModel::data(index, role);
}

bool ZenPlacesMasterModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    if (!index.isValid()) {
        return false;
    }

    if (role == IsEssentialRole) {
        const QString id = placeKey(index);
        KConfigGroup group = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelEssentials"));
        group.writeEntry(id, value.toBool());
        group.sync();
        Q_EMIT dataChanged(index, index, {IsEssentialRole});
        return true;
    }

    if (role == IsWorkspacePlaceRole) {
        const QString id = placeKey(index);
        KConfigGroup group = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelWorkspacePlaces"));
        group.writeEntry(id, value.toBool());
        group.sync();
        Q_EMIT dataChanged(index, index, {IsWorkspacePlaceRole});
        return true;
    }

    if (role == IsPinnedDeviceRole) {
        const QString id = placeKey(index);
        KConfigGroup group = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelPinnedDevices"));
        group.writeEntry(id, value.toBool());
        group.sync();
        Q_EMIT dataChanged(index, index, {IsPinnedDeviceRole});
        return true;
    }

    return KFilePlacesModel::setData(index, value, role);
}

int ZenPlacesMasterModel::maxEssentials() const
{
    return ZenPanelSettings::self()->maxEssentials();
}

int ZenPlacesMasterModel::essentialsCount() const
{
    int count = 0;
    const int total = rowCount();
    for (int i = 0; i < total; ++i) {
        if (data(this->index(i, 0), IsEssentialRole).toBool()) {
            ++count;
        }
    }
    return count;
}

bool ZenPlacesMasterModel::canAddEssential() const
{
    return essentialsCount() < maxEssentials();
}

int ZenPlacesMasterModel::rowForUrl(const QUrl &url) const
{
    const int total = rowCount();
    for (int i = 0; i < total; ++i) {
        if (this->url(index(i, 0)) == url) {
            return i;
        }
    }
    return -1;
}

bool ZenPlacesMasterModel::isSystemItem(const QModelIndex &index) const
{
    if (!index.isValid()) {
        return false;
    }
    const KBookmark bm = bookmarkForIndex(index);
    return bm.metaDataItem(QStringLiteral("isSystemItem")) == QLatin1String("true");
}

void ZenPlacesMasterModel::toggleEssential(int row)
{
    const QModelIndex idx = index(row, 0);
    if (!idx.isValid()) {
        return;
    }

    const bool currentState = data(idx, IsEssentialRole).toBool();
    if (currentState) {
        removeFromEssentials(idx);
        return;
    }

    if (!canAddEssential()) {
        return;
    }

    setData(idx, true, IsEssentialRole);
}

void ZenPlacesMasterModel::toggleDevicePin(int row)
{
    const QModelIndex idx = index(row, 0);
    if (!idx.isValid()) {
        return;
    }

    const bool currentState = data(idx, IsPinnedDeviceRole).toBool();
    setData(idx, !currentState, IsPinnedDeviceRole);
}

bool ZenPlacesMasterModel::addAsEssential(const QUrl &url, const QString &customTitle)
{
    if (!canAddEssential() || !url.isValid()) {
        return false;
    }

    int row = rowForUrl(url);
    bool newlyCreatedForEssentialOnly = false;
    if (row < 0) {
        const QString title = customTitle.isEmpty() ? url.fileName() : customTitle;
        addPlace(title, url, QStringLiteral("folder"));
        row = rowForUrl(url);
        newlyCreatedForEssentialOnly = true;
    }

    if (row >= 0) {
        const QModelIndex idx = index(row, 0);
        if (newlyCreatedForEssentialOnly) {
            setData(idx, false, IsWorkspacePlaceRole);
        }
        setData(idx, true, IsEssentialRole);

        // Append new essential to the persistent custom order list if not already present
        const QString key = placeKey(idx);
        KConfigGroup orderGroup = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelEssentialsOrder"));
        QStringList order = orderGroup.readEntry(QStringLiteral("Order"), QStringList());
        if (!order.contains(key)) {
            order.append(key);
            orderGroup.writeEntry(QStringLiteral("Order"), order);
            orderGroup.sync();
        }

        return true;
    }

    return false;
}

void ZenPlacesMasterModel::removeFromEssentials(const QModelIndex &index)
{
    if (!index.isValid()) {
        return;
    }

    const bool isInWorkspace = data(index, IsWorkspacePlaceRole).toBool();
    const bool sysItem = isSystemItem(index);
    const QString key = placeKey(index);

    setData(index, false, IsEssentialRole);

    // Remove from custom essentials order list
    KConfigGroup orderGroup = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelEssentialsOrder"));
    QStringList order = orderGroup.readEntry(QStringLiteral("Order"), QStringList());
    if (order.removeAll(key) > 0) {
        orderGroup.writeEntry(QStringLiteral("Order"), order);
        orderGroup.sync();
    }

    // If this entry was added exclusively as an Essential (not a Workspace Place and not a system bookmark),
    // remove the underlying XBEL bookmark completely so no orphan entry remains.
    if (!isInWorkspace && !sysItem) {
        KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelEssentials")).deleteEntry(key);
        KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelWorkspacePlaces")).deleteEntry(key);
        KSharedConfig::openConfig()->sync();
        removePlace(index);
    }
}

void ZenPlacesMasterModel::removeFromWorkspacePlaces(const QModelIndex &index)
{
    if (!index.isValid()) {
        return;
    }

    const bool isEssential = data(index, IsEssentialRole).toBool();
    if (isEssential) {
        // Keep the underlying XBEL bookmark alive for the Essentials tile, just hide it from Workspace Places
        setData(index, false, IsWorkspacePlaceRole);
        return;
    }

    if (!isSystemItem(index)) {
        const QString key = placeKey(index);
        KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelEssentials")).deleteEntry(key);
        KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelWorkspacePlaces")).deleteEntry(key);
        KSharedConfig::openConfig()->sync();
        removePlace(index);
    }
}

bool ZenPlacesMasterModel::addUrlToWorkspacePlaces(const QUrl &url, const QString &customTitle)
{
    if (!url.isValid()) {
        return false;
    }

    int row = rowForUrl(url);
    if (row < 0) {
        const QString title = customTitle.isEmpty() ? url.fileName() : customTitle;
        const QString iconName = KIO::iconNameForUrl(url);
        addPlace(title, url, iconName.isEmpty() ? QStringLiteral("folder") : iconName);
        row = rowForUrl(url);
    }

    if (row >= 0) {
        setData(index(row, 0), true, IsWorkspacePlaceRole);
        return true;
    }

    return false;
}

void ZenPlacesMasterModel::printDiagnosticPlaces() const
{
    qCDebug(zenLog) << "=== [WP 2.1 MasterModel Diagnostic] ===";
    const int total = rowCount();
    for (int i = 0; i < total; ++i) {
        const QModelIndex idx = index(i, 0);
        qCDebug(zenLog) << QStringLiteral("[%1]").arg(i)
                        << "Display:" << data(idx, Qt::DisplayRole).toString()
                        << "| Path:" << data(idx, FormattedPathRole).toString()
                        << "| Group:" << data(idx, KFilePlacesModel::GroupRole).toString()
                        << "| Hidden:" << data(idx, KFilePlacesModel::HiddenRole).toBool()
                        << "| Essential:" << data(idx, IsEssentialRole).toBool()
                        << "| PinnedDev:" << data(idx, IsPinnedDeviceRole).toBool()
                        << "| Capacity%:" << data(idx, CapacityPercentageRole).toInt();
    }
    qCDebug(zenLog) << "=======================================";
}

void ZenPlacesMasterModel::loadEssentialMetadata()
{
    // Initial sync point for stored metadata
}

void ZenPlacesMasterModel::persistEssentialMetadata()
{
    KSharedConfig::openConfig()->sync();
}
