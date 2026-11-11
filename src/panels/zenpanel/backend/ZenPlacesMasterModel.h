/*
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <KFilePlacesModel>
#include <QByteArray>
#include <QHash>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

/**
 * @brief Master data source managing bookmarks from user-places.xbel.
 *
 * Extends KFilePlacesModel with metadata flags for pinned items, essential status,
 * and capacity restrictions defined in ZenPanelSettings.
 */
class ZenPlacesMasterModel : public KFilePlacesModel
{
    Q_OBJECT
    QML_ELEMENT

public:
    enum AdditionalRoles {
        FormattedPathRole = Qt::UserRole + 100, ///< Tilde-collapsed local path or display URL for tooltips
        IsEssentialRole, ///< Whether the place is pinned as an Essential tile
        IsWorkspacePlaceRole, ///< Whether the bookmark is shown in the regular Workspace Places list
        IsPinnedDeviceRole, ///< Whether the device remains visible when DevicesSection collapses
        CapacityPercentageRole, ///< Mounted drive usage in percent (0..100), or -1 if not applicable
        FreeSpaceTextRole, ///< Formatted free/total capacity string (KIO::convertSize) for device tooltips
        CanTeardownRole ///< Whether the device can currently be unmounted or ejected
    };
    Q_ENUM(AdditionalRoles)

    explicit ZenPlacesMasterModel(QObject *parent = nullptr);
    ~ZenPlacesMasterModel() override;

    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    bool setData(const QModelIndex &index, const QVariant &value, int role = Qt::EditRole) override;

    int essentialsCount() const;
    int maxEssentials() const;
    bool canAddEssential() const;
    int rowForUrl(const QUrl &url) const;

    /**
     * @brief Returns true if @p index is a default KDE system bookmark (e.g. Home, Downloads, Trash)
     *        that cannot be permanently deleted, only hidden.
     */
    bool isSystemItem(const QModelIndex &index) const;

public Q_SLOTS:
    /**
     * @brief Toggles the IsEssentialRole flag for the master model item at @p row.
     * @param row Source row index in ZenPlacesMasterModel.
     */
    void toggleEssential(int row);

    /**
     * @brief Toggles the IsPinnedDeviceRole flag for the master model item at @p row.
     * @param row Source row index in ZenPlacesMasterModel.
     */
    void toggleDevicePin(int row);

    /**
     * @brief Adds @p url to the places model (if not already present) and marks it as an Essential tile.
     *        If the URL was not previously in the places model, its IsWorkspacePlaceRole is set to false
     *        so it only appears in the Essentials grid unless explicitly added to Workspace Places.
     * @param url Target folder URL.
     * @param customTitle Optional display title; defaults to the folder name.
     * @return true if the item was marked as essential, false if the limit was reached or URL is invalid.
     */
    bool addAsEssential(const QUrl &url, const QString &customTitle = QString());

    /**
     * @brief Removes the item at @p index from the Essentials grid.
     *        If the item is an Essential-only entry (!IsWorkspacePlaceRole and !isSystemItem),
     *        removes its underlying XBEL bookmark completely to avoid orphan entries.
     */
    void removeFromEssentials(const QModelIndex &index);

    /**
     * @brief Removes the item at @p index from the Workspace Places list.
     *        If the item is still marked as an Essential tile or is a system bookmark, preserves the XBEL bookmark and sets
     *        IsWorkspacePlaceRole to false; otherwise removes the XBEL bookmark via removePlace().
     */
    void removeFromWorkspacePlaces(const QModelIndex &index);

    /**
     * @brief Number of places currently hidden, including system XBEL hidden items
     *        and entries hidden locally from Workspace Places via IsWorkspacePlaceRole.
     */
    int hiddenCount() const;

    /**
     * @brief Adds @p url to the regular Workspace Places list (or re-enables IsWorkspacePlaceRole if it was Essential-only).
     */
    bool addUrlToWorkspacePlaces(const QUrl &url, const QString &customTitle = QString());

    /**
     * @brief Resolves a persistent unique identifier for @p index (XBEL bookmark ID or URL string).
     */
    QString placeKey(const QModelIndex &index) const;

private:
    void loadEssentialMetadata();
    void persistEssentialMetadata();
};
