/**
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * @file ZenSettingsWidget.cpp
 * @brief Implementation of embeddable QWidget hosting ZenPanel Kirigami settings.
 */

#include "ZenSettingsWidget.h"
#include "ZenPanelBridge.h"

#include <KLocalizedQmlContext>
#include <KLocalizedString>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickWidget>
#include <QVBoxLayout>

ZenSettingsWidget::ZenSettingsWidget(ZenPanelBridge *bridge, bool showCloseButton, QWidget *parent)
    : QWidget(parent)
    , m_bridge(bridge)
{
    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);

    m_quickWidget = new QQuickWidget(this);
    m_quickWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);

#ifdef ZENPANEL_LOCALE_DIR
    KLocalizedString::addDomainLocaleDir("zenpanel", QString::fromUtf8(ZENPANEL_LOCALE_DIR));
#elif defined(LOCAL_LOCALE_DIR)
    KLocalizedString::addDomainLocaleDir("zenpanel", QString::fromUtf8(LOCAL_LOCALE_DIR));
#endif

    // Register translation domain for KI18n lookups inside settings QML using official KF6 setup
    auto *localizedContext = KLocalization::setupLocalizedContext(m_quickWidget->engine());
    localizedContext->setTranslationDomain(QStringLiteral("zenpanel"));

    m_quickWidget->setInitialProperties({{QStringLiteral("bridge"), QVariant::fromValue(bridge)}, {QStringLiteral("showCloseButton"), showCloseButton}});

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

QSize ZenSettingsWidget::sizeHint() const
{
    return QSize(540, 600);
}

QSize ZenSettingsWidget::minimumSizeHint() const
{
    return QSize(400, 350);
}
