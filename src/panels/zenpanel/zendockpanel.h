/*
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef ZENDOCKPANEL_H
#define ZENDOCKPANEL_H

#include "panels/panel.h"
#include <QPointer>
#include <QUrl>

class QQuickWidget;
class DolphinDockWidget;
class DolphinMainWindow;
class DolphinTabWidget;
class ZenPanelBridge;
class ZenPlacesMasterModel;
class ZenNetworkPlacesModel;
class ZenSectionFilterProxy;
class ZenTabsModel;
class ZenFolderTreeModel;

/**
 * @brief Embeds the declarative Zen Panel (Kirigami/QML) into Dolphin as a native dock widget panel.
 */
class ZenDockPanel : public Panel
{
    Q_OBJECT

public:
    explicit ZenDockPanel(DolphinDockWidget *dock, DolphinMainWindow *mainWindow);
    ~ZenDockPanel() override;

    /**
     * @brief Connects Dolphin's central tab widget to synchronize open tabs and split views.
     */
    void setTabWidget(DolphinTabWidget *tabWidget);

    /**
     * @brief Refreshes settings from KConfigXT and dolphinrc.
     */
    void readSettings() override;

    /**
     * @brief Moves keyboard focus cleanly into ZenPanel and activates keyboard focus navigation.
     */
    void focusPanel();

    /**
     * @brief Returns the active ZenPanel bridge instance for UI bindings and configuration.
     * @return ZenPanelBridge pointer, or nullptr if not initialized.
     */
    ZenPanelBridge *bridge() const
    {
        return m_bridge;
    }

    /**
     * @brief Returns the embedded QQuickWidget hosting the Kirigami user interface.
     * @return Pointer to internal QQuickWidget.
     */
    QQuickWidget *quickWidget() const
    {
        return m_quickWidget;
    }

public Q_SLOTS:
    /**
     * @brief Invoked when Dolphin's active folder URL changes.
     */
    void setUrl(const QUrl &url);

Q_SIGNALS:
    void placeActivated(const QUrl &url);
    void tabRequested(const QUrl &url);
    void activeTabRequested(const QUrl &url);
    void newWindowRequested(const QUrl &url);
    void openInSplitViewRequested(const QUrl &url);
    void errorMessage(const QString &error);

protected:
    bool urlChanged() override;
    void focusInEvent(QFocusEvent *event) override;

private Q_SLOTS:
    void slotSyncTabs();

private:
    DolphinDockWidget *m_dock = nullptr;
    DolphinMainWindow *m_mainWindow = nullptr;
    QPointer<DolphinTabWidget> m_tabWidget;

    QQuickWidget *m_quickWidget = nullptr;
    ZenPanelBridge *m_bridge = nullptr;
    ZenPlacesMasterModel *m_masterModel = nullptr;
    ZenNetworkPlacesModel *m_networkPlacesModel = nullptr;
    ZenSectionFilterProxy *m_essentialsProxy = nullptr;
    ZenSectionFilterProxy *m_workspaceProxy = nullptr;
    ZenSectionFilterProxy *m_devicesProxy = nullptr;
    ZenSectionFilterProxy *m_trashProxy = nullptr;
    ZenTabsModel *m_tabsModel = nullptr;
    ZenFolderTreeModel *m_treeModel = nullptr;
};

#endif // ZENDOCKPANEL_H
