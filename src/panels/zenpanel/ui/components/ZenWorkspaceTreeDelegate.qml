// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel

/**
 * @brief Modular tree item delegate for WorkspaceTreeView, based on QQC2.TreeViewDelegate.
 *
 * Provides Breeze-compliant row layout, modern Pointer HoverHandler,
 * active tab/location pill indicators, and reliable focus rectangle integration.
 */
QQC2.TreeViewDelegate {
    id: control

    // --- Injected dependencies ---
    property ZenPanelBridge bridge: null
    property ZenFolderTreeModel treeModel: null
    property ZenTabsModel tabsModel: null
    property Item verticalScrollBar: null

    // --- State and URL helpers ---
    readonly property url itemUrl: (control.treeModel && control.treeView && control.row >= 0) ? control.treeModel.urlForIndex(control.treeView.index(control.row, 0)) : ""
    readonly property bool isCurrentLocation: (control.tabsModel && control.tabsModel.revision >= 0 && control.itemUrl !== "") ? control.tabsModel.isUrlActive(control.itemUrl) : false
    readonly property bool isOpenInAnyTab: (control.tabsModel && control.tabsModel.revision >= 0 && control.itemUrl !== "") ? control.tabsModel.hasUrl(control.itemUrl) : false
    readonly property bool isItemFocused: control.treeView && (control.treeView.currentRow === control.row) && control.treeView.activeFocus

    // --- Signals forwarded to tree view / controller ---
    signal folderClicked(url folderUrl)
    signal folderMiddleClicked(url folderUrl)
    signal folderRightClicked(url folderUrl, point globalPos)
    signal folderUrlsDropped(url targetUrl, var droppedUrls, point globalPos)
    signal dragAutoScrollRequested(real globalY)
    signal dragAutoScrollStopped()

    // Reserve space on the right for the slim ZenScrollBar handle so rows never shift or collide
    implicitWidth: Math.max(Math.max(0, (control.treeView ? control.treeView.width : 0) - (control.verticalScrollBar ? control.verticalScrollBar.implicitWidth : 0) - 2), contentRow.implicitWidth + leftPadding + rightPadding + Kirigami.Units.smallSpacing)
    implicitHeight: control.bridge ? control.bridge.treeRowHeight : Math.round(Kirigami.Units.gridUnit * 1.35)

    highlighted: control.current || control.selected || (control.treeView && control.treeView.currentRow === control.row)

    onIsItemFocusedChanged: {
        if (control.isItemFocused && control.bridge) {
            const idx = control.treeView.index(control.row, 0);
            const name = control.treeModel ? control.treeModel.data(idx, Qt.DisplayRole) : "";
            control.bridge.focusedItemDescription = name;
        }
    }

    contentItem: RowLayout {
        id: contentRow
        spacing: control.bridge ? control.bridge.lateralMargin : Kirigami.Units.smallSpacing

        // Spacer preserving vertical alignment for leaf nodes that lack an expand indicator
        Item {
            visible: control.isTreeNode && !control.hasChildren
            Layout.preferredWidth: (control.indicator && control.indicator.implicitWidth > 0)
                                   ? control.indicator.implicitWidth
                                   : Math.round(Kirigami.Units.smallSpacing * 2.2)
            Layout.preferredHeight: 1
        }

        ZenSectionIcon {
            Layout.preferredWidth: control.bridge ? control.bridge.treeIconSize : Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            bridge: control.bridge
            section: "tree"
            iconName: "folder"
            fallbackIcon: "folder"
            highlighted: control.isCurrentLocation || control.isItemFocused
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: {
                if (control.text && control.text.length > 0) {
                    return control.text;
                }
                if (!control.treeView || !control.treeModel) {
                    return "";
                }
                const idx = control.treeView.index(control.row, 0);
                return control.treeModel.data(idx, Qt.DisplayRole);
            }
            verticalAlignment: Text.AlignVCenter
            color: (control.highlighted && control.isItemFocused) ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            font.weight: control.isCurrentLocation ? Font.DemiBold : Font.Normal
        }
    }

    background: Rectangle {
        radius: control.bridge ? control.bridge.itemRadius : Kirigami.Units.cornerRadius
        color: {
            if (rowDropArea.containsDrag) {
                return Qt.alpha(Kirigami.Theme.focusColor, 0.25);
            }
            if (mouseArea.containsPress) {
                return Qt.alpha(Kirigami.Theme.focusColor, 0.35);
            }
            if (control.isItemFocused) {
                return Qt.alpha(Kirigami.Theme.focusColor, 0.12);
            }
            if (rowHoverHandler.hovered) {
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

        border.color: (control.isItemFocused || rowDropArea.containsDrag) ? Qt.alpha(Kirigami.Theme.focusColor, 0.65) : "transparent"
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.OutQuad
            }
        }

        // Active location indicator pill matching KFilePlacesView / ZenPlaceListDelegate standard
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

    // Modern pointer hover detection decoupled from mouse button clicks
    HoverHandler {
        id: rowHoverHandler
    }

    // Pointer interaction on the row content (excluding the branch indicator arrow on the left,
    // which remains handled directly by TreeViewDelegate to toggle expansion):
    // - Shift + Left-Click: only expand/collapse the node without opening the folder (Dolphin FoldersPanel behavior)
    // - Ctrl + Left-Click or Middle-Click: open folder in a new tab
    // - Normal Left-Click: open folder in active view
    // - Right-Click: open TreeView context menu
    MouseArea {
        id: mouseArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        x: control.indicator && control.indicator.visible ? (control.indicator.x + control.indicator.width) : 0
        width: Math.max(0, parent.width - x)
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onPressed: {
            if (control.bridge) {
                control.bridge.notifyMouseInteraction("workspace");
            }
        }

        onClicked: function (mouse) {
            if (control.treeView) {
                control.treeView.forceActiveFocus();
                const idx = control.treeView.index(control.row, 0);
                if (control.treeView.selectionModel) {
                    control.treeView.selectionModel.setCurrentIndex(idx, ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Current);
                }
                control.treeView.positionViewAtRow(control.row, TableView.Contain);

                const url = control.itemUrl;
                if (mouse.button === Qt.LeftButton) {
                    if (mouse.modifiers & Qt.ShiftModifier) {
                        control.treeView.toggleExpanded(control.row);
                    } else if (mouse.modifiers & Qt.ControlModifier) {
                        control.folderMiddleClicked(url);
                    } else {
                        control.folderClicked(url);
                    }
                } else if (mouse.button === Qt.MiddleButton) {
                    control.folderMiddleClicked(url);
                } else if (mouse.button === Qt.RightButton) {
                    const globalPoint = control.mapToGlobal(mouse.x + x, mouse.y);
                    control.folderRightClicked(url, Qt.point(Math.round(globalPoint.x), Math.round(globalPoint.y)));
                }
            }
        }
    }

    DropArea {
        id: rowDropArea
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
                if (rowDropArea.containsDrag && control.treeView && !control.treeView.isExpanded(control.row)) {
                    control.treeView.expand(control.row);
                }
            }
        }
    }
}

