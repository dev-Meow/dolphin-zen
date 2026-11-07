/*
 * SPDX-FileCopyrightText: 2026 Meow <meow@zenpanel.local>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "zendockpanel.h"

#include "dolphindockwidget.h"
#include "dolphinmainwindow.h"
#include "dolphintabwidget.h"
#include "dolphintabpage.h"
#include "dolphinviewcontainer.h"

#include "backend/ZenPanelBridge.h"
#include "backend/ZenPlacesMasterModel.h"
#include "backend/ZenNetworkPlacesModel.h"
#include "backend/ZenSectionFilterProxy.h"
#include "backend/ZenFolderTreeModel.h"
#include "backend/ZenTabsModel.h"
#include "zenpanelsettings.h"

#include <QVBoxLayout>
#include <QQuickWidget>
#include <QQmlEngine>
#include <QConcatenateTablesProxyModel>
#include <KLocalizedQmlContext>
#include <QLoggingCategory>
Q_LOGGING_CATEGORY(zenLog, "org.kde.dolphin.zenpanel")

void qml_register_types_org_kde_dolphin_zenpanel();

ZenDockPanel::ZenDockPanel(DolphinDockWidget *dock, DolphinMainWindow *mainWindow)
    : Panel(dock)
    , m_dock(dock)
    , m_mainWindow(mainWindow)
{
    qml_register_types_org_kde_dolphin_zenpanel();
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);

    m_quickWidget = new QQuickWidget(this);
    m_quickWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);
    connect(m_quickWidget, &QQuickWidget::statusChanged, this, [this](QQuickWidget::Status status) {
        if (status == QQuickWidget::Error) {
            for (const auto &err : m_quickWidget->errors()) {
                qCritical(zenLog) << "[ZenDockPanel QML Error]" << err.toString();
            }
        }
    });
    layout->addWidget(m_quickWidget);

    m_masterModel = new ZenPlacesMasterModel(this);
    m_networkPlacesModel = new ZenNetworkPlacesModel(this);

    auto *workspaceSourceModel = new QConcatenateTablesProxyModel(this);
    workspaceSourceModel->addSourceModel(m_masterModel);
    workspaceSourceModel->addSourceModel(m_networkPlacesModel);

    auto *devicesSourceModel = new QConcatenateTablesProxyModel(this);
    devicesSourceModel->addSourceModel(m_masterModel);
    devicesSourceModel->addSourceModel(m_networkPlacesModel);

    m_essentialsProxy = new ZenSectionFilterProxy(this);
    m_essentialsProxy->setSourceModel(m_masterModel);
    m_essentialsProxy->setSectionType(ZenSectionFilterProxy::Essentials);

    m_workspaceProxy = new ZenSectionFilterProxy(this);
    m_workspaceProxy->setSourceModel(workspaceSourceModel);
    m_workspaceProxy->setSectionType(ZenSectionFilterProxy::WorkspacePlaces);

    m_devicesProxy = new ZenSectionFilterProxy(this);
    m_devicesProxy->setSourceModel(devicesSourceModel);
    m_devicesProxy->setSectionType(ZenSectionFilterProxy::Devices);

    m_trashProxy = new ZenSectionFilterProxy(this);
    m_trashProxy->setSourceModel(m_masterModel);
    m_trashProxy->setSectionType(ZenSectionFilterProxy::Trash);

    m_tabsModel = new ZenTabsModel(this);
    m_treeModel = new ZenFolderTreeModel(this);

    m_bridge = new ZenPanelBridge(this);
    m_bridge->initModels(m_masterModel,
                         m_networkPlacesModel,
                         m_essentialsProxy,
                         m_workspaceProxy,
                         m_devicesProxy,
                         m_trashProxy,
                         m_tabsModel,
                         m_treeModel);

    if (m_dock) {
        auto updateOrientation = [this](Qt::DockWidgetArea area) {
            const bool isHorizontal = (area == Qt::TopDockWidgetArea || area == Qt::BottomDockWidgetArea);
            m_bridge->setPanelOrientation(isHorizontal ? Qt::Horizontal : Qt::Vertical);
        };
        connect(m_dock, &QDockWidget::dockLocationChanged, this, updateOrientation);
        updateOrientation(Qt::LeftDockWidgetArea);
    }

    // Connect bridge signals to panel signals
    connect(m_bridge, &ZenPanelBridge::urlActivated, this, &ZenDockPanel::placeActivated);
    connect(m_bridge, &ZenPanelBridge::urlInNewTabActivated, this, &ZenDockPanel::tabRequested);

    // Smart tab navigation from QML (switch to existing tab if already open)
    connect(m_tabsModel, &ZenTabsModel::tabActivated, this, [this](int index, bool focusSecondary) {
        if (m_tabWidget && index >= 0 && index < m_tabWidget->count()) {
            m_tabWidget->setCurrentIndex(index);
            if (focusSecondary) {
                m_tabWidget->focusInactiveSplitView();
            }
        }
    });

    KLocalization::setupLocalizedContext(m_quickWidget->engine());

    m_quickWidget->setInitialProperties({
        {QStringLiteral("bridge"), QVariant::fromValue(m_bridge)}
    });
    m_quickWidget->setSource(QUrl(QStringLiteral("qrc:/qt/qml/org/kde/dolphin/zenpanel/ui/ZenPanel.qml")));
}

ZenDockPanel::~ZenDockPanel() = default;

void ZenDockPanel::setTabWidget(DolphinTabWidget *tabWidget)
{
    if (m_tabWidget == tabWidget) {
        return;
    }

    if (m_tabWidget) {
        disconnect(m_tabWidget, nullptr, this, nullptr);
    }

    m_tabWidget = tabWidget;

    if (m_tabWidget) {
        connect(m_tabWidget, &DolphinTabWidget::activeViewChanged, this, &ZenDockPanel::slotSyncTabs);
        connect(m_tabWidget, &DolphinTabWidget::tabCountChanged, this, &ZenDockPanel::slotSyncTabs);
        connect(m_tabWidget, &DolphinTabWidget::currentUrlChanged, this, &ZenDockPanel::slotSyncTabs);
        slotSyncTabs();
    }
}

void ZenDockPanel::setUrl(const QUrl &url)
{
    Panel::setUrl(url);
    if (m_tabsModel) {
        m_tabsModel->setCurrentTabUrl(url);
    }
}

bool ZenDockPanel::urlChanged()
{
    if (m_tabsModel) {
        m_tabsModel->setCurrentTabUrl(url());
    }
    return true;
}

void ZenDockPanel::readSettings()
{
    Panel::readSettings();
    ZenPanelSettings::self()->load();
}

void ZenDockPanel::slotSyncTabs()
{
    if (!m_tabWidget || !m_tabsModel) {
        return;
    }

    QVector<ZenTabInfo> tabs;
    const int tabCount = m_tabWidget->count();
    const int currentIdx = m_tabWidget->currentIndex();

    for (int i = 0; i < tabCount; ++i) {
        DolphinTabPage *page = m_tabWidget->tabPageAt(i);
        if (!page) {
            continue;
        }

        ZenTabInfo info;
        info.index = i;
        info.title = m_tabWidget->tabText(i);
        info.primaryUrl = page->primaryViewContainer() ? page->primaryViewContainer()->url() : QUrl();
        info.isSplitActive = page->splitViewEnabled();
        info.secondaryUrl = (page->splitViewEnabled() && page->secondaryViewContainer())
                            ? page->secondaryViewContainer()->url() : QUrl();
        info.isCurrentTab = (i == currentIdx);
        info.isSecondaryFocused = page->splitViewEnabled() && !page->primaryViewActive();
        info.iconName = QStringLiteral("folder");
        tabs.append(info);
    }

    m_tabsModel->syncTabs(tabs);
}

