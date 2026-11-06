#include "ZenFolderTreeModel.h"
#include "zenpanelsettings.h"

#include <KDirModel>
#include <KDirLister>
#include <KFileItem>
#include <KSharedConfig>
#include <KConfigGroup>
#include <QDir>

ZenFolderTreeModel::ZenFolderTreeModel(QObject *parent)
: KDirSortFilterProxyModel(parent)
, m_dirModel(new KDirModel(this))
{
    auto *settings = ZenPanelSettings::self();
    const bool limitHome = settings->limitTreeToHome();
    m_rootUrl = QUrl::fromLocalFile(limitHome ? QDir::homePath() : QDir::rootPath());

    // Restrict listings strictly to directories for the sidebar tree
    m_dirModel->dirLister()->setDirOnlyMode(true);
    m_dirModel->dirLister()->setMimeFilter({QStringLiteral("inode/directory")});
    m_dirModel->dirLister()->setShowHiddenFiles(settings->showHiddenFoldersInTree());

    setSourceModel(m_dirModel);
    sort(KDirModel::Name, Qt::AscendingOrder);

    m_dirModel->openUrl(m_rootUrl);
}

ZenFolderTreeModel::~ZenFolderTreeModel() = default;

bool ZenFolderTreeModel::filterAcceptsColumn(int sourceColumn, const QModelIndex &/*sourceParent*/) const
{
    // KDirModel exposes multiple metadata columns; restrict proxy strictly to the Name column
    return sourceColumn == KDirModel::Name;
}

QHash<int, QByteArray> ZenFolderTreeModel::roleNames() const
{
    QHash<int, QByteArray> roles = KDirSortFilterProxyModel::roleNames();
    roles[Qt::DisplayRole] = "display";
    roles[Qt::DecorationRole] = "decoration";
    return roles;
}

QVariant ZenFolderTreeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) {
        return {};
    }

    if (role == Qt::DisplayRole) {
        const QModelIndex srcIndex = mapToSource(index);
        if (srcIndex.isValid()) {
            const KFileItem item = m_dirModel->itemForIndex(srcIndex);
            if (!item.isNull()) {
                return item.text();
            }
        }
    }

    return KDirSortFilterProxyModel::data(index, role);
}

QUrl ZenFolderTreeModel::rootUrl() const
{
    return m_rootUrl;
}

void ZenFolderTreeModel::setRootUrl(const QUrl &url)
{
    if (m_rootUrl != url && !url.isEmpty()) {
        m_rootUrl = url;
        m_dirModel->dirLister()->openUrl(m_rootUrl, KDirLister::Reload);
        Q_EMIT rootUrlChanged();
    }
}

bool ZenFolderTreeModel::showHiddenFiles() const
{
    return m_dirModel->dirLister()->showHiddenFiles();
}

void ZenFolderTreeModel::setShowHiddenFiles(bool show)
{
    if (m_dirModel->dirLister()->showHiddenFiles() != show) {
        m_dirModel->dirLister()->setShowHiddenFiles(show);
        m_dirModel->dirLister()->emitChanges();

        auto *settings = ZenPanelSettings::self();
        if (settings->showHiddenFoldersInTree() != show) {
            settings->setShowHiddenFoldersInTree(show);
            settings->save();
        }

        // Sync to dolphinrc FoldersPanel
        KSharedConfig::Ptr dolphinConfig = KSharedConfig::openConfig(QStringLiteral("dolphinrc"));
        KConfigGroup foldersGroup(dolphinConfig, QStringLiteral("FoldersPanel"));
        foldersGroup.writeEntry(QStringLiteral("HiddenFilesShown"), show);
        dolphinConfig->sync();

        Q_EMIT showHiddenFilesChanged();
    }
}

bool ZenFolderTreeModel::limitToHome() const
{
    return ZenPanelSettings::self()->limitTreeToHome();
}

void ZenFolderTreeModel::setLimitToHome(bool limit)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->limitTreeToHome() != limit) {
        settings->setLimitTreeToHome(limit);
        settings->save();

        // Sync to dolphinrc FoldersPanel
        KSharedConfig::Ptr dolphinConfig = KSharedConfig::openConfig(QStringLiteral("dolphinrc"));
        KConfigGroup foldersGroup(dolphinConfig, QStringLiteral("FoldersPanel"));
        foldersGroup.writeEntry(QStringLiteral("LimitFoldersPanelToHome"), limit);
        dolphinConfig->sync();

        setRootUrl(QUrl::fromLocalFile(limit ? QDir::homePath() : QDir::rootPath()));
        Q_EMIT limitToHomeChanged();
    }
}

QUrl ZenFolderTreeModel::urlForIndex(const QModelIndex &index) const
{
    if (!index.isValid()) {
        return {};
    }

    const QModelIndex srcIndex = mapToSource(index);
    if (!srcIndex.isValid()) {
        return {};
    }

    const KFileItem item = m_dirModel->itemForIndex(srcIndex);
    return item.url();
}

KFileItem ZenFolderTreeModel::fileItemForUrl(const QUrl &url) const
{
    if (!url.isValid()) {
        return {};
    }
    const KFileItem cached = m_dirModel->dirLister()->findByUrl(url);
    if (!cached.isNull()) {
        return cached;
    }
    return KFileItem(url);
}
