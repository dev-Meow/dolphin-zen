/*
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

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
    Q_PROPERTY(bool hideEssentialsInWorkspace READ hideEssentialsInWorkspace WRITE setHideEssentialsInWorkspace NOTIFY hideEssentialsInWorkspaceChanged)
    Q_PROPERTY(int maxItems READ maxItems WRITE setMaxItems NOTIFY maxItemsChanged)

public:
    enum SectionType {
        Essentials, ///< Pinned favorite tiles (isEssential == true)
        WorkspacePlaces, ///< Regular places and bookmarks (excludes devices, remote, and trash)
        Devices, ///< Hardware drives, removable media, and network shares
        Trash ///< Isolated trash entry (url.scheme() == "trash")
    };
    Q_ENUM(SectionType)

    explicit ZenSectionFilterProxy(QObject *parent = nullptr);

    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    /**
     * @brief Checks whether a localized group name corresponds to KFilePlacesModel::PlacesType.
     *
     * Allows QML ListView sections to suppress the header for the primary "Places" group
     * while showing localized headers for "Recent" and "Search For" groups.
     */
    Q_INVOKABLE bool isDefaultPlacesGroup(const QString &groupName) const;

    SectionType sectionType() const;
    void setSectionType(SectionType type);

    bool onlyPinned() const;
    void setOnlyPinned(bool pinned);

    bool expandNetworkFolder() const;
    void setExpandNetworkFolder(bool expand);

    bool showHiddenPlaces() const;
    void setShowHiddenPlaces(bool show);

    bool hideEssentialsInWorkspace() const;
    void setHideEssentialsInWorkspace(bool hide);

    int maxItems() const;
    void setMaxItems(int max);

Q_SIGNALS:
    void sectionTypeChanged();
    void onlyPinnedChanged();
    void expandNetworkFolderChanged();
    void showHiddenPlacesChanged();
    void hideEssentialsInWorkspaceChanged();
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
    bool m_hideEssentialsInWorkspace = true;
    int m_maxItems = -1;
};
