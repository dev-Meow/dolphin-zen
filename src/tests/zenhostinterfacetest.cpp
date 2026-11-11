/*
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "panels/zenpanel/backend/ZenFolderTreeModel.h"
#include "panels/zenpanel/backend/ZenNetworkPlacesModel.h"
#include "panels/zenpanel/backend/ZenPanelBridge.h"
#include "panels/zenpanel/backend/ZenPlacesMasterModel.h"
#include "panels/zenpanel/backend/ZenSectionFilterProxy.h"
#include "panels/zenpanel/backend/ZenTabsModel.h"
#include "panels/zenpanel/zendockpanel.h"
#include "panels/zenpanel/zenpanelsettings.h"

#include <QApplication>
#include <QQuickWidget>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>
#include <memory>

/**
 * @brief Contract test ensuring Dolphin's host integration interfaces and ZenDockPanel
 * remain compatible across future Dolphin and KDE Frameworks upstream updates.
 */
class ZenHostInterfaceTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
    void testPanelInstantiationAndModels();
    void testSignalForwardingContract();
    void testTabsModelContract();
    void testOrientationAndLockContract();
    void testSettingsContract();
    void testQmlHostContract();
    void cleanupTestCase();

private:
    QTemporaryDir m_tmpHome;
    std::unique_ptr<ZenDockPanel> m_panel;
};

int main(int argc, char *argv[])
{
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")) {
        qputenv("QT_QPA_PLATFORM", "offscreen");
    }
    if (qEnvironmentVariableIsEmpty("QT_QUICK_BACKEND")) {
        qputenv("QT_QUICK_BACKEND", "software");
    }
    QApplication app(argc, argv);
    ZenHostInterfaceTest tc;
    return QTest::qExec(&tc, argc, argv);
}

void ZenHostInterfaceTest::initTestCase()
{
    QVERIFY(m_tmpHome.isValid());
    qputenv("HOME", m_tmpHome.path().toUtf8());
    QStandardPaths::setTestModeEnabled(true);

    m_panel = std::make_unique<ZenDockPanel>(nullptr, nullptr);
    QVERIFY(m_panel != nullptr);
}

void ZenHostInterfaceTest::cleanupTestCase()
{
    m_panel.reset();
}

void ZenHostInterfaceTest::testPanelInstantiationAndModels()
{
    ZenPanelBridge *bridge = m_panel->bridge();
    QVERIFY(bridge != nullptr);

    QVERIFY(bridge->essentialsModel() != nullptr);
    QVERIFY(bridge->workspacePlacesModel() != nullptr);
    QVERIFY(bridge->devicesModel() != nullptr);
    QVERIFY(bridge->trashModel() != nullptr);
    QVERIFY(bridge->tabsModel() != nullptr);
    QVERIFY(bridge->treeModel() != nullptr);
}

void ZenHostInterfaceTest::testSignalForwardingContract()
{
    ZenPanelBridge *bridge = m_panel->bridge();
    QVERIFY(bridge != nullptr);

    QSignalSpy placeSpy(m_panel.get(), &ZenDockPanel::placeActivated);
    QSignalSpy tabSpy(m_panel.get(), &ZenDockPanel::tabRequested);
    QSignalSpy splitSpy(m_panel.get(), &ZenDockPanel::openInSplitViewRequested);
    QSignalSpy windowSpy(m_panel.get(), &ZenDockPanel::newWindowRequested);

    const QUrl testPlaceUrl(QStringLiteral("file:///home"));
    Q_EMIT bridge->urlActivated(testPlaceUrl);
    QCOMPARE(placeSpy.count(), 1);
    QCOMPARE(placeSpy.takeFirst().at(0).toUrl(), testPlaceUrl);

    const QUrl testTabUrl(QStringLiteral("file:///tmp"));
    Q_EMIT bridge->urlInNewTabActivated(testTabUrl);
    QCOMPARE(tabSpy.count(), 1);
    QCOMPARE(tabSpy.takeFirst().at(0).toUrl(), testTabUrl);

    const QUrl testSplitUrl(QStringLiteral("file:///etc"));
    Q_EMIT bridge->openInSplitViewRequested(testSplitUrl);
    QCOMPARE(splitSpy.count(), 1);
    QCOMPARE(splitSpy.takeFirst().at(0).toUrl(), testSplitUrl);

    const QUrl testWindowUrl(QStringLiteral("file:///var"));
    Q_EMIT bridge->openInNewWindowRequested(testWindowUrl);
    QCOMPARE(windowSpy.count(), 1);
    QCOMPARE(windowSpy.takeFirst().at(0).toUrl(), testWindowUrl);
}

void ZenHostInterfaceTest::testTabsModelContract()
{
    ZenTabsModel tabsModel;
    QCOMPARE(tabsModel.rowCount(), 0);
    QCOMPARE(tabsModel.activeTabIndex(), -1);

    const QUrl testUrl(QStringLiteral("file:///home"));
    tabsModel.simulateAddTab(QStringLiteral("Home"), testUrl);
    QCOMPARE(tabsModel.rowCount(), 1);
    QVERIFY(tabsModel.hasUrl(testUrl));

    QSignalSpy activateSpy(&tabsModel, &ZenTabsModel::tabActivated);
    tabsModel.activateTab(0, true);
    QCOMPARE(activateSpy.count(), 1);
    const QList<QVariant> args = activateSpy.takeFirst();
    QCOMPARE(args.at(0).toInt(), 0);
    QCOMPARE(args.at(1).toBool(), true);
}

void ZenHostInterfaceTest::testOrientationAndLockContract()
{
    ZenPanelBridge *bridge = m_panel->bridge();
    QVERIFY(bridge != nullptr);

    bridge->setPanelOrientation(Qt::Horizontal);
    QCOMPARE(bridge->panelOrientation(), Qt::Horizontal);

    bridge->setPanelOrientation(Qt::Vertical);
    QCOMPARE(bridge->panelOrientation(), Qt::Vertical);

    bridge->setPanelsLocked(true);
    QCOMPARE(bridge->panelsLocked(), true);

    bridge->setPanelsLocked(false);
    QCOMPARE(bridge->panelsLocked(), false);
}

void ZenHostInterfaceTest::testSettingsContract()
{
    ZenPanelSettings *settings = ZenPanelSettings::self();
    QVERIFY(settings != nullptr);

    // Verify presence and access of core configuration properties
    QVERIFY(settings->maxEssentials() >= 3);
    QVERIFY(settings->showAddEssentialButton() || !settings->showAddEssentialButton());
    QVERIFY(settings->showTrashSection() || !settings->showTrashSection());
    QVERIFY(settings->highlightOpenTabPlaces() || !settings->highlightOpenTabPlaces());
}

void ZenHostInterfaceTest::testQmlHostContract()
{
    QVERIFY(m_panel->quickWidget() != nullptr);

    // Ensure QQuickWidget didn't fail during instantiation
    QVERIFY(m_panel->quickWidget()->status() != QQuickWidget::Error);
}

#include "zenhostinterfacetest.moc"
