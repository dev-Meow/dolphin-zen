/**
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * @file zensettingspage.h
 * @brief Settings page for Zen Panel inside Dolphin's Configure dialog.
 */

#pragma once

#include "settings/settingspagebase.h"
#include <QPointer>

class ZenPanelBridge;
class ZenSettingsWidget;

/**
 * @class ZenSettingsPage
 * @brief Embeds the declarative Zen Panel settings view as a first-class page in DolphinSettingsDialog.
 */
class ZenSettingsPage : public SettingsPageBase
{
    Q_OBJECT

public:
    explicit ZenSettingsPage(ZenPanelBridge *bridge, QWidget *parent = nullptr);
    ~ZenSettingsPage() override = default;

    /**
     * @brief Persistently applies Zen Panel configuration.
     */
    void applySettings() override;

    /**
     * @brief Restores Zen Panel configuration to factory defaults.
     */
    void restoreDefaults() override;

private:
    QPointer<ZenPanelBridge> m_bridge;
    ZenSettingsWidget *m_widget = nullptr;
};
