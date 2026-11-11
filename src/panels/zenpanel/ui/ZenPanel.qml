// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel
import "components"
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

    function focusInitialItem() {
        if (root.bridge) {
            root.bridge.notifyKeyboardInteraction();
        }
        if (essentialsSection.visible && root.essentialsModel && root.essentialsModel.rowCount() > 0) {
            essentialsSection.focusTileAt(0);
        } else {
            workspaceSection.focusFirstItem();
        }
    }

    onActiveFocusChanged: {
        if (activeFocus && !root.hasActiveChildFocus(root)) {
            root.focusInitialItem();
        }
    }

    Keys.onPressed: function(event) {
        if (root.bridge) {
            root.bridge.notifyKeyboardInteraction();
        }

        if (event.key === Qt.Key_Backtab) {
            if (essentialsSection.hasActiveTileFocus() || essentialsSection.activeFocus
                || (!essentialsSection.visible && workspaceSection.activeFocus)) {
                if (root.bridge) {
                    root.bridge.focusPreviousWidget();
                }
                event.accepted = true;
                return;
            }
        }

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
    // Main orchestrator layout: dynamically Vertical (1 column) / Horizontal (1 row)
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

        // 1. Top/Left: Essentials tile grid (3.1)
        EssentialsSection {
            id: essentialsSection
            bridge: root.bridge
            maxEssentials: root.bridge ? root.bridge.maxEssentials : 12
            showAddButton: root.bridge ? root.bridge.showAddEssentialButton : true
            Layout.fillWidth: root.isVertical
            Layout.fillHeight: !root.isVertical
            Layout.preferredWidth: root.isVertical ? -1 : (root.bridge ? root.bridge.horizontalEssentialsWidth : Kirigami.Units.gridUnit * 12)
            Layout.minimumWidth: root.isVertical ? -1 : (root.bridge ? (root.bridge.essentialsTileWidth + Kirigami.Units.smallSpacing * 2) : 56)
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

        // Section separator & interactive splitter between Essentials and Workspace
        ZenSectionSplitter {
            id: essentialsSplitter
            isVertical: root.isVertical
            canResizeHorizontal: root.bridge && !root.bridge.panelsLocked && !root.isVertical

            property int startWidth: 0

            onResizeStarted: {
                startWidth = root.bridge ? root.bridge.horizontalEssentialsWidth : Kirigami.Units.gridUnit * 12;
            }
            onResizeMoved: function (delta) {
                if (root.bridge) {
                    const minW = Math.max((root.bridge.essentialsTileWidth + Kirigami.Units.smallSpacing * 2), 56);
                    const maxW = Math.min(Math.round(root.width * 0.45), Kirigami.Units.gridUnit * 24);
                    root.bridge.horizontalEssentialsWidth = Math.max(minW, Math.min(maxW, startWidth + delta));
                }
            }
            onResizeFinished: {
                if (root.bridge) {
                    root.bridge.saveSectionSizes();
                }
            }
        }

        // 2. Center: Flexible workspace section (3.2) - fills remaining space
        WorkspaceSection {
            id: workspaceSection
            bridge: root.bridge
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: root.isVertical ? -1 : Kirigami.Units.gridUnit * 10
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

        // Section separator & interactive splitter between Workspace and Devices
        ZenSectionSplitter {
            id: devicesSplitter
            isVertical: root.isVertical
            canResizeVertical: root.bridge && !root.bridge.panelsLocked && root.isVertical && devicesSection.effectivePinned
            canResizeHorizontal: root.bridge && !root.bridge.panelsLocked && !root.isVertical

            property int startDimension: 0

            onResizeStarted: function (vertical) {
                if (vertical) {
                    startDimension = root.bridge ? root.bridge.devicesSectionHeight : Kirigami.Units.gridUnit * 10;
                } else {
                    startDimension = root.bridge ? root.bridge.horizontalDevicesWidth : Kirigami.Units.gridUnit * 12;
                }
            }
            onResizeMoved: function (delta, vertical) {
                if (!root.bridge) {
                    return;
                }
                if (vertical) {
                    // Dragging upwards (negative delta) increases devices height
                    const minH = Math.round(Kirigami.Units.gridUnit * 3.5);
                    const maxH = Math.min(Math.round(root.height * 0.5), Kirigami.Units.gridUnit * 22);
                    root.bridge.devicesSectionHeight = Math.max(minH, Math.min(maxH, startDimension - delta));
                } else {
                    // Dragging leftwards (negative delta) increases devices width
                    const minW = Math.round(Kirigami.Units.gridUnit * 10);
                    const maxW = Math.min(Math.round(root.width * 0.45), Kirigami.Units.gridUnit * 24);
                    root.bridge.horizontalDevicesWidth = Math.max(minW, Math.min(maxW, startDimension - delta));
                }
            }
            onResizeFinished: {
                if (root.bridge) {
                    root.bridge.saveSectionSizes();
                }
            }
        }

        // 3. Bottom/Right: Devices & Network section (3.3) - z: 10 so its unpinned hover overlay floats above WorkspaceSection
        DevicesSection {
            id: devicesSection
            z: 10
            bridge: root.bridge
            Layout.fillWidth: root.isVertical
            Layout.fillHeight: !root.isVertical
            Layout.preferredHeight: root.isVertical
                ? (devicesSection.effectivePinned ? Math.min(devicesSection.targetSurfaceHeight, root.bridge ? root.bridge.devicesSectionHeight : Kirigami.Units.gridUnit * 10) : devicesSection.inLayoutHeight)
                : -1
            Layout.preferredWidth: root.isVertical ? -1 : (root.bridge ? root.bridge.horizontalDevicesWidth : Kirigami.Units.gridUnit * 12)
            Layout.minimumWidth: root.isVertical ? -1 : Kirigami.Units.gridUnit * 10
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

        // 4. Dedicated trash section pinned to bottom or outer edge
        TrashSection {
            id: trashSection
            bridge: root.bridge
            isHorizontal: !root.isVertical
            visible: root.bridge ? root.bridge.showTrashSection : true
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: root.isVertical
            Layout.fillHeight: false
            Layout.preferredWidth: root.isVertical ? -1 : trashSection.implicitWidth
            Layout.preferredHeight: trashSection.implicitHeight
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
