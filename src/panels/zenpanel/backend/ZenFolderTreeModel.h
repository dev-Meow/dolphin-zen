#pragma once

#include <KDirSortFilterProxyModel>
#include <KFileItem>
#include <QUrl>
#include <QModelIndex>
#include <QHash>
#include <QByteArray>
#include <QtQml/qqmlregistration.h>

class KDirModel;

/**
 * @brief Proxy model providing a single-column directory tree for ZenPanel.
 *
 * Filters directories using KDirLister MIME filters and limits columns to 1 (name only)
 * to avoid horizontal duplication in QML TreeView/TableView components.
 */
class ZenFolderTreeModel : public KDirSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl rootUrl READ rootUrl WRITE setRootUrl NOTIFY rootUrlChanged FINAL)
    Q_PROPERTY(bool showHiddenFiles READ showHiddenFiles WRITE setShowHiddenFiles NOTIFY showHiddenFilesChanged FINAL)
    Q_PROPERTY(bool limitToHome READ limitToHome WRITE setLimitToHome NOTIFY limitToHomeChanged FINAL)

public:
    explicit ZenFolderTreeModel(QObject *parent = nullptr);
    ~ZenFolderTreeModel() override;

    /**
     * @brief Ensures Qt::DisplayRole returns a non-empty name for column 0.
     */
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    /**
     * @brief Exports standard role names to QML context.
     */
    QHash<int, QByteArray> roleNames() const override;

    QUrl rootUrl() const;
    void setRootUrl(const QUrl &url);

    bool showHiddenFiles() const;
    void setShowHiddenFiles(bool show);

    /**
     * @brief Returns whether the directory tree root is restricted to the user's home directory (~) or system root (/).
     */
    bool limitToHome() const;
    void setLimitToHome(bool limit);

    /**
     * @brief Resolves source file URL from proxy index.
     */
    Q_INVOKABLE QUrl urlForIndex(const QModelIndex &index) const;

    /**
     * @brief Returns the cached KFileItem for @p url from KDirLister, or constructs a fallback KFileItem.
     */
    KFileItem fileItemForUrl(const QUrl &url) const;

Q_SIGNALS:
    void rootUrlChanged();
    void showHiddenFilesChanged();
    void limitToHomeChanged();

protected:
    /**
     * @brief Restricts visible columns strictly to column 0 (KDirModel::Name)
     *        while keeping QSortFilterProxyModel column mappings consistent.
     */
    bool filterAcceptsColumn(int sourceColumn, const QModelIndex &sourceParent) const override;

private:
    KDirModel *m_dirModel = nullptr;
    QUrl m_rootUrl;
};
