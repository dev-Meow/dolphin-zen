/*
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "ZenTabsModel.h"

#include <KShell>
#include <QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(zenLog)

ZenTabsModel::ZenTabsModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int ZenTabsModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_tabs.size();
}

QHash<int, QByteArray> ZenTabsModel::roleNames() const
{
    return {{TabIndexRole, "tabIndex"},
            {TitleRole, "title"},
            {PrimaryUrlRole, "primaryUrl"},
            {SecondaryUrlRole, "secondaryUrl"},
            {IconNameRole, "iconName"},
            {IsSplitActiveRole, "isSplitActive"},
            {IsSecondaryFocusedRole, "isSecondaryFocused"},
            {IsCurrentTabRole, "isCurrentTab"},
            {FormattedPrimaryPathRole, "formattedPrimaryPath"},
            {FormattedSecondaryPathRole, "formattedSecondaryPath"}};
}

QString ZenTabsModel::formatPath(const QUrl &url) const
{
    if (url.isEmpty()) {
        return QString();
    }
    if (url.isLocalFile()) {
        return KShell::tildeCollapse(url.toLocalFile());
    }
    return url.toDisplayString(QUrl::PreferLocalFile);
}

QVariant ZenTabsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_tabs.size()) {
        return QVariant();
    }

    const ZenTabInfo &tab = m_tabs.at(index.row());

    switch (role) {
    case Qt::DisplayRole:
    case TitleRole:
        return tab.title;
    case TabIndexRole:
        return tab.index;
    case PrimaryUrlRole:
        return tab.primaryUrl;
    case SecondaryUrlRole:
        return tab.secondaryUrl;
    case IconNameRole:
        return tab.iconName;
    case IsSplitActiveRole:
        return tab.isSplitActive;
    case IsSecondaryFocusedRole:
        return tab.isSecondaryFocused;
    case IsCurrentTabRole:
        return tab.isCurrentTab;
    case FormattedPrimaryPathRole:
        return formatPath(tab.primaryUrl);
    case FormattedSecondaryPathRole:
        return formatPath(tab.secondaryUrl);
    default:
        return QVariant();
    }
}

int ZenTabsModel::activeTabIndex() const
{
    for (int i = 0; i < m_tabs.size(); ++i) {
        if (m_tabs.at(i).isCurrentTab) {
            return i;
        }
    }
    return -1;
}

QUrl ZenTabsModel::activeUrl() const
{
    const int idx = activeTabIndex();
    if (idx < 0 || idx >= m_tabs.size()) {
        return QUrl();
    }
    const ZenTabInfo &tab = m_tabs.at(idx);
    if (tab.isSplitActive && tab.isSecondaryFocused) {
        return tab.secondaryUrl;
    }
    return tab.primaryUrl;
}

int ZenTabsModel::revision() const
{
    return m_revision;
}

bool ZenTabsModel::urlsMatch(const QUrl &a, const QUrl &b)
{
    if (a.isEmpty() || b.isEmpty()) {
        return false;
    }
    return a.adjusted(QUrl::StripTrailingSlash) == b.adjusted(QUrl::StripTrailingSlash);
}

QString ZenTabsModel::titleForUrl(const QUrl &url)
{
    if (url.scheme() == QLatin1String("trash")) {
        return QStringLiteral("Trash");
    }
    if (url.scheme() == QLatin1String("remote")) {
        return QStringLiteral("Network");
    }
    const QString name = url.adjusted(QUrl::StripTrailingSlash).fileName();
    if (!name.isEmpty()) {
        return name;
    }
    return url.toDisplayString(QUrl::PreferLocalFile);
}

bool ZenTabsModel::hasUrl(const QUrl &url) const
{
    return tabIndexForUrl(url) != -1;
}

int ZenTabsModel::tabIndexForUrl(const QUrl &url) const
{
    int tabIdx = -1;
    findTabForUrl(url, &tabIdx, nullptr);
    return tabIdx;
}

bool ZenTabsModel::findTabForUrl(const QUrl &url, int *outTabIndex, bool *outIsSecondarySplit) const
{
    if (outTabIndex) {
        *outTabIndex = -1;
    }
    if (outIsSecondarySplit) {
        *outIsSecondarySplit = false;
    }
    if (url.isEmpty()) {
        return false;
    }

    for (int i = 0; i < m_tabs.size(); ++i) {
        const ZenTabInfo &tab = m_tabs.at(i);
        if (urlsMatch(tab.primaryUrl, url)) {
            if (outTabIndex) {
                *outTabIndex = i;
            }
            if (outIsSecondarySplit) {
                *outIsSecondarySplit = false;
            }
            return true;
        }
        if (tab.isSplitActive && urlsMatch(tab.secondaryUrl, url)) {
            if (outTabIndex) {
                *outTabIndex = i;
            }
            if (outIsSecondarySplit) {
                *outIsSecondarySplit = true;
            }
            return true;
        }
    }
    return false;
}

bool ZenTabsModel::isUrlActive(const QUrl &url) const
{
    return urlsMatch(activeUrl(), url);
}

void ZenTabsModel::activateTab(int index, bool focusSecondary)
{
    if (index < 0 || index >= m_tabs.size()) {
        return;
    }

    bool changed = false;
    for (int i = 0; i < m_tabs.size(); ++i) {
        const bool shouldBeCurrent = (i == index);
        if (m_tabs[i].isCurrentTab != shouldBeCurrent) {
            m_tabs[i].isCurrentTab = shouldBeCurrent;
            changed = true;
        }
        if (shouldBeCurrent) {
            const bool targetSecondary = (m_tabs[i].isSplitActive && focusSecondary);
            if (m_tabs[i].isSecondaryFocused != targetSecondary) {
                m_tabs[i].isSecondaryFocused = targetSecondary;
                changed = true;
            }
        }
    }

    if (changed) {
        Q_EMIT dataChanged(this->index(0, 0), this->index(m_tabs.size() - 1, 0), {IsCurrentTabRole, IsSecondaryFocusedRole});
        updateActiveState();
    }
    Q_EMIT tabActivated(index, focusSecondary);
}

void ZenTabsModel::setCurrentTabUrl(const QUrl &url)
{
    if (!url.isValid()) {
        return;
    }

    int idx = activeTabIndex();
    if (idx < 0) {
        openNewTab(url);
        return;
    }

    ZenTabInfo &tab = m_tabs[idx];
    if (tab.isSplitActive && tab.isSecondaryFocused) {
        tab.secondaryUrl = url;
    } else {
        tab.primaryUrl = url;
        if (!tab.isSplitActive) {
            tab.title = titleForUrl(url);
        }
    }

    const QModelIndex modelIdx = this->index(idx, 0);
    Q_EMIT dataChanged(modelIdx, modelIdx, {TitleRole, PrimaryUrlRole, SecondaryUrlRole, FormattedPrimaryPathRole, FormattedSecondaryPathRole});
    updateActiveState();
}

int ZenTabsModel::openNewTab(const QUrl &url)
{
    if (!url.isValid()) {
        return -1;
    }

    const int newRow = m_tabs.size();
    beginInsertRows(QModelIndex(), newRow, newRow);

    for (ZenTabInfo &existing : m_tabs) {
        existing.isCurrentTab = false;
    }

    ZenTabInfo tab;
    tab.index = newRow;
    tab.title = titleForUrl(url);
    tab.primaryUrl = url;
    tab.isSplitActive = false;
    tab.isSecondaryFocused = false;
    tab.isCurrentTab = true;

    m_tabs.append(tab);
    endInsertRows();

    if (newRow > 0) {
        Q_EMIT dataChanged(this->index(0, 0), this->index(newRow - 1, 0), {IsCurrentTabRole});
    }

    updateActiveState();
    Q_EMIT countChanged();
    return newRow;
}

void ZenTabsModel::closeTab(int index)
{
    if (index < 0 || index >= m_tabs.size()) {
        return;
    }

    Q_EMIT tabCloseRequested(index);

    beginRemoveRows(QModelIndex(), index, index);
    m_tabs.removeAt(index);
    // Re-index remaining tabs
    for (int i = 0; i < m_tabs.size(); ++i) {
        m_tabs[i].index = i;
    }
    endRemoveRows();

    // If the closed tab was active, activate the last remaining tab
    if (!m_tabs.isEmpty() && activeTabIndex() == -1) {
        m_tabs.last().isCurrentTab = true;
        Q_EMIT dataChanged(this->index(m_tabs.size() - 1, 0), this->index(m_tabs.size() - 1, 0), {IsCurrentTabRole});
    }

    updateActiveState();
    Q_EMIT countChanged();
}

void ZenTabsModel::syncTabs(const QVector<ZenTabInfo> &tabs)
{
    beginResetModel();
    m_tabs = tabs;
    for (int i = 0; i < m_tabs.size(); ++i) {
        m_tabs[i].index = i;
    }
    m_revision++;
    endResetModel();

    updateActiveState();
    Q_EMIT countChanged();
    Q_EMIT stateChanged();
}

void ZenTabsModel::simulateAddTab(const QString &title, const QUrl &primaryUrl, const QUrl &secondaryUrl)
{
    const int newRow = m_tabs.size();
    beginInsertRows(QModelIndex(), newRow, newRow);

    ZenTabInfo tab;
    tab.index = newRow;
    tab.title = title;
    tab.primaryUrl = primaryUrl;
    tab.secondaryUrl = secondaryUrl;
    tab.isSplitActive = !secondaryUrl.isEmpty();
    tab.isSecondaryFocused = false;
    tab.isCurrentTab = m_tabs.isEmpty(); // First tab is active by default

    m_tabs.append(tab);
    endInsertRows();

    updateActiveState();
    Q_EMIT countChanged();
}

void ZenTabsModel::simulateSetSplit(int index, bool active, const QUrl &secondaryUrl)
{
    if (index < 0 || index >= m_tabs.size()) {
        return;
    }

    m_tabs[index].isSplitActive = active;
    m_tabs[index].secondaryUrl = active ? secondaryUrl : QUrl();
    if (!active) {
        m_tabs[index].isSecondaryFocused = false;
    }

    const QModelIndex modelIdx = this->index(index, 0);
    Q_EMIT dataChanged(modelIdx, modelIdx, {IsSplitActiveRole, SecondaryUrlRole, IsSecondaryFocusedRole, FormattedSecondaryPathRole});
    updateActiveState();
}

void ZenTabsModel::simulateFocusSecondary(int index, bool secondaryFocused)
{
    if (index < 0 || index >= m_tabs.size() || !m_tabs[index].isSplitActive) {
        return;
    }

    m_tabs[index].isSecondaryFocused = secondaryFocused;
    const QModelIndex modelIdx = this->index(index, 0);
    Q_EMIT dataChanged(modelIdx, modelIdx, {IsSecondaryFocusedRole});
    updateActiveState();
}

void ZenTabsModel::updateActiveState()
{
    ++m_revision;
    Q_EMIT activeTabIndexChanged();
    Q_EMIT activeUrlChanged();
    Q_EMIT stateChanged();
}
