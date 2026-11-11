/*
 * SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "ZenPanelBridge.h"
#include "ZenFolderTreeModel.h"
#include "ZenPlacesMasterModel.h"
#include "ZenSectionFilterProxy.h"
#include "ZenTabsModel.h"
#include "zenpanelsettings.h"

#include <QAction>
#include <QApplication>
#include <QClipboard>
#include <QConcatenateTablesProxyModel>
#include <QDialog>
#include <QDir>
#include <QDropEvent>
#include <QFileInfo>
#include <QFontMetrics>
#include <QLoggingCategory>
#include <QMenu>
#include <QMimeData>
#include <QStyle>
#include <QStyleOptionViewItem>
#include <QToolTip>
#include <QVBoxLayout>
#include <QWidget>

#include "ZenSettingsWidget.h"

#include <KBookmark>
#include <KConfig>
#include <KConfigGroup>
#include <KFileItemListProperties>
#include <KFilePlaceEditDialog>
#include <KIO/DeleteOrTrashJob>
#include <KIO/DropJob>
#include <KIO/Paste>
#include <KIO/PasteJob>
#include <KIO/RenameFileDialog>
#include <KIconLoader>
#include <KJobWidgets>
#include <KLazyLocalizedString>
#undef TRANSLATION_DOMAIN
#define TRANSLATION_DOMAIN "zenpanel"
#include <KLocalizedString>
#include <KPropertiesDialog>
#include <KProtocolManager>
#include <KSharedConfig>
#include <KUrlMimeData>

Q_DECLARE_LOGGING_CATEGORY(zenLog)

ZenPanelBridge::ZenPanelBridge(QObject *parent)
    : QObject(parent)
{
    if (qApp) {
        qApp->installEventFilter(this);
    }

    connect(ZenPanelSettings::self(), &ZenPanelSettings::LookFeelModeChanged, this, [this]() {
        Q_EMIT lookFeelModeChanged();
        Q_EMIT themeMetricsChanged();
    });
}

ZenPanelBridge::~ZenPanelBridge() = default;

bool ZenPanelBridge::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == qApp && event) {
        if (event->type() == QEvent::ApplicationPaletteChange || event->type() == QEvent::StyleChange || event->type() == QEvent::FontChange) {
            qCDebug(zenLog) << "Bridge: Live theme/font/style change detected, refreshing metrics";
            Q_EMIT themeMetricsChanged();
        }
    }
    return QObject::eventFilter(watched, event);
}

Qt::Orientation ZenPanelBridge::panelOrientation() const
{
    return m_panelOrientation;
}

void ZenPanelBridge::setPanelOrientation(Qt::Orientation orientation)
{
    if (m_panelOrientation != orientation) {
        m_panelOrientation = orientation;
        qCDebug(zenLog) << "Bridge: Orientation updated:" << (orientation == Qt::Horizontal ? "Horizontal" : "Vertical");
        if (orientation == Qt::Horizontal) {
            setDevicesPinned(true);
        }
        Q_EMIT panelOrientationChanged();
    }
}

bool ZenPanelBridge::devicesPinned() const
{
    return ZenPanelSettings::self()->devicesPinned();
}

void ZenPanelBridge::setDevicesPinned(bool pinned)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->devicesPinned() != pinned) {
        settings->setDevicesPinned(pinned);
        settings->save();
        qCDebug(zenLog) << "[Settings] DevicesPinned updated:" << pinned;
        Q_EMIT devicesPinnedChanged();
    }
}

bool ZenPanelBridge::expandNetworkFolder() const
{
    return ZenPanelSettings::self()->expandNetworkFolder();
}

void ZenPanelBridge::setExpandNetworkFolder(bool expand)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->expandNetworkFolder() != expand) {
        settings->setExpandNetworkFolder(expand);
        settings->save();
    }
    if (m_networkPlacesModel) {
        m_networkPlacesModel->setEnabled(expand);
    }
    if (m_devicesModel) {
        m_devicesModel->setExpandNetworkFolder(expand);
    }
    qCDebug(zenLog) << "[Settings] ExpandNetworkFolder updated:" << expand;
    Q_EMIT expandNetworkFolderChanged();
}

bool ZenPanelBridge::highlightOpenTabPlaces() const
{
    return ZenPanelSettings::self()->highlightOpenTabPlaces();
}

void ZenPanelBridge::setHighlightOpenTabPlaces(bool highlight)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->highlightOpenTabPlaces() != highlight) {
        settings->setHighlightOpenTabPlaces(highlight);
        settings->save();
        qCDebug(zenLog) << "[Settings] HighlightOpenTabPlaces updated:" << highlight;
        Q_EMIT highlightOpenTabPlacesChanged();
    }
}

bool ZenPanelBridge::switchToExistingTab() const
{
    return ZenPanelSettings::self()->switchToExistingTab();
}

void ZenPanelBridge::setSwitchToExistingTab(bool switchTab)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->switchToExistingTab() != switchTab) {
        settings->setSwitchToExistingTab(switchTab);
        settings->save();
        qCDebug(zenLog) << "[Settings] SwitchToExistingTab updated:" << switchTab;
        Q_EMIT switchToExistingTabChanged();
    }
}

bool ZenPanelBridge::hideEssentialsInWorkspace() const
{
    return ZenPanelSettings::self()->hideEssentialsInWorkspace();
}

void ZenPanelBridge::setHideEssentialsInWorkspace(bool hide)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->hideEssentialsInWorkspace() != hide) {
        settings->setHideEssentialsInWorkspace(hide);
        settings->save();
        if (m_workspacePlacesModel) {
            m_workspacePlacesModel->setHideEssentialsInWorkspace(hide);
        }
        qCDebug(zenLog) << "[Settings] HideEssentialsInWorkspace updated:" << hide;
        Q_EMIT hideEssentialsInWorkspaceChanged();
    }
}

int ZenPanelBridge::maxEssentials() const
{
    return ZenPanelSettings::self()->maxEssentials();
}

void ZenPanelBridge::setMaxEssentials(int max)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->maxEssentials() != max) {
        settings->setMaxEssentials(max);
        settings->save();
        qCDebug(zenLog) << "[Settings] MaxEssentials updated:" << max;
        Q_EMIT maxEssentialsChanged();
    }
}

bool ZenPanelBridge::showAddEssentialButton() const
{
    return ZenPanelSettings::self()->showAddEssentialButton();
}

void ZenPanelBridge::setShowAddEssentialButton(bool show)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->showAddEssentialButton() != show) {
        settings->setShowAddEssentialButton(show);
        settings->save();
        qCDebug(zenLog) << "[Settings] ShowAddEssentialButton updated:" << show;
        Q_EMIT showAddEssentialButtonChanged();
    }
}

int ZenPanelBridge::essentialsIconStyle() const
{
    return ZenPanelSettings::self()->essentialsIconStyle();
}

void ZenPanelBridge::setEssentialsIconStyle(int style)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->essentialsIconStyle() != style) {
        settings->setEssentialsIconStyle(style);
        settings->save();
        qCDebug(zenLog) << "[Settings] EssentialsIconStyle updated:" << style;
        Q_EMIT essentialsIconStyleChanged();
    }
}

int ZenPanelBridge::defaultWorkspaceView() const
{
    return ZenPanelSettings::self()->defaultWorkspaceView();
}

void ZenPanelBridge::setDefaultWorkspaceView(int viewIndex)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->defaultWorkspaceView() != viewIndex) {
        settings->setDefaultWorkspaceView(viewIndex);
        settings->save();
        qCDebug(zenLog) << "[Settings] DefaultWorkspaceView updated:" << viewIndex;
        Q_EMIT defaultWorkspaceViewChanged();
    }
}

bool ZenPanelBridge::limitTreeToHome() const
{
    return m_treeModel ? m_treeModel->limitToHome() : ZenPanelSettings::self()->limitTreeToHome();
}

void ZenPanelBridge::setLimitTreeToHome(bool limit)
{
    if (m_treeModel) {
        m_treeModel->setLimitToHome(limit);
    } else {
        ZenPanelSettings::self()->setLimitTreeToHome(limit);
        ZenPanelSettings::self()->save();
    }
    Q_EMIT limitTreeToHomeChanged();
}

bool ZenPanelBridge::showHiddenFoldersInTree() const
{
    return m_treeModel ? m_treeModel->showHiddenFiles() : ZenPanelSettings::self()->showHiddenFoldersInTree();
}

void ZenPanelBridge::setShowHiddenFoldersInTree(bool show)
{
    if (m_treeModel) {
        m_treeModel->setShowHiddenFiles(show);
    } else {
        ZenPanelSettings::self()->setShowHiddenFoldersInTree(show);
        ZenPanelSettings::self()->save();
    }
    Q_EMIT showHiddenFoldersInTreeChanged();
}

bool ZenPanelBridge::showTrashSection() const
{
    return ZenPanelSettings::self()->showTrashSection();
}

void ZenPanelBridge::setShowTrashSection(bool show)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->showTrashSection() != show) {
        settings->setShowTrashSection(show);
        settings->save();
        qCDebug(zenLog) << "[Settings] ShowTrashSection updated:" << show;
        Q_EMIT showTrashSectionChanged();
    }
}

int ZenPanelBridge::globalIconStyle() const
{
    return ZenPanelSettings::self()->globalIconStyle();
}

void ZenPanelBridge::setGlobalIconStyle(int style)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->globalIconStyle() != style) {
        settings->setGlobalIconStyle(style);
        settings->save();
        qCDebug(zenLog) << "[Settings] GlobalIconStyle updated:" << style;
        m_colorIconCache.clear();
        m_symbolicIconCache.clear();
        m_themeMetricsRevision++;
        Q_EMIT globalIconStyleChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::customEssentialsIconSize() const
{
    return ZenPanelSettings::self()->customEssentialsIconSize();
}

void ZenPanelBridge::setCustomEssentialsIconSize(int size)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->customEssentialsIconSize() != size) {
        settings->setCustomEssentialsIconSize(size);
        settings->save();
        qCDebug(zenLog) << "[Settings] CustomEssentialsIconSize updated:" << size;
        Q_EMIT customSectionIconSizesChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::customPlacesIconSize() const
{
    return ZenPanelSettings::self()->customPlacesIconSize();
}

void ZenPanelBridge::setCustomPlacesIconSize(int size)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->customPlacesIconSize() != size) {
        settings->setCustomPlacesIconSize(size);
        settings->save();
        qCDebug(zenLog) << "[Settings] CustomPlacesIconSize updated:" << size;
        Q_EMIT customSectionIconSizesChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::customDevicesIconSize() const
{
    return ZenPanelSettings::self()->customDevicesIconSize();
}

void ZenPanelBridge::setCustomDevicesIconSize(int size)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->customDevicesIconSize() != size) {
        settings->setCustomDevicesIconSize(size);
        settings->save();
        qCDebug(zenLog) << "[Settings] CustomDevicesIconSize updated:" << size;
        Q_EMIT customSectionIconSizesChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::customTreeIconSize() const
{
    return ZenPanelSettings::self()->customTreeIconSize();
}

void ZenPanelBridge::setCustomTreeIconSize(int size)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->customTreeIconSize() != size) {
        settings->setCustomTreeIconSize(size);
        settings->save();
        qCDebug(zenLog) << "[Settings] CustomTreeIconSize updated:" << size;
        m_themeMetricsRevision++;
        Q_EMIT customSectionIconSizesChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::customTrashIconSize() const
{
    return ZenPanelSettings::self()->customTrashIconSize();
}

void ZenPanelBridge::setCustomTrashIconSize(int size)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->customTrashIconSize() != size) {
        settings->setCustomTrashIconSize(size);
        settings->save();
        qCDebug(zenLog) << "[Settings] CustomTrashIconSize updated:" << size;
        m_themeMetricsRevision++;
        Q_EMIT customSectionIconSizesChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::themeMetricsRevision() const
{
    return m_themeMetricsRevision;
}

int ZenPanelBridge::customEssentialsIconStyle() const
{
    return ZenPanelSettings::self()->customEssentialsIconStyle();
}

void ZenPanelBridge::setCustomEssentialsIconStyle(int style)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->customEssentialsIconStyle() != style) {
        settings->setCustomEssentialsIconStyle(style);
        settings->save();
        qCDebug(zenLog) << "[Settings] CustomEssentialsIconStyle updated:" << style;
        m_themeMetricsRevision++;
        Q_EMIT customSectionIconStylesChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::customPlacesIconStyle() const
{
    return ZenPanelSettings::self()->customPlacesIconStyle();
}

void ZenPanelBridge::setCustomPlacesIconStyle(int style)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->customPlacesIconStyle() != style) {
        settings->setCustomPlacesIconStyle(style);
        settings->save();
        qCDebug(zenLog) << "[Settings] CustomPlacesIconStyle updated:" << style;
        m_themeMetricsRevision++;
        Q_EMIT customSectionIconStylesChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::customDevicesIconStyle() const
{
    return ZenPanelSettings::self()->customDevicesIconStyle();
}

void ZenPanelBridge::setCustomDevicesIconStyle(int style)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->customDevicesIconStyle() != style) {
        settings->setCustomDevicesIconStyle(style);
        settings->save();
        qCDebug(zenLog) << "[Settings] CustomDevicesIconStyle updated:" << style;
        m_themeMetricsRevision++;
        Q_EMIT customSectionIconStylesChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::customTreeIconStyle() const
{
    return ZenPanelSettings::self()->customTreeIconStyle();
}

void ZenPanelBridge::setCustomTreeIconStyle(int style)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->customTreeIconStyle() != style) {
        settings->setCustomTreeIconStyle(style);
        settings->save();
        qCDebug(zenLog) << "[Settings] CustomTreeIconStyle updated:" << style;
        m_themeMetricsRevision++;
        Q_EMIT customSectionIconStylesChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::customTrashIconStyle() const
{
    return ZenPanelSettings::self()->customTrashIconStyle();
}

void ZenPanelBridge::setCustomTrashIconStyle(int style)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->customTrashIconStyle() != style) {
        settings->setCustomTrashIconStyle(style);
        settings->save();
        qCDebug(zenLog) << "[Settings] CustomTrashIconStyle updated:" << style;
        m_themeMetricsRevision++;
        Q_EMIT customSectionIconStylesChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::sectionIconSize(const QString &section) const
{
    if (section == QLatin1String("essentials")) {
        return essentialsIconSize();
    } else if (section == QLatin1String("places")) {
        return placesIconSize();
    } else if (section == QLatin1String("devices")) {
        return devicesIconSize();
    } else if (section == QLatin1String("tree")) {
        return treeIconSize();
    } else if (section == QLatin1String("trash")) {
        return trashIconSize();
    }
    return 22;
}

int ZenPanelBridge::effectiveSectionIconStyle(const QString &section) const
{
    int overrideStyle = 0;
    if (section == QLatin1String("essentials")) {
        overrideStyle = customEssentialsIconStyle();
    } else if (section == QLatin1String("places")) {
        overrideStyle = customPlacesIconStyle();
    } else if (section == QLatin1String("devices")) {
        overrideStyle = customDevicesIconStyle();
    } else if (section == QLatin1String("tree")) {
        overrideStyle = customTreeIconStyle();
    } else if (section == QLatin1String("trash")) {
        overrideStyle = customTrashIconStyle();
    }

    // overrideStyle: 0 = Follow Global, 1 = Theme Default, 2 = Color, 3 = Monochrome
    if (overrideStyle == 1) {
        return 0; // Theme Default
    }
    if (overrideStyle == 2) {
        return 1; // Color
    }
    if (overrideStyle == 3) {
        return 2; // Monochrome
    }

    // Follow Global Setting: 0 = Theme Default, 1 = Color, 2 = Monochrome
    return globalIconStyle();
}

bool ZenPanelBridge::isSectionMonochrome(const QString &section) const
{
    const int style = effectiveSectionIconStyle(section);
    if (style == 2) {
        return true; // Monochrome forced
    }
    if (style == 1) {
        return false; // Color forced
    }
    // Style 0 (Theme default): at <= SizeSmallMedium (22px) Breeze uses monochrome outline
    return sectionIconSize(section) <= KIconLoader::SizeSmallMedium;
}

QVariant ZenPanelBridge::resolveSectionIcon(const QVariant &baseIcon, const QString &section) const
{
    if (baseIcon.isNull() || !baseIcon.isValid()) {
        return QStringLiteral("folder");
    }

    QString name;
    if (baseIcon.canConvert<QString>()) {
        name = baseIcon.toString();
    }
    if (name.isEmpty() && baseIcon.canConvert<QIcon>()) {
        name = baseIcon.value<QIcon>().name();
    }
    if (name.isEmpty()) {
        return baseIcon;
    }

    // If it's already an absolute file path or URL, return directly
    if (name.startsWith(QLatin1Char('/')) || name.startsWith(QLatin1String("file:"))) {
        return name;
    }

    // Strip "-symbolic" to get clean base name
    QString cleanName = name;
    if (cleanName.endsWith(QLatin1String("-symbolic"))) {
        cleanName.chop(9);
    }

    const int style = effectiveSectionIconStyle(section);

    if (style == 2) {
        // --- 2 = Monochrom / Schematisch (immer Kontur) ---
        auto it = m_symbolicIconCache.constFind(cleanName);
        if (it != m_symbolicIconCache.constEnd()) {
            return *it;
        }

        QString resolved = cleanName;
        const QString symbolicName = cleanName + QStringLiteral("-symbolic");
        if (QIcon::hasThemeIcon(symbolicName)) {
            resolved = symbolicName;
        }
        m_symbolicIconCache.insert(cleanName, resolved);
        return resolved;
    }

    if (style == 1) {
        // --- 1 = Full color (immer bunt) ---
        // If cleanName has no icon in the theme, but the original name does (e.g. folder-saved-search-symbolic),
        // preserve the original name so Qt's theme engine does not fall back to generic "folder"
        QString target = cleanName;
        if (!QIcon::hasThemeIcon(target) && QIcon::hasThemeIcon(name)) {
            target = name;
        }

        // When visual size is <= KIconLoader::SizeSmallMedium (22px), themes such as Breeze serve
        // monochrome outline icons. Load the colorful SizeMedium (32px) version via KIconLoader
        // so that Kirigami scales down the full-color pixmap.
        const int visualSize = sectionIconSize(section);
        if (visualSize <= KIconLoader::SizeSmallMedium) {
            auto it = m_colorIconCache.constFind(target);
            if (it != m_colorIconCache.constEnd()) {
                return QVariant::fromValue(*it);
            }

            if (KIconLoader::global()) {
                const QPixmap px = KIconLoader::global()->loadIcon(target, KIconLoader::NoGroup, KIconLoader::SizeMedium);
                if (!px.isNull()) {
                    const QIcon colorIcon(px);
                    m_colorIconCache.insert(target, colorIcon);
                    return QVariant::fromValue(colorIcon);
                }
            }
        }
        return target;
    }

    // --- 0 = KDE default (Theme uses color from 32px, monochrome outline below) ---
    return cleanName;
}

bool ZenPanelBridge::isSectionIconMask(const QVariant &baseIcon, const QString &section) const
{
    const int style = effectiveSectionIconStyle(section);
    if (style == 2) {
        return true; // Monochrom always masked for theme color tinting
    }
    if (style == 1) {
        return false; // Full color never masked
    }
    // Style 0 (Theme default): only mask if the icon is explicitly a symbolic icon
    QString name;
    if (baseIcon.canConvert<QString>()) {
        name = baseIcon.toString();
    } else if (baseIcon.canConvert<QIcon>()) {
        name = baseIcon.value<QIcon>().name();
    }
    return name.endsWith(QLatin1String("-symbolic"));
}

QString ZenPanelBridge::resolveIconName(const QVariant &baseIcon) const
{
    return resolveSectionIcon(baseIcon, QString()).toString();
}

QVariant ZenPanelBridge::resolveIcon(const QVariant &baseIcon) const
{
    return resolveSectionIcon(baseIcon, QString());
}

int ZenPanelBridge::lookFeelMode() const
{
    return ZenPanelSettings::self()->lookFeelMode();
}

void ZenPanelBridge::setLookFeelMode(int mode)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->lookFeelMode() != mode) {
        settings->setLookFeelMode(mode);
        settings->save();
        qCDebug(zenLog) << "[Settings] LookFeelMode updated:" << mode;
        m_colorIconCache.clear();
        m_symbolicIconCache.clear();
        m_themeMetricsRevision++;
        Q_EMIT lookFeelModeChanged();
        Q_EMIT themeMetricsChanged();
    }
}

bool ZenPanelBridge::isDolphinStyle() const
{
    return lookFeelMode() == ZenPanelSettings::EnumLookFeelMode::DolphinCompact;
}

int ZenPanelBridge::placesIconSizeSetting() const
{
    const int custom = ZenPanelSettings::self()->customDolphinIconSize();
    if (custom > 0) {
        return custom;
    }
    KSharedConfig::Ptr dolphinConfig = KSharedConfig::openConfig(QStringLiteral("dolphinrc"));
    KConfigGroup placesGroup(dolphinConfig, QStringLiteral("PlacesPanel"));
    return placesGroup.readEntry(QStringLiteral("IconSize"), -1);
}

void ZenPanelBridge::setPlacesIconSizeSetting(int size)
{
    if (placesIconSizeSetting() != size) {
        auto *settings = ZenPanelSettings::self();
        settings->setCustomDolphinIconSize(size);
        settings->save();

        // Sync directly to dolphinrc so Dolphin places panel matches
        KSharedConfig::Ptr dolphinConfig = KSharedConfig::openConfig(QStringLiteral("dolphinrc"));
        KConfigGroup placesGroup(dolphinConfig, QStringLiteral("PlacesPanel"));
        if (size <= 0) {
            placesGroup.deleteEntry(QStringLiteral("IconSize"));
        } else {
            placesGroup.writeEntry(QStringLiteral("IconSize"), size);
        }
        dolphinConfig->sync();

        qCDebug(zenLog) << "[Settings] PlacesIconSizeSetting updated:" << size;
        m_colorIconCache.clear();
        m_symbolicIconCache.clear();
        m_themeMetricsRevision++;
        Q_EMIT placesIconSizeSettingChanged();
        Q_EMIT themeMetricsChanged();
    }
}

int ZenPanelBridge::iconSize() const
{
    if (isDolphinStyle()) {
        const int custom = ZenPanelSettings::self()->customDolphinIconSize();
        if (custom > 0) {
            return custom;
        }
        // Read directly from dolphinrc if configured by the user
        KSharedConfig::Ptr dolphinConfig = KSharedConfig::openConfig(QStringLiteral("dolphinrc"));
        KConfigGroup placesGroup(dolphinConfig, QStringLiteral("PlacesPanel"));
        int sz = placesGroup.readEntry(QStringLiteral("IconSize"), -1);
        if (sz <= 0) {
            KConfigGroup fileDialogGroup(dolphinConfig, QStringLiteral("KFileDialog Settings"));
            sz = fileDialogGroup.readEntry(QStringLiteral("Places Icons Static Size"), -1);
        }
        if (sz <= 0 && KIconLoader::global()) {
            sz = KIconLoader::global()->currentSize(KIconLoader::Panel);
        }
        return (sz > 0) ? sz : KIconLoader::SizeSmallMedium;
    }

    const int custom = ZenPanelSettings::self()->customKirigamiIconSize();
    return (custom > 0) ? custom : KIconLoader::SizeSmallMedium;
}

int ZenPanelBridge::globalIconSize() const
{
    const int configured = placesIconSizeSetting();
    if (configured > 0) {
        return configured;
    }
    return iconSize();
}

int ZenPanelBridge::placesIconSize() const
{
    const int custom = customPlacesIconSize();
    return (custom > 0) ? custom : globalIconSize();
}

int ZenPanelBridge::essentialsIconSize() const
{
    const int custom = customEssentialsIconSize();
    return (custom > 0) ? custom : qMax(globalIconSize(), 22);
}

int ZenPanelBridge::devicesIconSize() const
{
    const int custom = customDevicesIconSize();
    return (custom > 0) ? custom : globalIconSize();
}

int ZenPanelBridge::treeIconSize() const
{
    const int custom = customTreeIconSize();
    if (custom > 0) {
        return custom;
    }
    if (isDolphinStyle() && placesIconSizeSetting() <= 0) {
        return KIconLoader::SizeSmall;
    }
    return globalIconSize();
}

int ZenPanelBridge::trashIconSize() const
{
    const int custom = customTrashIconSize();
    return (custom > 0) ? custom : globalIconSize();
}

bool ZenPanelBridge::panelsLocked() const
{
    return m_panelsLocked;
}

void ZenPanelBridge::setPanelsLocked(bool locked)
{
    if (m_panelsLocked != locked) {
        m_panelsLocked = locked;
        qCDebug(zenLog) << "[ZenPanelBridge] panelsLocked updated:" << locked;
        Q_EMIT panelsLockedChanged();
    }
}

int ZenPanelBridge::devicesSectionHeight() const
{
    return ZenPanelSettings::self()->devicesSectionHeight();
}

void ZenPanelBridge::setDevicesSectionHeight(int height)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->devicesSectionHeight() != height) {
        settings->setDevicesSectionHeight(height);
        Q_EMIT sectionSizesChanged();
    }
}

int ZenPanelBridge::horizontalEssentialsWidth() const
{
    return ZenPanelSettings::self()->horizontalEssentialsWidth();
}

void ZenPanelBridge::setHorizontalEssentialsWidth(int width)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->horizontalEssentialsWidth() != width) {
        settings->setHorizontalEssentialsWidth(width);
        Q_EMIT sectionSizesChanged();
    }
}

int ZenPanelBridge::horizontalDevicesWidth() const
{
    return ZenPanelSettings::self()->horizontalDevicesWidth();
}

void ZenPanelBridge::setHorizontalDevicesWidth(int width)
{
    auto *settings = ZenPanelSettings::self();
    if (settings->horizontalDevicesWidth() != width) {
        settings->setHorizontalDevicesWidth(width);
        Q_EMIT sectionSizesChanged();
    }
}

void ZenPanelBridge::saveSectionSizes()
{
    ZenPanelSettings::self()->save();
    qCDebug(zenLog) << "[Settings] Section sizes persisted to config";
}

int ZenPanelBridge::placesRowHeight() const
{
    const int sz = placesIconSize();
    if (isDolphinStyle()) {
        const int custom = ZenPanelSettings::self()->customDolphinRowHeight();
        if (custom > 0 && placesIconSizeSetting() <= 0 && customPlacesIconSize() <= 0) {
            return custom;
        }
        QStyleOptionViewItem opt;
        opt.features |= QStyleOptionViewItem::HasDecoration;
        opt.decorationSize = QSize(sz, sz);
        if (QApplication::style()) {
            const int styleHeight = QApplication::style()->sizeFromContents(QStyle::CT_ItemViewItem, &opt, QSize(), nullptr).height();
            if (styleHeight > 0) {
                return styleHeight;
            }
        }
        return qMax(sz + 6, 28);
    }

    const int custom = ZenPanelSettings::self()->customKirigamiRowHeight();
    if (custom > 0 && placesIconSizeSetting() <= 0 && customPlacesIconSize() <= 0) {
        return custom;
    }
    const int fontHeight = QFontMetrics(QApplication::font()).height();
    return qMax(sz + 12, qRound(fontHeight * 2.0));
}

int ZenPanelBridge::devicesRowHeight() const
{
    const int sz = devicesIconSize();
    if (isDolphinStyle()) {
        QStyleOptionViewItem opt;
        opt.features |= QStyleOptionViewItem::HasDecoration;
        opt.decorationSize = QSize(sz, sz);
        if (QApplication::style()) {
            const int styleHeight = QApplication::style()->sizeFromContents(QStyle::CT_ItemViewItem, &opt, QSize(), nullptr).height();
            if (styleHeight > 0) {
                return styleHeight;
            }
        }
        return qMax(sz + 6, 28);
    }

    const int fontHeight = QFontMetrics(QApplication::font()).height();
    return qMax(sz + 12, qRound(fontHeight * 2.0));
}

int ZenPanelBridge::treeRowHeight() const
{
    if (isDolphinStyle()) {
        return placesRowHeight();
    }
    const int sz = treeIconSize();
    const int fontHeight = QFontMetrics(QApplication::font()).height();
    return qMax(sz + 8, qMax(28, qRound(fontHeight * 1.7)));
}

int ZenPanelBridge::itemRowHeight() const
{
    return placesRowHeight();
}

int ZenPanelBridge::essentialsTileWidth() const
{
    return qMax(essentialsIconSize() + 24, 48);
}

int ZenPanelBridge::essentialsTileHeight() const
{
    return qMax(essentialsIconSize() + 16, 40);
}

int ZenPanelBridge::lateralMargin() const
{
    if (isDolphinStyle()) {
        return ZenPanelSettings::self()->customDolphinLateralMargin(); // default: 4px
    }
    const int custom = ZenPanelSettings::self()->customKirigamiLateralMargin();
    return (custom >= 0) ? custom : 8;
}

int ZenPanelBridge::itemRadius() const
{
    if (isDolphinStyle()) {
        return ZenPanelSettings::self()->customDolphinCornerRadius(); // default: 3px (Breeze)
    }
    const int custom = ZenPanelSettings::self()->customKirigamiCornerRadius();
    return (custom >= 0) ? custom : 6;
}

void ZenPanelBridge::requestOpenSettings()
{
    if (receivers(SIGNAL(openSettingsRequested())) > 0) {
        Q_EMIT openSettingsRequested();
    } else {
        openSettingsDialog();
    }
}

void ZenPanelBridge::openSettingsDialog()
{
    if (m_settingsDialog) {
        m_settingsDialog->show();
        m_settingsDialog->raise();
        m_settingsDialog->activateWindow();
        return;
    }

    QWidget *parentWidget = qobject_cast<QWidget *>(parent());
    QWidget *topLevel = parentWidget ? parentWidget->window() : QApplication::activeWindow();

    auto *dialog = new QDialog(topLevel);
    dialog->setWindowTitle(i18nc("@title:window", "Configure ZenPanel"));
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    dialog->resize(560, 680);
    dialog->setMinimumSize(460, 480);

    auto *layout = new QVBoxLayout(dialog);
    layout->setContentsMargins(0, 0, 0, 0);

    auto *settingsWidget = new ZenSettingsWidget(this, /*showCloseButton=*/true, dialog);
    layout->addWidget(settingsWidget);

    connect(settingsWidget, &ZenSettingsWidget::closeRequested, dialog, &QDialog::accept);

    m_settingsDialog = dialog;
    dialog->show();
}

void ZenPanelBridge::closeSettingsDialog()
{
    Q_EMIT closeSettingsRequested();
    if (m_settingsDialog) {
        m_settingsDialog->close();
    }
}

bool ZenPanelBridge::keyboardNavigationActive() const
{
    return m_keyboardNavigationActive;
}

void ZenPanelBridge::setKeyboardNavigationActive(bool active)
{
    if (m_keyboardNavigationActive != active) {
        m_keyboardNavigationActive = active;
        Q_EMIT keyboardNavigationActiveChanged();
    }
}

bool ZenPanelBridge::touchInteractionActive() const
{
    return m_touchInteractionActive;
}

void ZenPanelBridge::setTouchInteractionActive(bool active)
{
    if (m_touchInteractionActive != active) {
        m_touchInteractionActive = active;
        Q_EMIT touchInteractionActiveChanged();
    }
}

QString ZenPanelBridge::activeSection() const
{
    return m_activeSection;
}

void ZenPanelBridge::setActiveSection(const QString &section)
{
    if (!section.isEmpty() && m_activeSection != section) {
        m_activeSection = section;
        Q_EMIT activeSectionChanged();
    }
}

QString ZenPanelBridge::focusedItemDescription() const
{
    return m_focusedItemDescription;
}

void ZenPanelBridge::setFocusedItemDescription(const QString &desc)
{
    if (m_focusedItemDescription != desc) {
        m_focusedItemDescription = desc;
        Q_EMIT focusedItemDescriptionChanged();
    }
}

void ZenPanelBridge::notifyMouseInteraction(const QString &section)
{
    if (m_keyboardNavigationActive || m_touchInteractionActive) {
        m_keyboardNavigationActive = false;
        m_touchInteractionActive = false;
        Q_EMIT keyboardNavigationActiveChanged();
        Q_EMIT touchInteractionActiveChanged();
    }
    if (!section.isEmpty()) {
        setActiveSection(section);
    }
}

void ZenPanelBridge::notifyMouseHoverSection(const QString &section)
{
    if (m_keyboardNavigationActive || m_touchInteractionActive) {
        m_keyboardNavigationActive = false;
        m_touchInteractionActive = false;
        Q_EMIT keyboardNavigationActiveChanged();
        Q_EMIT touchInteractionActiveChanged();
    }
    if (!section.isEmpty()) {
        setActiveSection(section);
    }
}

void ZenPanelBridge::notifyKeyboardInteraction()
{
    if (!m_keyboardNavigationActive) {
        m_keyboardNavigationActive = true;
        m_touchInteractionActive = false;
        Q_EMIT keyboardNavigationActiveChanged();
        Q_EMIT touchInteractionActiveChanged();
    }
}

void ZenPanelBridge::notifyTouchInteraction(const QString &section)
{
    if (m_keyboardNavigationActive || !m_touchInteractionActive) {
        m_keyboardNavigationActive = false;
        m_touchInteractionActive = true;
        Q_EMIT keyboardNavigationActiveChanged();
        Q_EMIT touchInteractionActiveChanged();
    }
    if (!section.isEmpty()) {
        setActiveSection(section);
    }
}

int ZenPanelBridge::wheelScrollLines() const
{
    const int lines = QApplication::wheelScrollLines();
    return lines > 0 ? lines : 3;
}

double ZenPanelBridge::wheelScrollSpeedModifier() const
{
    const double mod = ZenPanelSettings::self()->wheelScrollSpeedModifier();
    return mod > 0.05 ? mod : 1.0;
}

QString ZenPanelBridge::lastErrorMessage() const
{
    return m_lastErrorMessage;
}

void ZenPanelBridge::clearErrorMessage()
{
    if (!m_lastErrorMessage.isEmpty()) {
        m_lastErrorMessage.clear();
        Q_EMIT lastErrorMessageChanged();
    }
}

void ZenPanelBridge::reportError(const QString &message)
{
    if (message.isEmpty()) {
        return;
    }
    qCWarning(zenLog) << "[ZenPanel Error]" << message;
    if (m_lastErrorMessage != message) {
        m_lastErrorMessage = message;
        Q_EMIT lastErrorMessageChanged();
    }
}

ZenSectionFilterProxy *ZenPanelBridge::essentialsModel() const
{
    return m_essentialsModel;
}

ZenSectionFilterProxy *ZenPanelBridge::workspacePlacesModel() const
{
    return m_workspacePlacesModel;
}

ZenSectionFilterProxy *ZenPanelBridge::devicesModel() const
{
    return m_devicesModel;
}

ZenSectionFilterProxy *ZenPanelBridge::trashModel() const
{
    return m_trashModel;
}

ZenTabsModel *ZenPanelBridge::tabsModel() const
{
    return m_tabsModel;
}

ZenFolderTreeModel *ZenPanelBridge::treeModel() const
{
    return m_treeModel;
}

void ZenPanelBridge::initModels(ZenPlacesMasterModel *masterModel,
                                ZenNetworkPlacesModel *networkPlacesModel,
                                ZenSectionFilterProxy *essentialsProxy,
                                ZenSectionFilterProxy *workspaceProxy,
                                ZenSectionFilterProxy *devicesProxy,
                                ZenSectionFilterProxy *trashProxy,
                                ZenTabsModel *tabsModel,
                                ZenFolderTreeModel *treeModel)
{
    m_masterModel = masterModel;
    m_networkPlacesModel = networkPlacesModel;
    m_essentialsModel = essentialsProxy;
    m_workspacePlacesModel = workspaceProxy;
    m_devicesModel = devicesProxy;
    m_trashModel = trashProxy;
    m_tabsModel = tabsModel;
    m_treeModel = treeModel;

    const bool expandNet = ZenPanelSettings::self()->expandNetworkFolder();
    if (m_networkPlacesModel) {
        m_networkPlacesModel->setEnabled(expandNet);
    }
    if (m_devicesModel) {
        m_devicesModel->setExpandNetworkFolder(expandNet);
        m_devicesModel->sort(0, Qt::AscendingOrder);
    }
    if (m_essentialsModel) {
        m_essentialsModel->sort(0, Qt::AscendingOrder);
    }
    const bool hideEss = ZenPanelSettings::self()->hideEssentialsInWorkspace();
    if (m_workspacePlacesModel) {
        m_workspacePlacesModel->setHideEssentialsInWorkspace(hideEss);
    }

    if (m_masterModel) {
        // Forward Solid / KIO places errors directly to the InlineMessage banner
        connect(m_masterModel, &KFilePlacesModel::errorMessage, this, &ZenPanelBridge::reportError);

        // Handle delayed navigation or file drop after an unmounted storage device finishes mounting
        connect(m_masterModel, &KFilePlacesModel::setupDone, this, [this](const QModelIndex &index, bool success) {
            if (m_pendingSetupClickIndex.isValid() && m_pendingSetupClickIndex == index) {
                const bool inNewTab = m_pendingSetupNewTab;
                m_pendingSetupClickIndex = QPersistentModelIndex();
                m_pendingSetupNewTab = false;

                if (success) {
                    const QUrl mountedUrl = KFilePlacesModel::convertedUrl(m_masterModel->url(index));
                    if (inNewTab) {
                        openUrlInNewTab(mountedUrl);
                    } else {
                        openUrl(mountedUrl);
                    }
                }
            }

            if (m_pendingSetupDropIndex.isValid() && m_pendingSetupDropIndex == index) {
                const QList<QUrl> urls = m_pendingDropUrls;
                const QPoint pos = m_pendingDropGlobalPos;
                m_pendingSetupDropIndex = QPersistentModelIndex();
                m_pendingDropUrls.clear();

                if (success && !urls.isEmpty()) {
                    const QUrl mountedUrl = KFilePlacesModel::convertedUrl(m_masterModel->url(index));
                    executeDropOnUrl(mountedUrl, urls, pos);
                }
            }
        });
    }
}

QModelIndex ZenPanelBridge::resolveMasterSourceIndex(QAbstractItemModel *proxyModel, int proxyRow) const
{
    if (!proxyModel || !m_masterModel || proxyRow < 0 || proxyRow >= proxyModel->rowCount()) {
        return {};
    }

    QModelIndex idx = proxyModel->index(proxyRow, 0);
    while (idx.isValid() && idx.model() != m_masterModel) {
        if (const auto *sortProxy = qobject_cast<const QSortFilterProxyModel *>(idx.model())) {
            idx = sortProxy->mapToSource(idx);
        } else if (const auto *concatProxy = qobject_cast<const QConcatenateTablesProxyModel *>(idx.model())) {
            idx = concatProxy->mapToSource(idx);
        } else {
            return {};
        }
    }
    return (idx.isValid() && idx.model() == m_masterModel) ? idx : QModelIndex();
}

bool ZenPanelBridge::moveWorkspacePlace(int fromProxyRow, int toProxyRow, bool dropAfter)
{
    if (!m_workspacePlacesModel || !m_masterModel) {
        return false;
    }

    const int proxyCount = m_workspacePlacesModel->rowCount();
    if (fromProxyRow < 0 || fromProxyRow >= proxyCount || toProxyRow < 0 || toProxyRow >= proxyCount) {
        qCWarning(zenLog) << "moveWorkspacePlace: Index out of range:" << fromProxyRow << "->" << toProxyRow << "(count:" << proxyCount << ")";
        return false;
    }

    if (fromProxyRow == toProxyRow) {
        return true;
    }

    if ((!dropAfter && fromProxyRow + 1 == toProxyRow) || (dropAfter && fromProxyRow - 1 == toProxyRow)) {
        return true;
    }

    const QModelIndex sourceFromIdx = resolveMasterSourceIndex(m_workspacePlacesModel, fromProxyRow);
    const QModelIndex sourceToIdx = resolveMasterSourceIndex(m_workspacePlacesModel, toProxyRow);

    if (!sourceFromIdx.isValid() || !sourceToIdx.isValid()) {
        qCWarning(zenLog) << "moveWorkspacePlace: Invalid source index mapping for proxy rows:" << fromProxyRow << "->" << toProxyRow;
        return false;
    }

    const int fromMasterRow = sourceFromIdx.row();
    const int toMasterRow = sourceToIdx.row();

    int targetMasterRow = toMasterRow;
    if (dropAfter) {
        targetMasterRow = toMasterRow + 1;
    }

    if (fromMasterRow == targetMasterRow) {
        return true;
    }

    qCDebug(zenLog) << "[Action: moveWorkspacePlace] Moving place from proxy" << fromProxyRow << "(master:" << fromMasterRow << ") to proxy" << toProxyRow
                    << "(master:" << targetMasterRow << ", dropAfter:" << dropAfter << ")";

    const bool moved = m_masterModel->movePlace(fromMasterRow, targetMasterRow);
    if (moved) {
        // KFilePlacesModel::movePlace reorders DOM nodes in-memory but does not persist to disk.
        // Explicitly calling refresh() writes user-places.xbel and broadcasts DBus change notifications
        // so parallel Dolphin windows update immediately.
        m_masterModel->refresh();
    } else {
        qCWarning(zenLog) << "moveWorkspacePlace: KFilePlacesModel::movePlace failed for" << fromMasterRow << "->" << targetMasterRow;
    }

    return moved;
}

bool ZenPanelBridge::moveEssential(int fromProxyRow, int toProxyRow)
{
    if (!m_essentialsModel || !m_masterModel) {
        return false;
    }

    const int count = m_essentialsModel->rowCount();
    if (fromProxyRow < 0 || fromProxyRow >= count || toProxyRow < 0 || toProxyRow >= count || fromProxyRow == toProxyRow) {
        return false;
    }

    QStringList currentKeys;
    currentKeys.reserve(count);
    for (int i = 0; i < count; ++i) {
        const QModelIndex proxyIdx = m_essentialsModel->index(i, 0);
        const QModelIndex srcIdx = m_essentialsModel->mapToSource(proxyIdx);
        currentKeys.append(m_masterModel->placeKey(srcIdx));
    }

    currentKeys.move(fromProxyRow, toProxyRow);

    KConfigGroup orderGroup = KSharedConfig::openConfig()->group(QStringLiteral("ZenPanelEssentialsOrder"));
    orderGroup.writeEntry(QStringLiteral("Order"), currentKeys);
    orderGroup.sync();

    m_essentialsModel->invalidate();
    m_essentialsModel->sort(0, Qt::AscendingOrder);

    qCDebug(zenLog) << "[Action: moveEssential] Moved essential from proxy" << fromProxyRow << "to" << toProxyRow;
    return true;
}

bool ZenPanelBridge::addPlaceFromUrl(const QUrl &url, int targetProxyRow, bool dropAfter)
{
    if (!m_masterModel || !url.isValid()) {
        return false;
    }

    if (url.isLocalFile()) {
        const QFileInfo fi(url.toLocalFile());
        if (!fi.exists() || !fi.isDir()) {
            qCWarning(zenLog) << "addPlaceFromUrl: URL is not an existing directory:" << url;
            return false;
        }
    }

    const bool added = m_masterModel->addUrlToWorkspacePlaces(url);
    if (!added) {
        qCWarning(zenLog) << "addPlaceFromUrl: Failed to add URL to workspace places:" << url;
        return false;
    }

    if (targetProxyRow >= 0 && m_workspacePlacesModel) {
        const int fromMasterRow = m_masterModel->rowForUrl(url);
        const QModelIndex targetSourceIdx = resolveMasterSourceIndex(m_workspacePlacesModel, targetProxyRow);
        if (targetSourceIdx.isValid() && fromMasterRow >= 0) {
            int toMasterRow = targetSourceIdx.row();
            if (dropAfter) {
                toMasterRow++;
            }
            if (fromMasterRow != toMasterRow) {
                m_masterModel->movePlace(fromMasterRow, toMasterRow);
            }
        }
    }

    m_masterModel->refresh();
    qCDebug(zenLog) << "[Action: addPlaceFromUrl] Added place:" << url << "targetProxyRow:" << targetProxyRow << "dropAfter:" << dropAfter;
    return true;
}

int ZenPanelBridge::essentialsCount() const
{
    return m_masterModel ? m_masterModel->essentialsCount() : 0;
}

bool ZenPanelBridge::canAddEssential() const
{
    return m_masterModel ? m_masterModel->canAddEssential() : false;
}

QString ZenPanelBridge::essentialSlotText() const
{
    const int count = essentialsCount();
    const int maxCount = maxEssentials();
    return QStringLiteral("(%1/%2)").arg(count).arg(maxCount);
}

void ZenPanelBridge::showToolTip(const QPointF &globalPos, const QString &text)
{
    if (text.isEmpty()) {
        QToolTip::hideText();
        return;
    }
    QWidget *parentWidget = qobject_cast<QWidget *>(parent());
    QToolTip::showText(globalPos.toPoint(), text, parentWidget);
}

void ZenPanelBridge::hideToolTip()
{
    QToolTip::hideText();
}

void ZenPanelBridge::setContextMenuActive(bool active)
{
    if (m_contextMenuActive != active) {
        m_contextMenuActive = active;
        Q_EMIT contextMenuActiveChanged();
    }
}

bool ZenPanelBridge::canAcceptDrop(const QUrl &targetUrl) const
{
    const QUrl resolved = KFilePlacesModel::convertedUrl(targetUrl);
    if (!resolved.isValid()) {
        return false;
    }
    return KProtocolManager::supportsWriting(resolved);
}

void ZenPanelBridge::openUrl(const QUrl &url)
{
    const QUrl resolvedUrl = KFilePlacesModel::convertedUrl(url);
    if (!resolvedUrl.isValid()) {
        return;
    }

    clearErrorMessage();

    if (m_tabsModel) {
        int existingTabIdx = -1;
        bool isSecondarySplit = false;
        if (switchToExistingTab() && m_tabsModel->findTabForUrl(resolvedUrl, &existingTabIdx, &isSecondarySplit)) {
            m_tabsModel->activateTab(existingTabIdx, isSecondarySplit);
            qCDebug(zenLog) << "[Action: openUrl -> Switched to existing Tab]" << existingTabIdx << "SecondarySplit:" << isSecondarySplit
                            << "URL:" << resolvedUrl;
            Q_EMIT navigateRequested(i18nc("@info:status",
                                           "Switched to existing tab #%1%2:",
                                           existingTabIdx + 1,
                                           isSecondarySplit ? i18nc("@info:status", " (Secondary split view)") : QString()),
                                     resolvedUrl);
            return;
        }

        m_tabsModel->setCurrentTabUrl(resolvedUrl);
    }

    qCDebug(zenLog) << "[Action: openUrl]" << resolvedUrl.toString();
    Q_EMIT urlActivated(resolvedUrl);
    Q_EMIT navigateRequested(i18nc("@info:status", "Opened in active tab:"), resolvedUrl);
}

void ZenPanelBridge::openUrlInNewTab(const QUrl &url)
{
    const QUrl resolvedUrl = KFilePlacesModel::convertedUrl(url);
    if (!resolvedUrl.isValid()) {
        return;
    }

    clearErrorMessage();

    if (m_tabsModel) {
        m_tabsModel->openNewTab(resolvedUrl);
    }
    qCDebug(zenLog) << "[Action: openUrlInNewTab]" << resolvedUrl.toString();
    Q_EMIT urlInNewTabActivated(resolvedUrl);
    Q_EMIT navigateRequested(i18nc("@info:status", "Opened in new tab:"), resolvedUrl);
}

void ZenPanelBridge::openUrlInSplitView(const QUrl &url)
{
    const QUrl resolvedUrl = KFilePlacesModel::convertedUrl(url);
    if (!resolvedUrl.isValid()) {
        return;
    }

    clearErrorMessage();
    qCDebug(zenLog) << "[Action: openUrlInSplitView]" << resolvedUrl.toString();
    Q_EMIT openInSplitViewRequested(resolvedUrl);
    Q_EMIT navigateRequested(i18nc("@info:status", "Opened in split view:"), resolvedUrl);
}

void ZenPanelBridge::openUrlInNewWindow(const QUrl &url)
{
    const QUrl resolvedUrl = KFilePlacesModel::convertedUrl(url);
    if (!resolvedUrl.isValid()) {
        return;
    }

    clearErrorMessage();
    qCDebug(zenLog) << "[Action: openUrlInNewWindow]" << resolvedUrl.toString();
    Q_EMIT openInNewWindowRequested(resolvedUrl);
    Q_EMIT navigateRequested(i18nc("@info:status", "Opened in new window:"), resolvedUrl);
}

void ZenPanelBridge::focusPreviousWidget()
{
    Q_EMIT focusPreviousRequested();
}

void ZenPanelBridge::focusNextWidget()
{
    Q_EMIT focusNextRequested();
}

void ZenPanelBridge::activateDevice(int proxyRow, bool inNewTab)
{
    if (!m_devicesModel) {
        return;
    }

    const QModelIndex proxyIdx = m_devicesModel->index(proxyRow, 0);
    if (!proxyIdx.isValid()) {
        return;
    }

    const QModelIndex sourceIdx = resolveMasterSourceIndex(m_devicesModel, proxyRow);
    if (sourceIdx.isValid() && m_masterModel) {
        const auto accessibility = m_masterModel->deviceAccessibility(sourceIdx);
        if (accessibility == KFilePlacesModel::SetupInProgress || accessibility == KFilePlacesModel::TeardownInProgress) {
            return;
        }

        if (m_masterModel->setupNeeded(sourceIdx)) {
            qCDebug(zenLog) << "[Action: activateDevice] Mounting unmounted device at source row:" << sourceIdx.row();
            m_pendingSetupClickIndex = QPersistentModelIndex(sourceIdx);
            m_pendingSetupNewTab = inNewTab;
            m_masterModel->requestSetup(sourceIdx);
            return;
        }

        const QUrl deviceUrl = KFilePlacesModel::convertedUrl(m_masterModel->url(sourceIdx));
        if (inNewTab) {
            openUrlInNewTab(deviceUrl);
        } else {
            openUrl(deviceUrl);
        }
        return;
    }

    // Fallback for expanded ZenNetworkPlacesModel entries
    const QUrl netUrl = m_devicesModel->data(proxyIdx, KFilePlacesModel::UrlRole).toUrl();
    if (inNewTab) {
        openUrlInNewTab(netUrl);
    } else {
        openUrl(netUrl);
    }
}

void ZenPanelBridge::executeDropOnUrl(const QUrl &targetUrl, const QList<QUrl> &droppedUrls, const QPoint &globalPos)
{
    const QUrl resolvedTarget = KFilePlacesModel::convertedUrl(targetUrl);
    if (!resolvedTarget.isValid() || droppedUrls.isEmpty()) {
        return;
    }

    if (!KProtocolManager::supportsWriting(resolvedTarget)) {
        reportError(i18nc("@info:status", "Destination '%1' does not support writing.", resolvedTarget.toDisplayString(QUrl::PreferLocalFile)));
        return;
    }

    QMimeData mimeData;
    mimeData.setUrls(droppedUrls);

    QWidget *parentWidget = qobject_cast<QWidget *>(parent());
    const QPoint localPos = parentWidget ? parentWidget->mapFromGlobal(globalPos) : globalPos;
    QDropEvent dropEvent(localPos, Qt::CopyAction | Qt::MoveAction | Qt::LinkAction, &mimeData, Qt::LeftButton, QGuiApplication::keyboardModifiers());

    KIO::DropJob *job = KIO::drop(&dropEvent, resolvedTarget);
    if (job) {
        if (parentWidget) {
            KJobWidgets::setWindow(job, parentWidget);
        }
        connect(job, &KIO::DropJob::result, this, [this](KJob *kjob) {
            if (kjob->error() && kjob->error() != KIO::ERR_USER_CANCELED) {
                reportError(kjob->errorString());
            }
        });
    }
}

void ZenPanelBridge::handleUrlDrop(const QUrl &targetUrl, const QList<QUrl> &droppedUrls, const QPoint &globalPos)
{
    executeDropOnUrl(targetUrl, droppedUrls, globalPos);
}

void ZenPanelBridge::handleDeviceDrop(int deviceProxyRow, const QList<QUrl> &droppedUrls, const QPoint &globalPos)
{
    if (!m_devicesModel || droppedUrls.isEmpty()) {
        return;
    }

    const QModelIndex sourceIdx = resolveMasterSourceIndex(m_devicesModel, deviceProxyRow);
    if (sourceIdx.isValid() && m_masterModel && m_masterModel->setupNeeded(sourceIdx)) {
        m_pendingSetupDropIndex = QPersistentModelIndex(sourceIdx);
        m_pendingDropUrls = droppedUrls;
        m_pendingDropGlobalPos = globalPos;
        m_masterModel->requestSetup(sourceIdx);
        return;
    }

    const QModelIndex proxyIdx = m_devicesModel->index(deviceProxyRow, 0);
    const QUrl targetUrl = m_devicesModel->data(proxyIdx, KFilePlacesModel::UrlRole).toUrl();
    executeDropOnUrl(targetUrl, droppedUrls, globalPos);
}

void ZenPanelBridge::editPlaceEntry(const QModelIndex &sourceIdx)
{
    if (!m_masterModel || !sourceIdx.isValid()) {
        return;
    }

    KBookmark bookmark = m_masterModel->bookmarkForIndex(sourceIdx);
    QUrl url = bookmark.url();
    QString label = m_masterModel->text(sourceIdx);
    QString iconName = bookmark.icon();
    bool appLocal = !bookmark.metaDataItem(QStringLiteral("OnlyInApp")).isEmpty();
    QWidget *parentWidget = qobject_cast<QWidget *>(parent());

    QT_WARNING_PUSH
    QT_WARNING_DISABLE_DEPRECATED
    if (KFilePlaceEditDialog::getInformation(true, url, label, iconName, false, appLocal, 64, parentWidget)) {
        const QString appName = appLocal ? QCoreApplication::instance()->applicationName() : QString();
        m_masterModel->editPlace(sourceIdx, label, url, iconName, appName);
    }
    QT_WARNING_POP
}

void ZenPanelBridge::addNewPlaceEntry()
{
    if (!m_masterModel) {
        return;
    }

    QUrl url = m_tabsModel ? m_tabsModel->activeUrl() : QUrl::fromLocalFile(QDir::homePath());
    QString label;
    QString iconName;
    bool appLocal = false;
    QWidget *parentWidget = qobject_cast<QWidget *>(parent());

    QT_WARNING_PUSH
    QT_WARNING_DISABLE_DEPRECATED
    if (KFilePlaceEditDialog::getInformation(true, url, label, iconName, true, appLocal, 64, parentWidget)) {
        const QString appName = appLocal ? QCoreApplication::instance()->applicationName() : QString();
        m_masterModel->addPlace(label, url, iconName, appName);
    }
    QT_WARNING_POP
}

void ZenPanelBridge::showEssentialsContextMenu(int proxyRow, const QPoint &globalPos)
{
    hideToolTip();
    const QModelIndex sourceIdx = resolveMasterSourceIndex(m_essentialsModel, proxyRow);
    if (!sourceIdx.isValid() || !m_masterModel) {
        return;
    }

    const QUrl placeUrl = m_masterModel->url(sourceIdx);
    const bool isInWorkspacePlaces = m_masterModel->data(sourceIdx, ZenPlacesMasterModel::IsWorkspacePlaceRole).toBool();
    QWidget *parentWidget = qobject_cast<QWidget *>(parent());

    auto *menu = new QMenu(parentWidget);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    setContextMenuActive(true);
    connect(menu, &QMenu::aboutToHide, this, [this]() {
        setContextMenuActive(false);
    });

    QAction *openNewTabAction = menu->addAction(QIcon::fromTheme(QStringLiteral("tab-new")), i18nc("@action:inmenu", "Open in New Tab"));
    QObject::connect(openNewTabAction, &QAction::triggered, this, [this, placeUrl]() {
        openUrlInNewTab(placeUrl);
    });

    QAction *openNewWindowAction = menu->addAction(QIcon::fromTheme(QStringLiteral("window-new")), i18nc("@action:inmenu", "Open in New Window"));
    QObject::connect(openNewWindowAction, &QAction::triggered, this, [this, placeUrl]() {
        openUrlInNewWindow(placeUrl);
    });

    QAction *openSplitAction = menu->addAction(QIcon::fromTheme(QStringLiteral("view-split-left-right")), i18nc("@action:inmenu", "Open in Split View"));
    QObject::connect(openSplitAction, &QAction::triggered, this, [this, placeUrl]() {
        openUrlInSplitView(placeUrl);
    });

    menu->addSeparator();

    QAction *removeEssentialAction = menu->addAction(QIcon::fromTheme(QStringLiteral("bookmark-remove")), i18nc("@action:inmenu", "Remove from Quick Access"));
    QObject::connect(removeEssentialAction, &QAction::triggered, this, [this, sourceIdx]() {
        m_masterModel->removeFromEssentials(sourceIdx);
    });

    if (!isInWorkspacePlaces) {
        QAction *addToPlacesAction =
            menu->addAction(QIcon::fromTheme(QStringLiteral("bookmark-new")), i18nc("@action:inmenu", "Additionally show in \"Places\""));
        QObject::connect(addToPlacesAction, &QAction::triggered, this, [this, sourceIdx]() {
            m_masterModel->setData(sourceIdx, true, ZenPlacesMasterModel::IsWorkspacePlaceRole);
        });
    }

    if (!m_masterModel->isDevice(sourceIdx)) {
        QAction *editAction = menu->addAction(QIcon::fromTheme(QStringLiteral("edit-entry")), i18nc("@action:inmenu", "Edit…"));
        QObject::connect(editAction, &QAction::triggered, this, [this, sourceIdx]() {
            editPlaceEntry(sourceIdx);
        });
    }

    if (placeUrl.isLocalFile()) {
        menu->addSeparator();
        QAction *propertiesAction = menu->addAction(QIcon::fromTheme(QStringLiteral("document-properties")), i18nc("@action:inmenu", "Properties"));
        QObject::connect(propertiesAction, &QAction::triggered, this, [placeUrl, parentWidget]() {
            KPropertiesDialog::showDialog(placeUrl, parentWidget);
        });
    }

    menu->popup(globalPos);
}

void ZenPanelBridge::showWorkspacePlaceContextMenu(int proxyRow, const QPoint &globalPos)
{
    hideToolTip();
    const QModelIndex sourceIdx = resolveMasterSourceIndex(m_workspacePlacesModel, proxyRow);
    if (!sourceIdx.isValid() || !m_masterModel) {
        return;
    }

    const QUrl placeUrl = m_masterModel->url(sourceIdx);
    const bool isEssential = m_masterModel->data(sourceIdx, ZenPlacesMasterModel::IsEssentialRole).toBool();
    const bool isPlaceHidden = m_masterModel->isHidden(sourceIdx);
    QWidget *parentWidget = qobject_cast<QWidget *>(parent());

    auto *menu = new QMenu(parentWidget);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    setContextMenuActive(true);
    connect(menu, &QMenu::aboutToHide, this, [this]() {
        setContextMenuActive(false);
    });

    QAction *openNewTabAction = menu->addAction(QIcon::fromTheme(QStringLiteral("tab-new")), i18nc("@action:inmenu", "Open in New Tab"));
    QObject::connect(openNewTabAction, &QAction::triggered, this, [this, placeUrl]() {
        openUrlInNewTab(placeUrl);
    });

    QAction *openNewWindowAction = menu->addAction(QIcon::fromTheme(QStringLiteral("window-new")), i18nc("@action:inmenu", "Open in New Window"));
    QObject::connect(openNewWindowAction, &QAction::triggered, this, [this, placeUrl]() {
        openUrlInNewWindow(placeUrl);
    });

    QAction *openSplitAction = menu->addAction(QIcon::fromTheme(QStringLiteral("view-split-left-right")), i18nc("@action:inmenu", "Open in Split View"));
    QObject::connect(openSplitAction, &QAction::triggered, this, [this, placeUrl]() {
        openUrlInSplitView(placeUrl);
    });

    menu->addSeparator();

    if (isEssential) {
        QAction *removeEssentialAction =
            menu->addAction(QIcon::fromTheme(QStringLiteral("bookmark-remove")), i18nc("@action:inmenu", "Remove from Quick Access"));
        QObject::connect(removeEssentialAction, &QAction::triggered, this, [this, sourceIdx]() {
            m_masterModel->removeFromEssentials(sourceIdx);
        });
    } else {
        const bool canAdd = canAddEssential();
        const QString actionLabel = QStringLiteral("%1\t%2").arg(i18nc("@action:inmenu", "Add to Quick Access"), essentialSlotText());
        QAction *addEssentialAction = menu->addAction(QIcon::fromTheme(QStringLiteral("bookmark-new")), actionLabel);
        addEssentialAction->setEnabled(canAdd);
        QObject::connect(addEssentialAction, &QAction::triggered, this, [this, sourceIdx]() {
            m_masterModel->toggleEssential(sourceIdx.row());
        });
    }

    menu->addSeparator();

    if (!m_masterModel->isDevice(sourceIdx)) {
        QAction *editAction = menu->addAction(QIcon::fromTheme(QStringLiteral("edit-entry")), i18nc("@action:inmenu", "Edit…"));
        QObject::connect(editAction, &QAction::triggered, this, [this, sourceIdx]() {
            editPlaceEntry(sourceIdx);
        });

        const bool isLocallyShown = m_masterModel->data(sourceIdx, ZenPlacesMasterModel::IsWorkspacePlaceRole).toBool();
        if (isLocallyShown) {
            QAction *removePlaceAction =
                menu->addAction(QIcon::fromTheme(QStringLiteral("bookmark-remove-symbolic")), i18nc("@action:inmenu", "Remove from \"Places\""));
            QObject::connect(removePlaceAction, &QAction::triggered, this, [this, sourceIdx]() {
                m_masterModel->removeFromWorkspacePlaces(sourceIdx);
            });
        } else {
            QAction *showPlaceAction = menu->addAction(QIcon::fromTheme(QStringLiteral("visibility")), i18nc("@action:inmenu", "Show in \"Places\""));
            QObject::connect(showPlaceAction, &QAction::triggered, this, [this, sourceIdx]() {
                m_masterModel->setData(sourceIdx, true, ZenPlacesMasterModel::IsWorkspacePlaceRole);
            });
        }
    }

    QAction *hideAction = menu->addAction(QIcon::fromTheme(QStringLiteral("hint")), i18nc("@action:inmenu", "Hide \"Place\" System-wide"));
    hideAction->setCheckable(true);
    hideAction->setChecked(isPlaceHidden);
    QObject::connect(hideAction, &QAction::toggled, this, [this, sourceIdx](bool checked) {
        m_masterModel->setPlaceHidden(sourceIdx, checked);
    });

    if (m_masterModel->hiddenCount() > 0 || m_workspacePlacesModel->showHiddenPlaces()) {
        QAction *showAllAction = menu->addAction(QIcon::fromTheme(QStringLiteral("visibility")), i18nc("@action:inmenu", "Show all \"Places\""));
        showAllAction->setCheckable(true);
        showAllAction->setChecked(m_workspacePlacesModel->showHiddenPlaces());
        QObject::connect(showAllAction, &QAction::toggled, this, [this](bool checked) {
            m_workspacePlacesModel->setShowHiddenPlaces(checked);
            if (m_devicesModel) {
                m_devicesModel->setShowHiddenPlaces(checked);
            }
        });
    }

    if (placeUrl.isLocalFile()) {
        menu->addSeparator();
        QAction *propertiesAction = menu->addAction(QIcon::fromTheme(QStringLiteral("document-properties")), i18nc("@action:inmenu", "Properties"));
        QObject::connect(propertiesAction, &QAction::triggered, this, [placeUrl, parentWidget]() {
            KPropertiesDialog::showDialog(placeUrl, parentWidget);
        });
    }

    menu->popup(globalPos);
}

void ZenPanelBridge::showWorkspaceBackgroundContextMenu(const QPoint &globalPos)
{
    hideToolTip();
    if (!m_masterModel || !m_workspacePlacesModel) {
        return;
    }

    QWidget *parentWidget = qobject_cast<QWidget *>(parent());
    auto *menu = new QMenu(parentWidget);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    setContextMenuActive(true);
    connect(menu, &QMenu::aboutToHide, this, [this]() {
        setContextMenuActive(false);
    });

    QAction *addEntryAction = menu->addAction(QIcon::fromTheme(QStringLiteral("document-new")), i18nc("@action:inmenu", "Add \"Place\"…"));
    QObject::connect(addEntryAction, &QAction::triggered, this, &ZenPanelBridge::addNewPlaceEntry);

    if (m_masterModel->hiddenCount() > 0 || m_workspacePlacesModel->showHiddenPlaces()) {
        QAction *showAllAction = menu->addAction(QIcon::fromTheme(QStringLiteral("visibility")), i18nc("@action:inmenu", "Show all \"Places\""));
        showAllAction->setCheckable(true);
        showAllAction->setChecked(m_workspacePlacesModel->showHiddenPlaces());
        QObject::connect(showAllAction, &QAction::toggled, this, [this](bool checked) {
            m_workspacePlacesModel->setShowHiddenPlaces(checked);
            if (m_devicesModel) {
                m_devicesModel->setShowHiddenPlaces(checked);
            }
        });
    }

    menu->addSeparator();
    QAction *configureAction = menu->addAction(QIcon::fromTheme(QStringLiteral("configure")), i18nc("@action:inmenu", "Configure ZenPanel…"));
    QObject::connect(configureAction, &QAction::triggered, this, &ZenPanelBridge::requestOpenSettings);

    menu->popup(globalPos);
}

void ZenPanelBridge::showPlacesContextMenu(int row, const QPoint &mousePos)
{
    showTrashContextMenu(row, mousePos);
}

void ZenPanelBridge::showTrashContextMenu(int /*row*/, const QPoint &globalPos)
{
    hideToolTip();
    QWidget *parentWidget = qobject_cast<QWidget *>(parent());
    auto *menu = new QMenu(parentWidget);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    setContextMenuActive(true);
    connect(menu, &QMenu::aboutToHide, this, [this]() {
        setContextMenuActive(false);
    });

    const QUrl trashUrl(QStringLiteral("trash:/"));

    QAction *emptyTrashAction = menu->addAction(QIcon::fromTheme(QStringLiteral("edit-delete")), i18nc("@action:inmenu", "Empty Trash"));

    KConfig trashConfig(QStringLiteral("trashrc"), KConfig::SimpleConfig);
    const bool isTrashEmpty = trashConfig.group(QStringLiteral("Status")).readEntry("Empty", true);
    emptyTrashAction->setEnabled(!isTrashEmpty);

    QObject::connect(emptyTrashAction, &QAction::triggered, this, [this, parentWidget]() {
        using AskIface = KIO::AskUserActionInterface;
        auto *job = new KIO::DeleteOrTrashJob(QList<QUrl>{}, AskIface::EmptyTrash, AskIface::DefaultConfirmation, parentWidget);
        connect(job, &KJob::result, this, [this](KJob *kjob) {
            if (kjob->error() && kjob->error() != KIO::ERR_USER_CANCELED) {
                reportError(kjob->errorString());
            }
        });
        job->start();
    });

    menu->addSeparator();

    QAction *openNewTabAction = menu->addAction(QIcon::fromTheme(QStringLiteral("tab-new")), i18nc("@action:inmenu", "Open in New Tab"));
    QObject::connect(openNewTabAction, &QAction::triggered, this, [this, trashUrl]() {
        openUrlInNewTab(trashUrl);
    });

    QAction *openNewWindowAction = menu->addAction(QIcon::fromTheme(QStringLiteral("window-new")), i18nc("@action:inmenu", "Open in New Window"));
    QObject::connect(openNewWindowAction, &QAction::triggered, this, [this, trashUrl]() {
        openUrlInNewWindow(trashUrl);
    });

    QAction *openSplitAction = menu->addAction(QIcon::fromTheme(QStringLiteral("view-split-left-right")), i18nc("@action:inmenu", "Open in Split View"));
    QObject::connect(openSplitAction, &QAction::triggered, this, [this, trashUrl]() {
        openUrlInSplitView(trashUrl);
    });

    QAction *propertiesAction = menu->addAction(QIcon::fromTheme(QStringLiteral("document-properties")), i18nc("@action:inmenu", "Properties"));
    QObject::connect(propertiesAction, &QAction::triggered, this, [trashUrl, parentWidget]() {
        KPropertiesDialog::showDialog(trashUrl, parentWidget);
    });

    menu->popup(globalPos);
}

void ZenPanelBridge::showDevicesContextMenu(int row, const QPoint &globalPos)
{
    hideToolTip();
    if (!m_devicesModel) {
        return;
    }

    const QModelIndex proxyIdx = m_devicesModel->index(row, 0);
    if (!proxyIdx.isValid()) {
        return;
    }

    QWidget *parentWidget = qobject_cast<QWidget *>(parent());
    auto *menu = new QMenu(parentWidget);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    setContextMenuActive(true);
    connect(menu, &QMenu::aboutToHide, this, [this]() {
        setContextMenuActive(false);
    });

    const QUrl targetUrl = m_devicesModel->data(proxyIdx, KFilePlacesModel::UrlRole).toUrl();
    const bool isPinned = m_devicesModel->data(proxyIdx, ZenPlacesMasterModel::IsPinnedDeviceRole).toBool();

    QAction *openNewTabAction = menu->addAction(QIcon::fromTheme(QStringLiteral("tab-new")), i18nc("@action:inmenu", "Open in New Tab"));
    QObject::connect(openNewTabAction, &QAction::triggered, this, [this, row]() {
        activateDevice(row, /*inNewTab=*/true);
    });

    if (targetUrl.isValid()) {
        QAction *openNewWindowAction = menu->addAction(QIcon::fromTheme(QStringLiteral("window-new")), i18nc("@action:inmenu", "Open in New Window"));
        QObject::connect(openNewWindowAction, &QAction::triggered, this, [this, targetUrl]() {
            openUrlInNewWindow(targetUrl);
        });

        QAction *openSplitAction = menu->addAction(QIcon::fromTheme(QStringLiteral("view-split-left-right")), i18nc("@action:inmenu", "Open in Split View"));
        QObject::connect(openSplitAction, &QAction::triggered, this, [this, targetUrl]() {
            openUrlInSplitView(targetUrl);
        });
    }

    QAction *pinDeviceAction = menu->addAction(QIcon::fromTheme(QStringLiteral("pin")), i18nc("@action:inmenu", "Permanently Pin Device"));
    pinDeviceAction->setCheckable(true);
    pinDeviceAction->setChecked(isPinned);
    QObject::connect(pinDeviceAction, &QAction::triggered, this, [this, row]() {
        toggleDevicePin(row);
    });

    const QModelIndex sourceIdx = resolveMasterSourceIndex(m_devicesModel, row);
    if (sourceIdx.isValid() && m_masterModel) {
        QAction *mountAction = nullptr;
        if (m_masterModel->setupNeeded(sourceIdx)) {
            mountAction = new QAction(QIcon::fromTheme(QStringLiteral("media-mount")), i18nc("@action:inmenu", "Mount"), menu);
        }

        QAction *teardownAction = m_masterModel->teardownActionForIndex(sourceIdx);
        if (teardownAction) {
            teardownAction->setParent(menu);
            if (!m_masterModel->isTeardownAllowed(sourceIdx)) {
                teardownAction->setEnabled(false);
            }
        }

        QAction *ejectAction = m_masterModel->ejectActionForIndex(sourceIdx);
        if (ejectAction) {
            ejectAction->setParent(menu);
        }

        QAction *partitionAction = m_masterModel->partitionActionForIndex(sourceIdx);
        if (partitionAction) {
            partitionAction->setParent(menu);
        }

        if (mountAction || teardownAction || ejectAction) {
            menu->addSeparator();
        }
        if (mountAction) {
            QObject::connect(mountAction, &QAction::triggered, this, [this, sourceIdx]() {
                m_masterModel->requestSetup(sourceIdx);
            });
            menu->addAction(mountAction);
        }
        if (teardownAction) {
            QObject::connect(teardownAction, &QAction::triggered, this, [this, sourceIdx]() {
                m_masterModel->requestTeardown(sourceIdx);
            });
            menu->addAction(teardownAction);
        }
        if (ejectAction) {
            QObject::connect(ejectAction, &QAction::triggered, this, [this, sourceIdx]() {
                m_masterModel->requestEject(sourceIdx);
            });
            menu->addAction(ejectAction);
        }
        if (partitionAction) {
            menu->addSeparator();
            menu->addAction(partitionAction);
        }

        menu->addSeparator();
        QAction *hideAction = menu->addAction(QIcon::fromTheme(QStringLiteral("hint")), i18nc("@action:inmenu", "Hide"));
        hideAction->setCheckable(true);
        hideAction->setChecked(m_masterModel->isHidden(sourceIdx));
        QObject::connect(hideAction, &QAction::toggled, this, [this, sourceIdx](bool checked) {
            m_masterModel->setPlaceHidden(sourceIdx, checked);
        });
    }

    if (targetUrl.isLocalFile()) {
        menu->addSeparator();
        QAction *propertiesAction = menu->addAction(QIcon::fromTheme(QStringLiteral("document-properties")), i18nc("@action:inmenu", "Properties"));
        QObject::connect(propertiesAction, &QAction::triggered, this, [targetUrl, parentWidget]() {
            KPropertiesDialog::showDialog(targetUrl, parentWidget);
        });
    }

    menu->popup(globalPos);
}

void ZenPanelBridge::showFolderContextMenu(const QUrl &url, const QPoint &globalPos)
{
    hideToolTip();
    if (!m_masterModel || !url.isValid()) {
        return;
    }

    QWidget *parentWidget = qobject_cast<QWidget *>(parent());
    auto *menu = new QMenu(parentWidget);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    setContextMenuActive(true);
    connect(menu, &QMenu::aboutToHide, this, [this]() {
        setContextMenuActive(false);
    });

    const KFileItem fileItem = m_treeModel ? m_treeModel->fileItemForUrl(url) : KFileItem(url);
    const KFileItemListProperties capabilities(KFileItemList{fileItem});

    // 1. Open in new tab + Zen Essentials / Places actions
    QAction *openNewTabAction = menu->addAction(QIcon::fromTheme(QStringLiteral("tab-new")), i18nc("@action:inmenu", "Open in New Tab"));
    QObject::connect(openNewTabAction, &QAction::triggered, this, [this, url]() {
        openUrlInNewTab(url);
    });

    QAction *openNewWindowAction = menu->addAction(QIcon::fromTheme(QStringLiteral("window-new")), i18nc("@action:inmenu", "Open in New Window"));
    QObject::connect(openNewWindowAction, &QAction::triggered, this, [this, url]() {
        openUrlInNewWindow(url);
    });

    QAction *openSplitAction = menu->addAction(QIcon::fromTheme(QStringLiteral("view-split-left-right")), i18nc("@action:inmenu", "Open in Split View"));
    QObject::connect(openSplitAction, &QAction::triggered, this, [this, url]() {
        openUrlInSplitView(url);
    });

    const int existingRow = m_masterModel->rowForUrl(url);
    const bool isEssential = (existingRow >= 0) && m_masterModel->data(m_masterModel->index(existingRow, 0), ZenPlacesMasterModel::IsEssentialRole).toBool();
    const bool isWorkspacePlace =
        (existingRow >= 0) && m_masterModel->data(m_masterModel->index(existingRow, 0), ZenPlacesMasterModel::IsWorkspacePlaceRole).toBool();

    if (isEssential) {
        QAction *removeEssentialAction =
            menu->addAction(QIcon::fromTheme(QStringLiteral("bookmark-remove")), i18nc("@action:inmenu", "Remove from Quick Access"));
        QObject::connect(removeEssentialAction, &QAction::triggered, this, [this, existingRow]() {
            m_masterModel->removeFromEssentials(m_masterModel->index(existingRow, 0));
        });
    } else {
        const bool canAdd = canAddEssential();
        const QString actionLabel = QStringLiteral("%1\t%2").arg(i18nc("@action:inmenu", "Add to Quick Access"), essentialSlotText());
        QAction *addEssentialAction = menu->addAction(QIcon::fromTheme(QStringLiteral("bookmark-new")), actionLabel);
        addEssentialAction->setEnabled(canAdd);
        QObject::connect(addEssentialAction, &QAction::triggered, this, [this, url]() {
            addFolderToEssentials(url);
        });
    }

    if (!isWorkspacePlace) {
        QAction *addToPlacesAction = menu->addAction(QIcon::fromTheme(QStringLiteral("bookmark-new")), i18nc("@action:inmenu", "Add to \"Places\""));
        QObject::connect(addToPlacesAction, &QAction::triggered, this, [this, url]() {
            m_masterModel->addUrlToWorkspacePlaces(url);
        });
    }

    menu->addSeparator();

    // 2. Standard Dolphin TreeViewContextMenu file operations (Cut, Copy, Paste, Rename, Trash/Delete)
    auto populateClipboard = [fileItem](bool cut) {
        auto *mimeData = new QMimeData();
        const QList<QUrl> kdeUrls{fileItem.url()};
        bool isLocal = false;
        const QList<QUrl> mostLocalUrls{fileItem.mostLocalUrl(&isLocal)};
        KIO::setClipboardDataCut(mimeData, cut);
        KUrlMimeData::exportUrlsToPortal(mimeData);
        KUrlMimeData::setUrls(kdeUrls, mostLocalUrls, mimeData);
        QApplication::clipboard()->setMimeData(mimeData);
    };

    QAction *cutAction = menu->addAction(QIcon::fromTheme(QStringLiteral("edit-cut")), i18nc("@action:inmenu", "Cut"));
    cutAction->setEnabled(capabilities.supportsMoving());
    QObject::connect(cutAction, &QAction::triggered, this, [populateClipboard]() {
        populateClipboard(true);
    });

    QAction *copyAction = menu->addAction(QIcon::fromTheme(QStringLiteral("edit-copy")), i18nc("@action:inmenu", "Copy"));
    QObject::connect(copyAction, &QAction::triggered, this, [populateClipboard]() {
        populateClipboard(false);
    });

    const QMimeData *clipboardData = QApplication::clipboard()->mimeData();
    bool canPaste = false;
    const QString pasteText = KIO::pasteActionText(clipboardData, &canPaste, fileItem);
    QAction *pasteAction = menu->addAction(QIcon::fromTheme(QStringLiteral("edit-paste")), pasteText);
    pasteAction->setEnabled(canPaste);
    QObject::connect(pasteAction, &QAction::triggered, this, [this, url, parentWidget]() {
        KIO::PasteJob *job = KIO::paste(QApplication::clipboard()->mimeData(), url);
        if (parentWidget) {
            KJobWidgets::setWindow(job, parentWidget);
        }
        connect(job, &KJob::result, this, [this](KJob *kjob) {
            if (kjob->error() && kjob->error() != KIO::ERR_USER_CANCELED) {
                reportError(kjob->errorString());
            }
        });
    });

    menu->addSeparator();

    QAction *renameAction = menu->addAction(QIcon::fromTheme(QStringLiteral("edit-rename")), i18nc("@action:inmenu", "Rename…"));
    renameAction->setEnabled(capabilities.supportsMoving());
    QObject::connect(renameAction, &QAction::triggered, this, [fileItem, parentWidget]() {
        auto *dialog = new KIO::RenameFileDialog(KFileItemList{fileItem}, parentWidget);
        dialog->open();
    });

    KSharedConfig::Ptr globalConfig = KSharedConfig::openConfig(QStringLiteral("kdeglobals"), KConfig::IncludeGlobals);
    KConfigGroup kdeGroup(globalConfig, QStringLiteral("KDE"));
    bool showDeleteCommand = kdeGroup.readEntry("ShowDeleteCommand", false);

    if (url.isLocalFile()) {
        QAction *moveToTrashAction = menu->addAction(QIcon::fromTheme(QStringLiteral("user-trash")), i18nc("@action:inmenu", "Move to Trash"));
        moveToTrashAction->setEnabled(capabilities.isLocal() && capabilities.supportsMoving());
        QObject::connect(moveToTrashAction, &QAction::triggered, this, [this, url, parentWidget]() {
            using AskIface = KIO::AskUserActionInterface;
            auto *job = new KIO::DeleteOrTrashJob(QList<QUrl>{url}, AskIface::Trash, AskIface::DefaultConfirmation, parentWidget);
            connect(job, &KJob::result, this, [this](KJob *kjob) {
                if (kjob->error() && kjob->error() != KIO::ERR_USER_CANCELED) {
                    reportError(kjob->errorString());
                }
            });
            job->start();
        });
    } else {
        showDeleteCommand = true;
    }

    if (showDeleteCommand) {
        QAction *deleteAction = menu->addAction(QIcon::fromTheme(QStringLiteral("edit-delete")), i18nc("@action:inmenu", "Delete"));
        deleteAction->setEnabled(capabilities.supportsDeleting());
        QObject::connect(deleteAction, &QAction::triggered, this, [this, url, parentWidget]() {
            using AskIface = KIO::AskUserActionInterface;
            auto *job = new KIO::DeleteOrTrashJob(QList<QUrl>{url}, AskIface::Delete, AskIface::DefaultConfirmation, parentWidget);
            connect(job, &KJob::result, this, [this](KJob *kjob) {
                if (kjob->error() && kjob->error() != KIO::ERR_USER_CANCELED) {
                    reportError(kjob->errorString());
                }
            });
            job->start();
        });
    }

    // 3. FoldersPanel view options (Show Hidden Files, Limit to Home Directory)
    if (m_treeModel) {
        menu->addSeparator();

        QAction *showHiddenAction = menu->addAction(i18nc("@action:inmenu", "Show Hidden Folders"));
        showHiddenAction->setCheckable(true);
        showHiddenAction->setChecked(m_treeModel->showHiddenFiles());
        QObject::connect(showHiddenAction, &QAction::toggled, m_treeModel, &ZenFolderTreeModel::setShowHiddenFiles);

        QAction *limitHomeAction = menu->addAction(i18nc("@action:inmenu", "Limit to Home Directory"));
        limitHomeAction->setCheckable(true);
        limitHomeAction->setEnabled(url.isLocalFile());
        limitHomeAction->setChecked(m_treeModel->limitToHome());
        QObject::connect(limitHomeAction, &QAction::toggled, m_treeModel, &ZenFolderTreeModel::setLimitToHome);
    }

    // 4. Properties dialog
    menu->addSeparator();
    QAction *propertiesAction = menu->addAction(QIcon::fromTheme(QStringLiteral("document-properties")), i18nc("@action:inmenu", "Properties"));
    QObject::connect(propertiesAction, &QAction::triggered, this, [url, parentWidget]() {
        KPropertiesDialog::showDialog(url, parentWidget);
    });

    menu->popup(globalPos);
}

void ZenPanelBridge::showTreeBackgroundContextMenu(const QUrl & /*rootUrl*/, const QPoint &globalPos)
{
    if (!m_treeModel) {
        return;
    }

    QWidget *parentWidget = qobject_cast<QWidget *>(parent());
    auto *menu = new QMenu(parentWidget);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    setContextMenuActive(true);
    connect(menu, &QMenu::aboutToHide, this, [this]() {
        setContextMenuActive(false);
    });

    QAction *showHiddenAction = menu->addAction(i18nc("@action:inmenu", "Show Hidden Folders"));
    showHiddenAction->setCheckable(true);
    showHiddenAction->setChecked(m_treeModel->showHiddenFiles());
    QObject::connect(showHiddenAction, &QAction::toggled, m_treeModel, &ZenFolderTreeModel::setShowHiddenFiles);

    QAction *limitHomeAction = menu->addAction(i18nc("@action:inmenu", "Limit to Home Directory"));
    limitHomeAction->setCheckable(true);
    limitHomeAction->setChecked(m_treeModel->limitToHome());
    QObject::connect(limitHomeAction, &QAction::toggled, m_treeModel, &ZenFolderTreeModel::setLimitToHome);

    menu->addSeparator();
    QAction *configureAction = menu->addAction(QIcon::fromTheme(QStringLiteral("configure")), i18nc("@action:inmenu", "Configure ZenPanel…"));
    QObject::connect(configureAction, &QAction::triggered, this, &ZenPanelBridge::requestOpenSettings);

    menu->popup(globalPos);
}

void ZenPanelBridge::addFolderToEssentials(const QUrl &url)
{
    if (!m_masterModel) {
        return;
    }

    if (m_masterModel->addAsEssential(url)) {
        qCDebug(zenLog) << "[Action: addFolderToEssentials] Added:" << url << "Total:" << m_masterModel->essentialsCount();
    } else {
        qCDebug(zenLog) << "[Action: addFolderToEssentials] Limit reached or rejected for:" << url;
    }
}

void ZenPanelBridge::activateTab(int tabIndex, bool focusSecondary)
{
    if (m_tabsModel) {
        m_tabsModel->activateTab(tabIndex, focusSecondary);
    }
    qCDebug(zenLog) << "[Action: activateTab] Tab:" << tabIndex << "FocusSecondary:" << focusSecondary;
}

void ZenPanelBridge::closeTab(int tabIndex)
{
    if (m_tabsModel) {
        m_tabsModel->closeTab(tabIndex);
    }
    qCDebug(zenLog) << "[Action: closeTab] Tab:" << tabIndex;
}

void ZenPanelBridge::requestTeardown(int row)
{
    const QModelIndex sourceIdx = resolveMasterSourceIndex(m_devicesModel, row);
    if (!sourceIdx.isValid() || !m_masterModel) {
        return;
    }

    qCDebug(zenLog) << "[Action: requestTeardown] ProxyRow:" << row << "SourceRow:" << sourceIdx.row();
    if (m_masterModel->isEjectAllowed(sourceIdx)) {
        m_masterModel->requestEject(sourceIdx);
    } else if (m_masterModel->isTeardownAllowed(sourceIdx)) {
        m_masterModel->requestTeardown(sourceIdx);
    }
}

void ZenPanelBridge::toggleDevicePin(int deviceProxyRow)
{
    if (!m_devicesModel) {
        return;
    }

    const QModelIndex proxyIdx = m_devicesModel->index(deviceProxyRow, 0);
    if (!proxyIdx.isValid()) {
        return;
    }

    const bool currentState = m_devicesModel->data(proxyIdx, ZenPlacesMasterModel::IsPinnedDeviceRole).toBool();
    qCDebug(zenLog) << "[Action: toggleDevicePin] ProxyRow:" << deviceProxyRow << "NewState:" << !currentState;
    m_devicesModel->setData(proxyIdx, !currentState, ZenPlacesMasterModel::IsPinnedDeviceRole);
}

void ZenPanelBridge::notifySettingsChanged()
{
    qCDebug(zenLog) << "[Settings] Emitting notification signals for all configuration properties";
    m_colorIconCache.clear();
    m_symbolicIconCache.clear();
    m_themeMetricsRevision++;
    Q_EMIT maxEssentialsChanged();
    Q_EMIT showAddEssentialButtonChanged();
    Q_EMIT essentialsIconStyleChanged();
    Q_EMIT placesIconSizeSettingChanged();
    Q_EMIT lookFeelModeChanged();
    Q_EMIT defaultWorkspaceViewChanged();
    Q_EMIT highlightOpenTabPlacesChanged();
    Q_EMIT switchToExistingTabChanged();
    const bool hideEss = ZenPanelSettings::self()->hideEssentialsInWorkspace();
    if (m_workspacePlacesModel) {
        m_workspacePlacesModel->setHideEssentialsInWorkspace(hideEss);
    }
    Q_EMIT hideEssentialsInWorkspaceChanged();
    Q_EMIT devicesPinnedChanged();
    Q_EMIT expandNetworkFolderChanged();
    Q_EMIT limitTreeToHomeChanged();
    Q_EMIT showHiddenFoldersInTreeChanged();
    Q_EMIT showTrashSectionChanged();
    Q_EMIT customSectionIconSizesChanged();
    Q_EMIT customSectionIconStylesChanged();
    Q_EMIT sectionSizesChanged();
    Q_EMIT globalIconStyleChanged();
    Q_EMIT themeMetricsChanged();
}
