#pragma once

#include <QObject>
#include <QUrl>
#include <QPoint>
#include <QList>
#include <QPersistentModelIndex>
#include <QPointer>
#include <QtQml/qqmlregistration.h>

class QDialog;

#include "ZenFolderTreeModel.h"
#include "ZenNetworkPlacesModel.h"
#include "ZenPlacesMasterModel.h"
#include "ZenSectionFilterProxy.h"
#include "ZenTabsModel.h"

/**
 * @brief Central dispatch mediator connecting QML view events to C++ backend models and KF6/KIO system services.
 */
class ZenPanelBridge : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(Qt::Orientation panelOrientation READ panelOrientation WRITE setPanelOrientation NOTIFY panelOrientationChanged FINAL)
    Q_PROPERTY(bool devicesPinned READ devicesPinned WRITE setDevicesPinned NOTIFY devicesPinnedChanged FINAL)
    Q_PROPERTY(bool expandNetworkFolder READ expandNetworkFolder WRITE setExpandNetworkFolder NOTIFY expandNetworkFolderChanged FINAL)
    Q_PROPERTY(bool highlightOpenTabPlaces READ highlightOpenTabPlaces WRITE setHighlightOpenTabPlaces NOTIFY highlightOpenTabPlacesChanged FINAL)
    Q_PROPERTY(bool switchToExistingTab READ switchToExistingTab WRITE setSwitchToExistingTab NOTIFY switchToExistingTabChanged FINAL)
    Q_PROPERTY(int maxEssentials READ maxEssentials WRITE setMaxEssentials NOTIFY maxEssentialsChanged FINAL)
    Q_PROPERTY(bool showAddEssentialButton READ showAddEssentialButton WRITE setShowAddEssentialButton NOTIFY showAddEssentialButtonChanged FINAL)
    Q_PROPERTY(int essentialsIconStyle READ essentialsIconStyle WRITE setEssentialsIconStyle NOTIFY essentialsIconStyleChanged FINAL)
    Q_PROPERTY(bool showTrashSection READ showTrashSection WRITE setShowTrashSection NOTIFY showTrashSectionChanged FINAL)
    Q_PROPERTY(int globalIconStyle READ globalIconStyle WRITE setGlobalIconStyle NOTIFY globalIconStyleChanged FINAL)
    Q_PROPERTY(bool preferOutlineIcons READ preferOutlineIcons WRITE setPreferOutlineIcons NOTIFY preferOutlineIconsChanged FINAL)
    Q_PROPERTY(int customEssentialsIconSize READ customEssentialsIconSize WRITE setCustomEssentialsIconSize NOTIFY customSectionIconSizesChanged FINAL)
    Q_PROPERTY(int customPlacesIconSize READ customPlacesIconSize WRITE setCustomPlacesIconSize NOTIFY customSectionIconSizesChanged FINAL)
    Q_PROPERTY(int customDevicesIconSize READ customDevicesIconSize WRITE setCustomDevicesIconSize NOTIFY customSectionIconSizesChanged FINAL)
    Q_PROPERTY(int customTreeIconSize READ customTreeIconSize WRITE setCustomTreeIconSize NOTIFY customSectionIconSizesChanged FINAL)
    Q_PROPERTY(int customEssentialsIconStyle READ customEssentialsIconStyle WRITE setCustomEssentialsIconStyle NOTIFY customSectionIconStylesChanged FINAL)
    Q_PROPERTY(int customPlacesIconStyle READ customPlacesIconStyle WRITE setCustomPlacesIconStyle NOTIFY customSectionIconStylesChanged FINAL)
    Q_PROPERTY(int customDevicesIconStyle READ customDevicesIconStyle WRITE setCustomDevicesIconStyle NOTIFY customSectionIconStylesChanged FINAL)
    Q_PROPERTY(int customTreeIconStyle READ customTreeIconStyle WRITE setCustomTreeIconStyle NOTIFY customSectionIconStylesChanged FINAL)
    Q_PROPERTY(int themeMetricsRevision READ themeMetricsRevision NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int defaultWorkspaceView READ defaultWorkspaceView WRITE setDefaultWorkspaceView NOTIFY defaultWorkspaceViewChanged FINAL)
    Q_PROPERTY(bool limitTreeToHome READ limitTreeToHome WRITE setLimitTreeToHome NOTIFY limitTreeToHomeChanged FINAL)
    Q_PROPERTY(bool showHiddenFoldersInTree READ showHiddenFoldersInTree WRITE setShowHiddenFoldersInTree NOTIFY showHiddenFoldersInTreeChanged FINAL)
    Q_PROPERTY(int lookFeelMode READ lookFeelMode WRITE setLookFeelMode NOTIFY lookFeelModeChanged FINAL)
    Q_PROPERTY(bool isDolphinStyle READ isDolphinStyle NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int itemRowHeight READ itemRowHeight NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int placesRowHeight READ placesRowHeight NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int devicesRowHeight READ devicesRowHeight NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int treeRowHeight READ treeRowHeight NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int iconSize READ iconSize NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int placesIconSize READ placesIconSize NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int essentialsIconSize READ essentialsIconSize NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int devicesIconSize READ devicesIconSize NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int treeIconSize READ treeIconSize NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int essentialsTileWidth READ essentialsTileWidth NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int essentialsTileHeight READ essentialsTileHeight NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int placesIconSizeSetting READ placesIconSizeSetting WRITE setPlacesIconSizeSetting NOTIFY placesIconSizeSettingChanged FINAL)
    Q_PROPERTY(int lateralMargin READ lateralMargin NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(int itemRadius READ itemRadius NOTIFY themeMetricsChanged FINAL)
    Q_PROPERTY(bool keyboardNavigationActive READ keyboardNavigationActive WRITE setKeyboardNavigationActive NOTIFY keyboardNavigationActiveChanged FINAL)
    Q_PROPERTY(bool touchInteractionActive READ touchInteractionActive WRITE setTouchInteractionActive NOTIFY touchInteractionActiveChanged FINAL)
    Q_PROPERTY(QString activeSection READ activeSection WRITE setActiveSection NOTIFY activeSectionChanged FINAL)
    Q_PROPERTY(QString focusedItemDescription READ focusedItemDescription WRITE setFocusedItemDescription NOTIFY focusedItemDescriptionChanged FINAL)
    Q_PROPERTY(QString lastErrorMessage READ lastErrorMessage NOTIFY lastErrorMessageChanged FINAL)
    Q_PROPERTY(ZenSectionFilterProxy *essentialsModel READ essentialsModel CONSTANT FINAL)
    Q_PROPERTY(ZenSectionFilterProxy *workspacePlacesModel READ workspacePlacesModel CONSTANT FINAL)
    Q_PROPERTY(ZenSectionFilterProxy *devicesModel READ devicesModel CONSTANT FINAL)
    Q_PROPERTY(ZenSectionFilterProxy *trashModel READ trashModel CONSTANT FINAL)
    Q_PROPERTY(ZenTabsModel *tabsModel READ tabsModel CONSTANT FINAL)
    Q_PROPERTY(ZenFolderTreeModel *treeModel READ treeModel CONSTANT FINAL)

public:
    explicit ZenPanelBridge(QObject *parent = nullptr);
    ~ZenPanelBridge() override;

    Qt::Orientation panelOrientation() const;
    void setPanelOrientation(Qt::Orientation orientation);

    /**
     * @brief Returns whether the Devices section is permanently pinned open in the panel layout.
     */
    bool devicesPinned() const;

    /**
     * @brief Updates and persists the pinned state of the Devices section via KConfigXT.
     */
    void setDevicesPinned(bool pinned);

    /**
     * @brief Returns whether the "remote:/" network folder is expanded inline into individual device entries.
     */
    bool expandNetworkFolder() const;

    /**
     * @brief Updates and persists the inline network folder expansion setting via KConfigXT.
     */
    void setExpandNetworkFolder(bool expand);

    /**
     * @brief Returns whether places currently open in Dolphin tabs/split-views receive a pale background highlight.
     */
    bool highlightOpenTabPlaces() const;
    void setHighlightOpenTabPlaces(bool highlight);

    /**
     * @brief Returns whether clicking an already-open place switches to its existing tab instead of reopening it.
     */
    bool switchToExistingTab() const;
    void setSwitchToExistingTab(bool switchTab);

    int maxEssentials() const;
    void setMaxEssentials(int max);

    bool showAddEssentialButton() const;
    void setShowAddEssentialButton(bool show);

    int essentialsIconStyle() const;
    void setEssentialsIconStyle(int style);

    int defaultWorkspaceView() const;
    void setDefaultWorkspaceView(int viewIndex);

    bool limitTreeToHome() const;
    void setLimitTreeToHome(bool limit);

    bool showHiddenFoldersInTree() const;
    void setShowHiddenFoldersInTree(bool show);

    bool showTrashSection() const;
    void setShowTrashSection(bool show);

    int globalIconStyle() const;
    void setGlobalIconStyle(int style);

    bool preferOutlineIcons() const;
    void setPreferOutlineIcons(bool prefer);

    int customEssentialsIconSize() const;
    void setCustomEssentialsIconSize(int size);

    int customPlacesIconSize() const;
    void setCustomPlacesIconSize(int size);

    int customDevicesIconSize() const;
    void setCustomDevicesIconSize(int size);

    int customTreeIconSize() const;
    void setCustomTreeIconSize(int size);

    int customEssentialsIconStyle() const;
    void setCustomEssentialsIconStyle(int style);

    int customPlacesIconStyle() const;
    void setCustomPlacesIconStyle(int style);

    int customDevicesIconStyle() const;
    void setCustomDevicesIconStyle(int style);

    int customTreeIconStyle() const;
    void setCustomTreeIconStyle(int style);

    int themeMetricsRevision() const;

    /**
     * @brief Returns whether a specific panel section should render icons in monochrome.
     */
    Q_INVOKABLE bool isSectionMonochrome(const QString &section) const;

    /**
     * @brief Returns the effective icon style for a section: 0 = theme default, 1 = color, 2 = monochrome.
     */
    Q_INVOKABLE int effectiveSectionIconStyle(const QString &section) const;

    /**
     * @brief Returns the icon size configured for a section in pixels.
     */
    Q_INVOKABLE int sectionIconSize(const QString &section) const;

    /**
     * @brief Resolves base icon (string name or QIcon) to "-symbolic" variant if preferOutlineIcons is enabled.
     */
    Q_INVOKABLE QString resolveIconName(const QVariant &baseIcon) const;

    /**
     * @brief Resolves icon safely, returning either a symbolic/base icon name or preserving QIcon.
     */
    Q_INVOKABLE QVariant resolveIcon(const QVariant &baseIcon) const;

    /**
     * @brief Resolves section-specific icon safely, respecting per-section color/monochrome overrides.
     */
    Q_INVOKABLE QVariant resolveSectionIcon(const QVariant &baseIcon, const QString &section = QString()) const;

    /**
     * @brief Returns true if an icon mask should be applied for the given section.
     */
    Q_INVOKABLE bool isSectionIconMask(const QVariant &baseIcon, const QString &section = QString()) const;

    int globalIconSize() const;
    int essentialsIconSize() const;
    int placesIconSize() const;
    int devicesIconSize() const;
    int placesRowHeight() const;
    int devicesRowHeight() const;
    int essentialsTileWidth() const;
    int essentialsTileHeight() const;

    /**
     * @brief Returns the active look and feel mode (0: DolphinCompact, 1: SystemKirigami).
     */
    int lookFeelMode() const;
    void setLookFeelMode(int mode);

    /**
     * @brief Returns whether the panel currently renders in classic DolphinCompact style.
     */
    bool isDolphinStyle() const;

    /**
     * @brief Dynamically calculates row height in pixels for regular place list items.
     */
    int itemRowHeight() const;

    /**
     * @brief Dynamically calculates row height in pixels for tree view folder items.
     */
    int treeRowHeight() const;

    /**
     * @brief Returns the icon pixel size for list items (Dolphin/KFilePlacesView or Kirigami standard).
     */
    int iconSize() const;

    /**
     * @brief Returns the configured icon size setting (-1 for auto, or 16, 22, 32, 48, 64).
     */
    int placesIconSizeSetting() const;
    void setPlacesIconSizeSetting(int size);

    /**
     * @brief Returns the icon pixel size for folder tree items.
     */
    int treeIconSize() const;

    /**
     * @brief Returns lateral padding in pixels for delegates (e.g. 4px in Dolphin vs. smallSpacing in Kirigami).
     */
    int lateralMargin() const;

    /**
     * @brief Returns selection and hover corner radius in pixels.
     */
    int itemRadius() const;

    /**
     * @brief Requests opening the ZenPanel settings dialog from QML or preview menu.
     */
    Q_INVOKABLE void requestOpenSettings();

    /**
     * @brief Opens the ZenPanel settings in an independent top-level dialog.
     */
    Q_INVOKABLE void openSettingsDialog();

    /**
     * @brief Closes the settings dialog if currently open.
     */
    Q_INVOKABLE void closeSettingsDialog();

    bool eventFilter(QObject *watched, QEvent *event) override;

    bool keyboardNavigationActive() const;
    void setKeyboardNavigationActive(bool active);

    bool touchInteractionActive() const;
    void setTouchInteractionActive(bool active);

    QString activeSection() const;
    void setActiveSection(const QString &section);

    QString focusedItemDescription() const;
    void setFocusedItemDescription(const QString &desc);

    Q_INVOKABLE void notifyMouseInteraction(const QString &section = QString());
    Q_INVOKABLE void notifyMouseHoverSection(const QString &section);
    Q_INVOKABLE void notifyKeyboardInteraction();
    Q_INVOKABLE void notifyTouchInteraction(const QString &section = QString());

    /**
     * @brief Returns the latest human-readable error message from KIO or Solid (empty if none).
     */
    QString lastErrorMessage() const;

    ZenSectionFilterProxy *essentialsModel() const;
    ZenSectionFilterProxy *workspacePlacesModel() const;
    ZenSectionFilterProxy *devicesModel() const;
    ZenSectionFilterProxy *trashModel() const;
    ZenTabsModel *tabsModel() const;
    ZenFolderTreeModel *treeModel() const;

    void initModels(ZenPlacesMasterModel *masterModel,
                    ZenNetworkPlacesModel *networkPlacesModel,
                    ZenSectionFilterProxy *essentialsProxy,
                    ZenSectionFilterProxy *workspaceProxy,
                    ZenSectionFilterProxy *devicesProxy,
                    ZenSectionFilterProxy *trashProxy,
                    ZenTabsModel *tabsModel,
                    ZenFolderTreeModel *treeModel);

    Q_INVOKABLE int essentialsCount() const;
    Q_INVOKABLE bool canAddEssential() const;
    Q_INVOKABLE QString essentialSlotText() const;

    /**
     * @brief Pre-flight check using KProtocolManager::supportsWriting (or unmounted device check) before accepting a file drop.
     */
    Q_INVOKABLE bool canAcceptDrop(const QUrl &targetUrl) const;

    /**
     * @brief Moves a workspace place from one visual proxy index to another.
     * @param fromProxyRow Source row index in the workspace places proxy model.
     * @param toProxyRow Target row index in the workspace places proxy model.
     * @param dropAfter If true, place is inserted after toProxyRow; if false, before toProxyRow.
     * @return True if the bookmark was successfully reordered, false otherwise.
     */
    Q_INVOKABLE bool moveWorkspacePlace(int fromProxyRow, int toProxyRow, bool dropAfter = false);

    /**
     * @brief Moves an essential tile from one visual proxy index to another and persists the custom order to KConfig.
     * @param fromProxyRow Source row index in the essentials proxy model.
     * @param toProxyRow Target row index in the essentials proxy model.
     * @return True if the essential was reordered, false otherwise.
     */
    Q_INVOKABLE bool moveEssential(int fromProxyRow, int toProxyRow);

    /**
     * @brief Adds a folder URL as a new bookmark to Workspace Places and optionally moves it to the target row.
     * @param url Folder URL to add.
     * @param targetProxyRow Optional target row index in Workspace Places (-1 to append at end).
     * @param dropAfter If true and targetProxyRow >= 0, inserts after targetProxyRow.
     * @return True if the place was added and persisted, false otherwise.
     */
    Q_INVOKABLE bool addPlaceFromUrl(const QUrl &url, int targetProxyRow = -1, bool dropAfter = false);

public Q_SLOTS:
    void openUrl(const QUrl &url);
    void openUrlInNewTab(const QUrl &url);
    void activateDevice(int proxyRow, bool inNewTab = false);
    void handleUrlDrop(const QUrl &targetUrl, const QList<QUrl> &droppedUrls, const QPoint &globalPos);
    void handleDeviceDrop(int deviceProxyRow, const QList<QUrl> &droppedUrls, const QPoint &globalPos);
    void clearErrorMessage();
    void reportError(const QString &message);

    void showEssentialsContextMenu(int proxyRow, const QPoint &globalPos);
    void showWorkspacePlaceContextMenu(int proxyRow, const QPoint &globalPos);
    void showWorkspaceBackgroundContextMenu(const QPoint &globalPos);
    void showPlacesContextMenu(int row, const QPoint &mousePos);
    void showTrashContextMenu(int row, const QPoint &globalPos);
    void showDevicesContextMenu(int row, const QPoint &globalPos);
    void showFolderContextMenu(const QUrl &url, const QPoint &globalPos);
    void addFolderToEssentials(const QUrl &url);
    void activateTab(int tabIndex, bool focusSecondary);
    void closeTab(int tabIndex);
    void requestTeardown(int row);
    void toggleDevicePin(int deviceProxyRow);
    void showTreeBackgroundContextMenu(const QUrl &rootUrl, const QPoint &globalPos);

Q_SIGNALS:
    void panelOrientationChanged();
    void devicesPinnedChanged();
    void expandNetworkFolderChanged();
    void highlightOpenTabPlacesChanged();
    void switchToExistingTabChanged();
    void maxEssentialsChanged();
    void showAddEssentialButtonChanged();
    void essentialsIconStyleChanged();
    void defaultWorkspaceViewChanged();
    void limitTreeToHomeChanged();
    void showHiddenFoldersInTreeChanged();
    void showTrashSectionChanged();
    void globalIconStyleChanged();
    void preferOutlineIconsChanged();
    void customSectionIconSizesChanged();
    void customSectionIconStylesChanged();
    void lookFeelModeChanged();
    void themeMetricsChanged();
    void placesIconSizeSettingChanged();
    void openSettingsRequested();
    void closeSettingsRequested();
    void keyboardNavigationActiveChanged();
    void touchInteractionActiveChanged();
    void activeSectionChanged();
    void focusedItemDescriptionChanged();
    void lastErrorMessageChanged();
    void navigateRequested(const QString &actionText, const QUrl &url);
    void urlActivated(const QUrl &url);
    void urlInNewTabActivated(const QUrl &url);

private:
    QModelIndex resolveMasterSourceIndex(QAbstractItemModel *proxyModel, int proxyRow) const;
    void editPlaceEntry(const QModelIndex &sourceIdx);
    void addNewPlaceEntry();
    void executeDropOnUrl(const QUrl &targetUrl, const QList<QUrl> &droppedUrls, const QPoint &globalPos);

    Qt::Orientation m_panelOrientation = Qt::Vertical;
    bool m_keyboardNavigationActive = false;
    bool m_touchInteractionActive = false;
    QString m_activeSection = QStringLiteral("essentials");
    QString m_focusedItemDescription;
    QString m_lastErrorMessage;

    QPersistentModelIndex m_pendingSetupClickIndex;
    bool m_pendingSetupNewTab = false;

    QPersistentModelIndex m_pendingSetupDropIndex;
    QList<QUrl> m_pendingDropUrls;
    QPoint m_pendingDropGlobalPos;

    ZenPlacesMasterModel *m_masterModel = nullptr;
    ZenNetworkPlacesModel *m_networkPlacesModel = nullptr;
    ZenSectionFilterProxy *m_essentialsModel = nullptr;
    ZenSectionFilterProxy *m_workspacePlacesModel = nullptr;
    ZenSectionFilterProxy *m_devicesModel = nullptr;
    ZenSectionFilterProxy *m_trashModel = nullptr;
    ZenTabsModel *m_tabsModel = nullptr;
    ZenFolderTreeModel *m_treeModel = nullptr;
    QPointer<QDialog> m_settingsDialog;
    int m_themeMetricsRevision = 0;
};
