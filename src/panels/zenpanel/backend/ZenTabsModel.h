/*
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <QAbstractListModel>
#include <QUrl>
#include <QVector>
#include <QtQml/qqmlregistration.h>

struct ZenTabInfo {
    int index = 0;
    QString title;
    QUrl primaryUrl;
    QUrl secondaryUrl; // Empty when split-view is inactive
    QString iconName = QStringLiteral("folder");
    bool isSplitActive = false;
    bool isSecondaryFocused = false;
    bool isCurrentTab = false;
};

/**
 * @brief Tracks open Dolphin tabs and split-view panes for location highlighting and smart tab switching.
 */
class ZenTabsModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int activeTabIndex READ activeTabIndex NOTIFY activeTabIndexChanged FINAL)
    Q_PROPERTY(QUrl activeUrl READ activeUrl NOTIFY activeUrlChanged FINAL)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)
    Q_PROPERTY(int revision READ revision NOTIFY stateChanged FINAL)

public:
    enum TabRoles {
        TabIndexRole = Qt::UserRole + 200,
        TitleRole,
        PrimaryUrlRole,
        SecondaryUrlRole,
        IconNameRole,
        IsSplitActiveRole,
        IsSecondaryFocusedRole,
        IsCurrentTabRole,
        FormattedPrimaryPathRole,
        FormattedSecondaryPathRole
    };
    Q_ENUM(TabRoles)

    explicit ZenTabsModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // --- Queries for smart navigation & multi-highlighting ---
    Q_INVOKABLE bool hasUrl(const QUrl &url) const;
    Q_INVOKABLE int tabIndexForUrl(const QUrl &url) const;
    Q_INVOKABLE bool isUrlActive(const QUrl &url) const;
    bool findTabForUrl(const QUrl &url, int *outTabIndex, bool *outIsSecondarySplit = nullptr) const;

    int activeTabIndex() const;
    QUrl activeUrl() const;
    int revision() const;

    // --- Tab state mutations ---
    Q_INVOKABLE void activateTab(int index, bool focusSecondary = false);
    Q_INVOKABLE void closeTab(int index);
    void setCurrentTabUrl(const QUrl &url);
    int openNewTab(const QUrl &url);
    void syncTabs(const QVector<ZenTabInfo> &tabs);

    // --- Simulator interface for preview harness (zenpanel_preview) ---
    Q_INVOKABLE void simulateAddTab(const QString &title, const QUrl &primaryUrl, const QUrl &secondaryUrl = QUrl());
    Q_INVOKABLE void simulateSetSplit(int index, bool active, const QUrl &secondaryUrl = QUrl());
    Q_INVOKABLE void simulateFocusSecondary(int index, bool secondaryFocused);

Q_SIGNALS:
    void activeTabIndexChanged();
    void activeUrlChanged();
    void countChanged();
    void stateChanged();
    void tabActivated(int index, bool focusSecondary);
    void tabCloseRequested(int index);

private:
    static bool urlsMatch(const QUrl &a, const QUrl &b);
    static QString titleForUrl(const QUrl &url);
    QString formatPath(const QUrl &url) const;
    void updateActiveState();

    QVector<ZenTabInfo> m_tabs;
    int m_revision = 0;
};
