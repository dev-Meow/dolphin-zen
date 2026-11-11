/*
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <KFileItem>
#include <QAbstractListModel>
#include <QList>
#include <QUrl>

class KCoreDirLister;

/**
 * @brief Asynchronous model listing the child entries of "remote:/" when network folder expansion is enabled.
 *
 * Exposes the exact same role identifiers and roleNames() as ZenPlacesMasterModel so it can be
 * combined seamlessly via QConcatenateTablesProxyModel into the Devices section proxy without
 * polluting the user's persistent user-places.xbel file.
 */
class ZenNetworkPlacesModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged FINAL)

public:
    explicit ZenNetworkPlacesModel(QObject *parent = nullptr);
    ~ZenNetworkPlacesModel() override;

    bool isEnabled() const;
    void setEnabled(bool enabled);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    bool setData(const QModelIndex &index, const QVariant &value, int role = Qt::EditRole) override;
    QHash<int, QByteArray> roleNames() const override;

Q_SIGNALS:
    void enabledChanged();

private Q_SLOTS:
    void onItemsAdded(const QUrl &directoryUrl, const KFileItemList &items);
    void onItemsDeleted(const KFileItemList &items);
    void onListerCleared();

private:
    static QUrl effectiveUrl(const KFileItem &item);
    static QString itemKey(const KFileItem &item);

    KCoreDirLister *m_dirLister = nullptr;
    QList<KFileItem> m_items;
    bool m_enabled = false;
};
