// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQml.Models
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel
import "../../components"

Item {
    id: root

    required property ZenFolderTreeModel treeModel
    property ZenTabsModel tabsModel: null
    property ZenPanelBridge bridge: null

    signal folderClicked(url folderUrl)
    signal folderMiddleClicked(url folderUrl)
    signal folderRightClicked(url folderUrl, point globalPos)
    signal folderUrlsDropped(url targetUrl, var droppedUrls, point globalPos)
    signal backgroundRightClicked(url rootUrl, point globalPos)

    function focusFirstFolder() {
        if (treeView.rows > 0) {
            if (treeView.currentRow < 0) {
                treeSelectionModel.setCurrentIndex(treeView.index(0, 0), ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Current);
            }
            treeView.forceActiveFocus();
        }
    }

    implicitWidth: Kirigami.Units.gridUnit * 10
    implicitHeight: Kirigami.Units.gridUnit * 15

    // --- Smooth auto-scroll during drag near top/bottom edges ---
    property int autoScrollSpeed: 0 // < 0: scroll up, > 0: scroll down, 0: idle

    function updateDragAutoScroll(globalY: real) {
        const localPt = treeView.mapFromGlobal(0, globalY);
        const y = localPt.y;
        const margin = Math.round(Kirigami.Units.gridUnit * 2.0); // ~36px edge zone

        if (y >= 0 && y < margin) {
            // Near top edge: scroll up progressively
            const factor = 1.0 - (y / margin);
            root.autoScrollSpeed = -Math.round(3 + factor * 10);
        } else if (y > treeView.height - margin && y <= treeView.height + 10) {
            // Near bottom edge: scroll down progressively
            const factor = Math.min(1.0, (y - (treeView.height - margin)) / margin);
            root.autoScrollSpeed = Math.round(3 + factor * 10);
        } else {
            root.autoScrollSpeed = 0;
        }
    }

    function stopDragAutoScroll() {
        root.autoScrollSpeed = 0;
    }

    Timer {
        id: autoScrollTimer
        interval: 16 // 60 fps
        repeat: true
        running: root.autoScrollSpeed !== 0
        onTriggered: {
            if (root.autoScrollSpeed !== 0) {
                const maxContentY = Math.max(0, treeView.contentHeight - treeView.height);
                const newY = Math.max(0, Math.min(maxContentY, treeView.contentY + root.autoScrollSpeed));
                treeView.contentY = newY;
                verticalScrollBar.revealTemporarily();
            }
        }
    }

    // Detect mouse hover & pointer movement over the tree view to reveal auto-fading scrollbars
    HoverHandler {
        id: sectionHoverHandler
        onPointChanged: {
            if (hovered) {
                if (root.bridge) {
                    root.bridge.notifyMouseHoverSection("workspace");
                }
                verticalScrollBar.revealTemporarily();
                horizontalScrollBar.revealTemporarily();
            }
        }
    }

    // Right-click on empty viewport area
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.RightButton
        onClicked: function (mouse) {
            const globalPoint = mapToGlobal(mouse.x, mouse.y);
            root.backgroundRightClicked(root.treeModel.rootUrl, Qt.point(globalPoint.x, globalPoint.y));
        }
    }

    // Drop area on empty viewport background (auto-scroll & drop onto root folder)
    DropArea {
        id: treeBackgroundDropArea
        anchors.fill: parent
        z: 0
        keys: ["text/uri-list"]

        onPositionChanged: function (drag) {
            const globalPt = mapToGlobal(drag.x, drag.y);
            root.updateDragAutoScroll(globalPt.y);
        }

        onExited: {
            root.stopDragAutoScroll();
        }

        onDropped: function (drop) {
            root.stopDragAutoScroll();
            if (drop.hasUrls && drop.urls.length > 0) {
                const globalPt = mapToGlobal(drop.x, drop.y);
                root.folderUrlsDropped(root.treeModel.rootUrl, drop.urls, Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
                drop.acceptProposedAction();
            }
        }
    }

    TreeView {
        id: treeView
        anchors.fill: parent
        z: 1
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.treeModel
        focus: true
        activeFocusOnTab: true
        keyNavigationEnabled: true

        QQC2.ScrollBar.vertical: ZenScrollBar {
            id: verticalScrollBar
            parent: treeView
            x: treeView.width - width
            y: 0
            height: treeView.height
            orientation: Qt.Vertical
            sectionHovered: sectionHoverHandler.hovered
            sectionFocused: treeView.activeFocus
        }

        QQC2.ScrollBar.horizontal: ZenScrollBar {
            id: horizontalScrollBar
            parent: treeView
            x: 0
            y: treeView.height - height
            width: treeView.width - verticalScrollBar.width
            orientation: Qt.Horizontal
            sectionHovered: sectionHoverHandler.hovered
            sectionFocused: treeView.activeFocus
        }

        ZenWheelScroller {
            flickable: treeView
            bridge: root.bridge
            rowHeight: root.bridge ? root.bridge.treeRowHeight : 24
            onScrolled: verticalScrollBar.revealTemporarily()
        }

        onContentYChanged: {
            verticalScrollBar.revealTemporarily();
        }

        onContentXChanged: {
            horizontalScrollBar.revealTemporarily();
        }

        selectionModel: ItemSelectionModel {
            id: treeSelectionModel
            model: treeView.model
        }

        onActiveFocusChanged: {
            if (activeFocus) {
                verticalScrollBar.revealTemporarily();
                horizontalScrollBar.revealTemporarily();
                if (treeView.currentRow < 0 && treeView.rows > 0) {
                    treeSelectionModel.setCurrentIndex(treeView.index(0, 0), ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Current);
                }
            }
        }

        onMovementStarted: {
            if (root.bridge && (treeView.dragging || treeView.flicking)) {
                root.bridge.notifyTouchInteraction("workspace");
            }
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Tab) {
                const next = treeView.nextItemInFocusChain(true);
                if (next) {
                    next.forceActiveFocus();
                    event.accepted = true;
                    return;
                }
            } else if (event.key === Qt.Key_Backtab) {
                const prev = treeView.nextItemInFocusChain(false);
                if (prev) {
                    prev.forceActiveFocus();
                    event.accepted = true;
                    return;
                }
            }
            if (root.bridge) {
                root.bridge.notifyKeyboardInteraction();
            }
            verticalScrollBar.revealTemporarily();
            horizontalScrollBar.revealTemporarily();
            if (treeView.rows <= 0) {
                return;
            }

            // Ensure a valid current row exists when starting keyboard navigation
            if (treeView.currentRow < 0) {
                treeSelectionModel.setCurrentIndex(treeView.index(0, 0), ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Current);
            }

            const row = treeView.currentRow;
            if (row < 0) {
                return;
            }

            if (event.key === Qt.Key_Right) {
                if (!treeView.isExpanded(row)) {
                    treeView.expand(row);
                    event.accepted = true;
                } else if (row + 1 < treeView.rows && treeView.depth(row + 1) > treeView.depth(row)) {
                    const childIdx = treeView.index(row + 1, 0);
                    treeSelectionModel.setCurrentIndex(childIdx, ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Current);
                    treeView.positionViewAtRow(row + 1, TableView.Contain);
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Left) {
                if (treeView.isExpanded(row)) {
                    treeView.collapse(row);
                    event.accepted = true;
                } else if (treeView.depth(row) > 0) {
                    const currentIdx = treeView.index(row, 0);
                    const parentIdx = currentIdx.parent;
                    if (parentIdx.valid) {
                        const parentCell = treeView.cellAtIndex(parentIdx);
                        if (parentCell.y >= 0) {
                            treeSelectionModel.setCurrentIndex(parentIdx, ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Current);
                            treeView.positionViewAtRow(parentCell.y, TableView.Contain);
                            event.accepted = true;
                        }
                    }
                }
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                treeView.activateCurrent();
                event.accepted = true;
            }
        }

        function activateCurrent() {
            if (treeView.currentRow >= 0) {
                const modelIndex = treeView.index(treeView.currentRow, 0);
                const url = root.treeModel.urlForIndex(modelIndex);
                root.folderClicked(url);
            }
        }

        delegate: ZenWorkspaceTreeDelegate {
            id: treeDelegate
            treeModel: root.treeModel
            tabsModel: root.tabsModel
            bridge: root.bridge
            verticalScrollBar: verticalScrollBar

            onFolderClicked: function (folderUrl) {
                root.folderClicked(folderUrl);
            }
            onFolderMiddleClicked: function (folderUrl) {
                root.folderMiddleClicked(folderUrl);
            }
            onFolderRightClicked: function (folderUrl, globalPos) {
                root.folderRightClicked(folderUrl, globalPos);
            }
            onFolderUrlsDropped: function (targetUrl, droppedUrls, globalPos) {
                root.folderUrlsDropped(targetUrl, droppedUrls, globalPos);
            }
            onDragAutoScrollRequested: function (globalY) {
                root.updateDragAutoScroll(globalY);
            }
            onDragAutoScrollStopped: {
                root.stopDragAutoScroll();
            }
        }
    }
}
