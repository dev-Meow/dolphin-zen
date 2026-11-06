/**
 * SPDX-FileCopyrightText: 2026 Meow <meow@example.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * @file ZenSettingsWidget.cpp
 * @brief Implementation of embeddable QWidget hosting ZenPanel Kirigami settings.
 */

#include "ZenSettingsWidget.h"
#include "ZenPanelBridge.h"

#include <QVBoxLayout>
#include <QQuickWidget>
#include <QQmlEngine>
#include <QQmlContext>
#include <KLocalizedQmlContext>

ZenSettingsWidget::ZenSettingsWidget(ZenPanelBridge *bridge, bool showCloseButton, QWidget *parent)
    : QWidget(parent)
    , m_bridge(bridge)
{
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);

    m_quickWidget = new QQuickWidget(this);
    m_quickWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);

    // Register translation domain for KI18n lookups inside settings QML
    auto *context = new KLocalizedQmlContext(m_quickWidget->engine());
    context->setTranslationDomain(QStringLiteral("zenpanel"));
    m_quickWidget->engine()->rootContext()->setContextObject(context);

    m_quickWidget->setInitialProperties({
        {QStringLiteral("bridge"), QVariant::fromValue(bridge)},
        {QStringLiteral("showCloseButton"), showCloseButton}
    });

    m_quickWidget->setSource(QUrl(QStringLiteral("qrc:/qt/qml/org/kde/dolphin/zenpanel/ui/components/ZenSettingsDialog.qml")));

    layout->addWidget(m_quickWidget);

    if (m_bridge) {
        connect(m_bridge, &ZenPanelBridge::closeSettingsRequested, this, &ZenSettingsWidget::closeRequested);
    }
}

QQuickWidget *ZenSettingsWidget::quickWidget() const
{
    return m_quickWidget;
}

