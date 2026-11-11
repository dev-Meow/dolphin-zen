/**
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * @file zensettingspage.cpp
 * @brief Implementation of the Dolphin settings page for Zen Panel.
 */

#include "zensettingspage.h"
#include "panels/zenpanel/backend/ZenPanelBridge.h"
#include "panels/zenpanel/backend/ZenSettingsWidget.h"
#include "zenpanelsettings.h"

#include <QVBoxLayout>

ZenSettingsPage::ZenSettingsPage(ZenPanelBridge *bridge, QWidget *parent)
    : SettingsPageBase(parent)
    , m_bridge(bridge)
{
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);

    // Embed the Kirigami settings widget without standalone dialog close button
    m_widget = new ZenSettingsWidget(m_bridge, /*showCloseButton=*/false, this);
    layout->addWidget(m_widget);

    // Notify DolphinSettingsDialog to enable the Apply button when any property changes
    if (m_bridge) {
        connect(m_bridge, &ZenPanelBridge::maxEssentialsChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::showAddEssentialButtonChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::essentialsIconStyleChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::placesIconSizeSettingChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::lookFeelModeChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::defaultWorkspaceViewChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::highlightOpenTabPlacesChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::switchToExistingTabChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::hideEssentialsInWorkspaceChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::devicesPinnedChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::expandNetworkFolderChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::limitTreeToHomeChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::showHiddenFoldersInTreeChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::showTrashSectionChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::customSectionIconSizesChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::customSectionIconStylesChanged, this, &ZenSettingsPage::changed);
        connect(m_bridge, &ZenPanelBridge::globalIconStyleChanged, this, &ZenSettingsPage::changed);
    }
}

void ZenSettingsPage::applySettings()
{
    ZenPanelSettings::self()->save();
}

void ZenSettingsPage::restoreDefaults()
{
    ZenPanelSettings::self()->setDefaults();
    ZenPanelSettings::self()->save();
    if (m_bridge) {
        m_bridge->notifySettingsChanged();
    }
}

#include "moc_zensettingspage.cpp"
