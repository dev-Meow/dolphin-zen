pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel
import "sections"
import "sections/workspace"

Rectangle {
    id: root
    color: Kirigami.Theme.backgroundColor

    // Use Window colorSet (matches Dolphin dock widget background and settings dialog palette)
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    // Size constraints:
    // Vertical: 220px standard width, minimum 140px (Dolphin sidebar min), maximum 600px
    implicitWidth: root.isVertical ? 220 : -1
    implicitHeight: root.isVertical ? -1 : 120
    Layout.minimumWidth: root.isVertical ? 140 : -1
    Layout.maximumWidth: root.isVertical ? 600 : -1
    Layout.preferredWidth: root.isVertical ? 220 : -1

    // --- Host bridge (injected from C++ host via setInitialProperties) ---
    required property ZenPanelBridge bridge

    // --- Models provided by the C++ bridge ---
    readonly property ZenSectionFilterProxy essentialsModel: root.bridge.essentialsModel
    readonly property ZenSectionFilterProxy workspacePlacesModel: root.bridge.workspacePlacesModel
    readonly property ZenSectionFilterProxy devicesModel: root.bridge.devicesModel
    readonly property ZenSectionFilterProxy trashModel: root.bridge.trashModel
    readonly property ZenTabsModel tabsModel: root.bridge.tabsModel
    readonly property ZenFolderTreeModel treeModel: root.bridge.treeModel

    readonly property bool isVertical: root.bridge.panelOrientation === Qt.Vertical

    focus: true

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            return;
        }

        // If no child currently has activeFocus, focus initial item
        if (!root.hasActiveChildFocus(root)) {
            workspaceSection.focusFirstItem();
            event.accepted = true;
        }
    }

    function hasActiveChildFocus(item: Item): bool {
        if (!item) return false;
        if (item !== root && item.activeFocus) return true;
        for (let i = 0; i < item.children.length; ++i) {
            const child = item.children[i] as Item;
            if (child && root.hasActiveChildFocus(child)) {
                return true;
            }
        }
        return false;
    }

    onIsVerticalChanged: {
        // Automatically pin the Devices section when docking horizontally (top/bottom)
        if (!root.isVertical && !root.bridge.devicesPinned) {
            root.bridge.devicesPinned = true;
        }
    }

    // =========================================================================
    // Haupt-Orchestrator Layout: Dynamisch Vertikal (1 Spalte) / Horizontal (1 Zeile)
    // =========================================================================
    GridLayout {
        id: mainLayout
        anchors.fill: parent
        flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Kirigami.Units.smallSpacing
        columnSpacing: Kirigami.Units.smallSpacing

        // 0. Optional KIO / Solid error message banner (Safe-Use feedback)
        Kirigami.InlineMessage {
            id: errorBanner
            Layout.fillWidth: root.isVertical
            Layout.fillHeight: !root.isVertical
            Layout.margins: Kirigami.Units.smallSpacing
            type: Kirigami.MessageType.Error
            text: root.bridge.lastErrorMessage
            visible: root.bridge.lastErrorMessage.length > 0
            showCloseButton: true

            onVisibleChanged: {
                if (!visible && root.bridge.lastErrorMessage.length > 0) {
                    root.bridge.clearErrorMessage();
                }
            }
        }

        // 1. Oben/Links: Essentials-Kachel-Grid (3.1)
        EssentialsSection {
            id: essentialsSection
            bridge: root.bridge
            maxEssentials: root.bridge ? root.bridge.maxEssentials : 12
            showAddButton: root.bridge ? root.bridge.showAddEssentialButton : true
            Layout.fillWidth: root.isVertical
            Layout.fillHeight: !root.isVertical
            Layout.preferredWidth: root.isVertical ? -1 : Kirigami.Units.gridUnit * 12
            essentialsModel: root.essentialsModel
            tabsModel: root.tabsModel
            highlightOpenTabPlaces: root.bridge ? root.bridge.highlightOpenTabPlaces : true

            onPlaceClicked: function(placeUrl) {
                root.bridge.openUrl(placeUrl);
            }
            onPlaceMiddleClicked: function(placeUrl) {
                root.bridge.openUrlInNewTab(placeUrl);
            }
            onPlaceRightClicked: function(row, mousePos) {
                root.bridge.showEssentialsContextMenu(row, mousePos);
            }
            onPlaceUrlsDropped: function(targetUrl, droppedUrls, globalPos) {
                root.bridge.handleUrlDrop(targetUrl, droppedUrls, globalPos);
            }
            onAddUrlDropped: function(folderUrl) {
                root.bridge.addFolderToEssentials(folderUrl);
            }
            onAddClicked: {
                if (root.tabsModel) {
                    root.bridge.addFolderToEssentials(root.tabsModel.activeUrl);
                }
            }
        }

        // Subtle section separator (adapts automatically to vertical/horizontal panel orientation)
        Kirigami.Separator {
            Layout.fillWidth: root.isVertical
            Layout.fillHeight: !root.isVertical
            Layout.leftMargin: root.isVertical ? Kirigami.Units.smallSpacing : 0
            Layout.rightMargin: root.isVertical ? Kirigami.Units.smallSpacing : 0
            Layout.topMargin: root.isVertical ? 0 : Kirigami.Units.smallSpacing
            Layout.bottomMargin: root.isVertical ? 0 : Kirigami.Units.smallSpacing
            weight: Kirigami.Separator.Weight.Light
        }

        // 2. Center: Flexible workspace section (3.2) - fills remaining space
        WorkspaceSection {
            id: workspaceSection
            bridge: root.bridge
            Layout.fillWidth: true
            Layout.fillHeight: true
            placesModel: root.workspacePlacesModel
            tabsModel: root.tabsModel
            treeModel: root.treeModel
            highlightOpenTabPlaces: root.bridge.highlightOpenTabPlaces

            onPlaceClicked: function(placeUrl) {
                root.bridge.openUrl(placeUrl);
            }
            onPlaceMiddleClicked: function(placeUrl) {
                root.bridge.openUrlInNewTab(placeUrl);
            }
            onPlaceRightClicked: function(row, mousePos) {
                root.bridge.showWorkspacePlaceContextMenu(row, mousePos);
            }
            onPlaceUrlsDropped: function(targetUrl, droppedUrls, globalPos) {
                root.bridge.handleUrlDrop(targetUrl, droppedUrls, globalPos);
            }
            onPlacesBackgroundRightClicked: function(globalPos) {
                root.bridge.showWorkspaceBackgroundContextMenu(globalPos);
            }
            onFolderRightClicked: function(folderUrl, globalPos) {
                root.bridge.showFolderContextMenu(folderUrl, globalPos);
            }
            onTreeBackgroundRightClicked: function(rootUrl, globalPos) {
                root.bridge.showTreeBackgroundContextMenu(rootUrl, globalPos);
            }
        }

        // Subtle section separator (adapts automatically to vertical/horizontal panel orientation)
        Kirigami.Separator {
            Layout.fillWidth: root.isVertical
            Layout.fillHeight: !root.isVertical
            Layout.leftMargin: root.isVertical ? Kirigami.Units.smallSpacing : 0
            Layout.rightMargin: root.isVertical ? Kirigami.Units.smallSpacing : 0
            Layout.topMargin: root.isVertical ? 0 : Kirigami.Units.smallSpacing
            Layout.bottomMargin: root.isVertical ? 0 : Kirigami.Units.smallSpacing
            weight: Kirigami.Separator.Weight.Light
        }

        // 3. Bottom/Right: Devices & Network section (3.3) - z: 10 so its unpinned hover overlay floats above WorkspaceSection
        DevicesSection {
            id: devicesSection
            z: 10
            bridge: root.bridge
            Layout.fillWidth: root.isVertical
            Layout.fillHeight: !root.isVertical
            Layout.preferredWidth: root.isVertical ? -1 : Kirigami.Units.gridUnit * 12
            devicesModel: root.devicesModel
            tabsModel: root.tabsModel
            isPinned: root.bridge.devicesPinned
            isHorizontal: !root.isVertical
            highlightOpenTabPlaces: root.bridge.highlightOpenTabPlaces

            onPinToggled: function(pinned) {
                root.bridge.devicesPinned = pinned;
            }
            onDevicePinToggled: function(row) {
                root.bridge.toggleDevicePin(row);
            }
            onDeviceClicked: function(row) {
                root.bridge.activateDevice(row, false);
            }
            onDeviceMiddleClicked: function(row) {
                root.bridge.activateDevice(row, true);
            }
            onDeviceRightClicked: function(row, mousePos) {
                root.bridge.showDevicesContextMenu(row, mousePos);
            }
            onDeviceUrlsDropped: function(row, droppedUrls, globalPos) {
                root.bridge.handleDeviceDrop(row, droppedUrls, globalPos);
            }
        }

        // Subtle section separator before trash
        Kirigami.Separator {
            visible: root.bridge ? root.bridge.showTrashSection : true
            Layout.fillWidth: root.isVertical
            Layout.fillHeight: !root.isVertical
            Layout.leftMargin: root.isVertical ? Kirigami.Units.smallSpacing : 0
            Layout.rightMargin: root.isVertical ? Kirigami.Units.smallSpacing : 0
            Layout.topMargin: root.isVertical ? 0 : Kirigami.Units.smallSpacing
            Layout.bottomMargin: root.isVertical ? 0 : Kirigami.Units.smallSpacing
            weight: Kirigami.Separator.Weight.Light
        }

        // 4. Fixierter Papierkorb ganz unten/rechts außen (3.4)
        TrashSection {
            id: trashSection
            bridge: root.bridge
            isHorizontal: !root.isVertical
            visible: root.bridge ? root.bridge.showTrashSection : true
            Layout.fillWidth: root.isVertical
            Layout.fillHeight: !root.isVertical
            Layout.preferredWidth: root.isVertical ? -1 : (root.bridge ? root.bridge.essentialsTileWidth : Math.round(Kirigami.Units.gridUnit * 2.5))
            trashModel: root.trashModel
            tabsModel: root.tabsModel
            highlightOpenTabPlaces: root.bridge.highlightOpenTabPlaces

            onTrashClicked: function(trashUrl) {
                root.bridge.openUrl(trashUrl);
            }
            onTrashMiddleClicked: function(trashUrl) {
                root.bridge.openUrlInNewTab(trashUrl);
            }
            onTrashRightClicked: function(row, mousePos) {
                root.bridge.showTrashContextMenu(row, mousePos);
            }
            onTrashUrlsDropped: function(trashUrl, droppedUrls, globalPos) {
                root.bridge.handleUrlDrop(trashUrl, droppedUrls, globalPos);
            }
        }
    }
}
