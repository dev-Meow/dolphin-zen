/**
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * @file ZenSettingsWidget.h
 * @brief Embeddable QWidget hosting the ZenPanel Kirigami settings view.
 *
 * Designed for dual-use:
 * 1. Embedded inside a standalone QDialog when opened from ZenPanel.
 * 2. Embedded as a category page (KPageWidgetItem) inside DolphinPreferencesDialog.
 */

#pragma once

#include <QPointer>
#include <QWidget>

class QQuickWidget;
class ZenPanelBridge;

/**
 * @class ZenSettingsWidget
 * @brief Reusable QWidget hosting the declarative Kirigami settings interface.
 */
class ZenSettingsWidget : public QWidget
{
    Q_OBJECT

public:
    explicit ZenSettingsWidget(ZenPanelBridge *bridge, bool showCloseButton = true, QWidget *parent = nullptr);
    ~ZenSettingsWidget() override = default;

    /**
     * @brief Recommended default size for embedding inside configuration dialogs.
     */
    QSize sizeHint() const override;

    /**
     * @brief Minimum viable size preventing layout collapse.
     */
    QSize minimumSizeHint() const override;

    /**
     * @brief Returns the underlying QQuickWidget rendering the settings QML component.
     */
    QQuickWidget *quickWidget() const;

Q_SIGNALS:
    /**
     * @brief Emitted when the user requests closing the settings view from the footer button.
     */
    void closeRequested();

private:
    QQuickWidget *m_quickWidget = nullptr;
    QPointer<ZenPanelBridge> m_bridge;
};
