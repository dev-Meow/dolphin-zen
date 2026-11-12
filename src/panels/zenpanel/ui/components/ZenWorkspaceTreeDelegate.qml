// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel

/**
 * @brief Native-first modular tree item delegate for WorkspaceTreeView, based on QQC2.TreeViewDelegate.
 *
 * Preserves native TreeViewDelegate properties (indicator, indentation, leftPadding, rightPadding)
 * while unifying background tab highlighting, ZenSectionIcon + Label content layout, and
 * Dolphin click/drag interactions with ZenPlaceListDelegate and ZenDeviceDelegate.
 */
QQC2.TreeViewDelegate {
    id: control

    // --- Injected dependencies ---
    property ZenPanelBridge bridge: null
    property ZenFolderTreeModel treeModel: null
    property ZenTabsModel tabsModel: null
    property Item verticalScrollBar: null

    // --- External / derived state flags ---
    readonly property string itemDisplay: (control.model && control.model.display !== undefined) ? control.model.display : ""
    readonly property var itemDecoration: (control.model && control.model.decoration !== undefined) ? control.model.decoration : "folder"
    readonly property url itemUrl: (control.treeModel && control.treeView && control.row >= 0) ? control.treeModel.urlForIndex(control.treeView.index(control.row, 0)) : ""
    readonly property bool isCurrentLocation: (control.tabsModel && control.tabsModel.revision >= 0 && control.itemUrl !== "") ? control.tabsModel.isUrlActive(control.itemUrl) : false
    readonly property bool isOpenInAnyTab: (control.tabsModel && control.tabsModel.revision >= 0 && control.itemUrl !== "") ? control.tabsModel.hasUrl(control.itemUrl) : false

    // --- Focus state ---
    readonly property bool isItemFocused: control.treeView && (control.treeView.currentRow === control.row) && control.treeView.activeFocus

    // --- Signals ---
    signal folderClicked(url folderUrl)
    signal folderMiddleClicked(url folderUrl)
    signal folderRightClicked(url folderUrl, point globalPos)
    signal folderUrlsDropped(url targetUrl, var droppedUrls, point globalPos)
    signal dragAutoScrollRequested(real globalY)
    signal dragAutoScrollStopped

    // --- Sizing & metrics ---
    readonly property int effectiveTreeIconSize: control.bridge ? control.bridge.treeIconSize : Kirigami.Units.iconSizes.smallMedium
    readonly property real effectiveIndentWidth: Math.max(control.leftPadding, control.leftMargin + (control.depth + 1) * control.indentation + control.spacing)
    topPadding: 0
    bottomPadding: 0
    implicitWidth: Math.ceil(control.effectiveIndentWidth + control.effectiveTreeIconSize + contentRow.spacing + textLabel.implicitWidth + control.rightPadding + Kirigami.Units.smallSpacing * 2)
    implicitHeight: Math.max(control.bridge ? control.bridge.treeRowHeight : 0, control.effectiveTreeIconSize + Kirigami.Units.smallSpacing, Math.round(Kirigami.Units.gridUnit * 1.35))

    onImplicitWidthChanged: {
        if (control.treeView && control.implicitWidth > control.treeView.contentWidth) {
            Qt.callLater(control.treeView.forceLayout);
        }
    }

    highlighted: control.current || control.selected || (control.treeView && control.treeView.currentRow === control.row)

    // Full accessibility support following KDE HIG
    Accessible.role: Accessible.ListItem
    Accessible.name: control.itemDisplay

    onIsItemFocusedChanged: {
        if (control.isItemFocused && control.bridge) {
            control.bridge.focusedItemDescription = control.itemDisplay;
        }
    }

    function triggerContextMenu(localX: real, localY: real) {
        if (control.treeView) {
            control.treeView.forceActiveFocus();
            const idx = control.treeView.index(control.row, 0);
            if (control.treeView.selectionModel) {
                control.treeView.selectionModel.setCurrentIndex(idx, ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Current);
            }
        }
        const globalPoint = control.mapToGlobal(localX + control.contentItem.x, localY + control.contentItem.y);
        control.folderRightClicked(control.itemUrl, Qt.point(Math.round(globalPoint.x), Math.round(globalPoint.y)));
    }

    // List/tree element background container (unified with ZenPlaceListDelegate & ZenDeviceDelegate)
    background: Rectangle {
        id: bgRect
        anchors.fill: parent
        anchors.margins: 1
        radius: control.bridge ? control.bridge.itemRadius : Kirigami.Units.cornerRadius

        color: {
            if (dropArea.containsDrag) {
                return Qt.alpha(Kirigami.Theme.focusColor, 0.25);
            }
            if (control.down || leftTapHandler.pressed) {
                return Qt.alpha(Kirigami.Theme.focusColor, 0.35);
            }
            if (control.isItemFocused) {
                return Qt.alpha(Kirigami.Theme.focusColor, 0.12);
            }
            if (control.hovered) {
                return Kirigami.Theme.hoverColor;
            }
            if (control.isCurrentLocation) {
                return Qt.alpha(Kirigami.Theme.highlightColor, 0.16);
            }
            if (control.isOpenInAnyTab) {
                return Qt.alpha(Kirigami.Theme.highlightColor, 0.08);
            }
            if (control.highlighted) {
                return Qt.alpha(Kirigami.Theme.highlightColor, 0.12);
            }
            return "transparent";
        }

        border.color: (control.isItemFocused || dropArea.containsDrag) ? Qt.alpha(Kirigami.Theme.focusColor, 0.65) : "transparent"
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.OutQuad
            }
        }

        // Left accent bar indicating the active location
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            radius: 1.5
            color: Kirigami.Theme.highlightColor
            opacity: 0.7
            visible: control.isCurrentLocation
        }
    }

    // Visual content: Icon + Title (unified with ZenPlaceListDelegate & ZenDeviceDelegate)
    contentItem: RowLayout {
        id: contentRow
        LayoutMirroring.enabled: control.mirrored
        spacing: control.bridge ? control.bridge.lateralMargin : Kirigami.Units.smallSpacing

        // Preserve native truncation tooltip compatibility in org.kde.desktop
        property alias truncated: textLabel.truncated

        ZenSectionIcon {
            Layout.preferredWidth: control.effectiveTreeIconSize
            Layout.preferredHeight: control.effectiveTreeIconSize
            Layout.alignment: Qt.AlignVCenter
            // Fallback for QQC2 styles (e.g. org.kde.union) that skip the invisible indicator slot when !hasChildren
            Layout.leftMargin: (!control.hasChildren && contentRow.x < (control.depth + 1) * control.indentation)
                ? ((control.indicator && control.indicator.implicitWidth > 0 ? control.indicator.implicitWidth : control.indentation) + control.spacing)
                : 0
            bridge: control.bridge
            section: "tree"
            iconName: control.itemDecoration
            fallbackIcon: "folder"
            highlighted: control.isCurrentLocation || control.isItemFocused
        }

        QQC2.Label {
            id: textLabel
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.rightMargin: Kirigami.Units.smallSpacing
            text: control.itemDisplay
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            color: Kirigami.Theme.textColor
            font.weight: control.isCurrentLocation ? Font.DemiBold : Font.Normal
        }
    }

    // Primary Left-Click / Tap interaction on folder content (from icon to right panel edge, excluding expander indicator)
    TapHandler {
        id: leftTapHandler
        parent: control.contentItem
        acceptedButtons: Qt.LeftButton
        onTapped: function (eventPoint) {
            // Suppress Shift + single-click (non-standard in Dolphin); Shift + double-click toggles expansion below
            if (eventPoint.modifiers & Qt.ShiftModifier) {
                return;
            }
            if (control.treeView) {
                control.treeView.forceActiveFocus();
                const idx = control.treeView.index(control.row, 0);
                if (control.treeView.selectionModel) {
                    control.treeView.selectionModel.setCurrentIndex(idx, ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Current);
                }
                control.treeView.positionViewAtRow(control.row, TableView.Contain);
            }
            if (control.bridge) {
                if (eventPoint.device.type === PointerDevice.TouchScreen) {
                    control.bridge.notifyTouchInteraction("workspace");
                } else {
                    control.bridge.notifyMouseInteraction("workspace");
                }
            }
            if (eventPoint.modifiers & Qt.ControlModifier) {
                control.folderMiddleClicked(control.itemUrl);
            } else {
                control.folderClicked(control.itemUrl);
            }
        }
        onDoubleTapped: function (eventPoint) {
            // KDE / Dolphin convention: Shift + double-click expands/collapses the tree node without navigating
            if ((eventPoint.modifiers & Qt.ShiftModifier) && control.treeView && control.hasChildren) {
                control.treeView.toggleExpanded(control.row);
            }
        }
    }

    // Middle-click: Open in new tab (Mouse / TouchPad only)
    TapHandler {
        parent: control.contentItem
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            if (control.treeView) {
                control.treeView.forceActiveFocus();
            }
            if (control.bridge) {
                control.bridge.notifyMouseInteraction("workspace");
            }
            control.folderMiddleClicked(control.itemUrl);
        }
    }

    // Right-click: Open tree context menu (Mouse / TouchPad / Stylus)
    TapHandler {
        parent: control.contentItem
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        acceptedButtons: Qt.RightButton
        onTapped: function (eventPoint) {
            control.triggerContextMenu(eventPoint.position.x, eventPoint.position.y);
        }
    }

    // Touch press-and-hold (long-press): Open tree context menu on touchscreens
    TapHandler {
        parent: control.contentItem
        acceptedDevices: PointerDevice.TouchScreen
        gesturePolicy: TapHandler.WithinBounds
        onLongPressed: {
            control.triggerContextMenu(point.position.x, point.position.y);
        }
    }

    // External file drop handler (Dolphin file drops + hover auto-expand)
    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list"]

        onPositionChanged: function (drag) {
            const globalPt = control.mapToGlobal(drag.x, drag.y);
            control.dragAutoScrollRequested(globalPt.y);
        }

        onEntered: function (drag) {
            if (control.treeView && !control.treeView.isExpanded(control.row)) {
                autoExpandTimer.restart();
            }
        }

        onExited: {
            autoExpandTimer.stop();
            control.dragAutoScrollStopped();
        }

        onDropped: function (drop) {
            autoExpandTimer.stop();
            control.dragAutoScrollStopped();
            if (drop.hasUrls && drop.urls.length > 0 && control.treeView && control.treeModel) {
                const idx = control.treeView.index(control.row, 0);
                const targetUrl = control.treeModel.urlForIndex(idx);
                const globalPt = control.mapToGlobal(drop.x, drop.y);
                control.folderUrlsDropped(targetUrl, drop.urls, Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
                drop.acceptProposedAction();
            }
        }

        Timer {
            id: autoExpandTimer
            interval: 750
            repeat: false
            onTriggered: {
                if (dropArea.containsDrag && control.treeView && !control.treeView.isExpanded(control.row)) {
                    control.treeView.expand(control.row);
                }
            }
        }
    }
}
