#pragma once

#include <QSortFilterProxyModel>
#include <QtQml/qqmlregistration.h>

/**
 * @brief Filter and sorting proxy partitioning ZenPlacesMasterModel into the 4 ZenPanel UI sections.
 *
 * Uses native KF6::KIOFileWidgets APIs (KFilePlacesModel::isDevice, KFilePlacesModel::groupType,
 * KFilePlacesModel::isHidden) for locale-independent classification.
 */
class ZenSectionFilterProxy : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(SectionType sectionType READ sectionType WRITE setSectionType NOTIFY sectionTypeChanged)
    Q_PROPERTY(bool onlyPinned READ onlyPinned WRITE setOnlyPinned NOTIFY onlyPinnedChanged)
    Q_PROPERTY(bool expandNetworkFolder READ expandNetworkFolder WRITE setExpandNetworkFolder NOTIFY expandNetworkFolderChanged)
    Q_PROPERTY(bool showHiddenPlaces READ showHiddenPlaces WRITE setShowHiddenPlaces NOTIFY showHiddenPlacesChanged)
    Q_PROPERTY(int maxItems READ maxItems WRITE setMaxItems NOTIFY maxItemsChanged)

public:
    enum SectionType {
        Essentials,      ///< Section 3.1: Pinned favorite tiles (isEssential == true)
        WorkspacePlaces, ///< Section 3.2: Regular places/bookmarks (excludes devices, remote, and trash)
        Devices,         ///< Section 3.3: Hardware drives, removable media, and network shares
        Trash            ///< Section 3.4: Isolated trash entry (url.scheme() == "trash")
    };
    Q_ENUM(SectionType)

    explicit ZenSectionFilterProxy(QObject *parent = nullptr);

    QHash<int, QByteArray> roleNames() const override;

    SectionType sectionType() const;
    void setSectionType(SectionType type);

    bool onlyPinned() const;
    void setOnlyPinned(bool pinned);

    bool expandNetworkFolder() const;
    void setExpandNetworkFolder(bool expand);

    bool showHiddenPlaces() const;
    void setShowHiddenPlaces(bool show);

    int maxItems() const;
    void setMaxItems(int max);

Q_SIGNALS:
    void sectionTypeChanged();
    void onlyPinnedChanged();
    void expandNetworkFolderChanged();
    void showHiddenPlacesChanged();
    void maxItemsChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
    bool lessThan(const QModelIndex &sourceLeft, const QModelIndex &sourceRight) const override;

private:
    bool isNetworkUrl(const QUrl &url) const;

    SectionType m_sectionType = WorkspacePlaces;
    bool m_onlyPinned = false;
    bool m_expandNetworkFolder = false;
    bool m_showHiddenPlaces = false;
    int m_maxItems = -1;
};
