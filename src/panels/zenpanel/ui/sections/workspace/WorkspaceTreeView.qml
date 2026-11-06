pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQml.Models
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel
import "../../components"

Item {
    id: root

    required property ZenFolderTreeModel treeModel
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
        pointerNavigationEnabled: true

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
            if (root.bridge) {
                root.bridge.notifyTouchInteraction("workspace");
            }
        }

        Keys.onTabPressed: function(event) {
            const nextItem = treeView.nextItemInFocusChain(true);
            if (nextItem) {
                nextItem.forceActiveFocus(Qt.TabFocusReason);
                event.accepted = true;
            }
        }

        Keys.onBacktabPressed: function(event) {
            const prevItem = treeView.nextItemInFocusChain(false);
            if (prevItem) {
                prevItem.forceActiveFocus(Qt.BacktabFocusReason);
                event.accepted = true;
            }
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                return;
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

        delegate: QQC2.TreeViewDelegate {
            id: control

            // Reserve space on the right for the slim ZenScrollBar handle so rows never shift or collide
            implicitWidth: Math.max(Math.max(0, treeView.width - verticalScrollBar.implicitWidth - 2), contentRow.implicitWidth + leftPadding + rightPadding + Kirigami.Units.smallSpacing)
            implicitHeight: root.bridge ? root.bridge.treeRowHeight : Math.round(Kirigami.Units.gridUnit * 1.8)

            highlighted: control.current || control.selected || (treeView.currentRow === control.row)
            onHighlightedChanged: {
                if (control.highlighted && root.bridge) {
                    const idx = treeView.index(control.row, 0);
                    const name = root.treeModel ? root.treeModel.data(idx, Qt.DisplayRole) : "";
                    root.bridge.focusedItemDescription = name;
                }
            }

            contentItem: RowLayout {
                id: contentRow
                spacing: root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: root.bridge ? root.bridge.treeIconSize : Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                    source: {
                        if (!root.bridge) {
                            return "folder";
                        }
                        const _rev = root.bridge.themeMetricsRevision;
                        return root.bridge.resolveSectionIcon("folder", "tree");
                    }
                    isMask: root.bridge ? root.bridge.isSectionIconMask("folder", "tree") : false
                    color: Kirigami.Theme.textColor
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: {
                        if (control.text && control.text.length > 0) {
                            return control.text;
                        }
                        const idx = treeView.index(control.row, 0);
                        return root.treeModel ? root.treeModel.data(idx, Qt.DisplayRole) : "";
                    }
                    verticalAlignment: Text.AlignVCenter
                    color: control.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                }
            }

            background: Rectangle {
                radius: root.bridge ? root.bridge.itemRadius : Kirigami.Units.cornerRadius
                color: {
                    if (rowDropArea.containsDrag) {
                        return Qt.alpha(Kirigami.Theme.focusColor, 0.25);
                    }
                    if (control.highlighted) {
                        return Kirigami.Theme.highlightColor;
                    }
                    if (control.hovered && (!root.bridge || (!root.bridge.keyboardNavigationActive && !root.bridge.touchInteractionActive))) {
                        return Kirigami.Theme.hoverColor;
                    }
                    return "transparent";
                }
                border.color: ((treeView.activeFocus && control.highlighted && (!root.bridge || root.bridge.keyboardNavigationActive)) || rowDropArea.containsDrag) ? Kirigami.Theme.focusColor : "transparent"
                border.width: 1
            }

            // Pointer interaction on the row content (excluding the branch indicator arrow on the left,
            // which remains handled directly by TreeViewDelegate to toggle expansion):
            // - Shift + Left-Click: only expand/collapse the node without opening the folder (Dolphin FoldersPanel behavior)
            // - Ctrl + Left-Click or Middle-Click: open folder in a new tab
            // - Normal Left-Click: open folder in active view
            // - Right-Click: open TreeView context menu
            MouseArea {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                x: control.indicator && control.indicator.visible ? (control.indicator.x + control.indicator.width) : 0
                width: Math.max(0, parent.width - x)
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                onPressed: {
                    if (root.bridge) {
                        root.bridge.notifyMouseInteraction("workspace");
                    }
                }

                onClicked: function (mouse) {
                    treeView.forceActiveFocus();
                    const idx = treeView.index(control.row, 0);
                    treeSelectionModel.setCurrentIndex(idx, ItemSelectionModel.ClearAndSelect | ItemSelectionModel.Current);
                    treeView.positionViewAtRow(control.row, TableView.Contain);

                    const url = root.treeModel.urlForIndex(idx);
                    if (mouse.button === Qt.LeftButton) {
                        if (mouse.modifiers & Qt.ShiftModifier) {
                            // Shift + Click only toggles node expansion without navigating
                            treeView.toggleExpanded(control.row);
                        } else if (mouse.modifiers & Qt.ControlModifier) {
                            root.folderMiddleClicked(url);
                        } else {
                            root.folderClicked(url);
                        }
                    } else if (mouse.button === Qt.MiddleButton) {
                        root.folderMiddleClicked(url);
                    } else if (mouse.button === Qt.RightButton) {
                        const globalPoint = control.mapToGlobal(mouse.x + x, mouse.y);
                        root.folderRightClicked(url, Qt.point(Math.round(globalPoint.x), Math.round(globalPoint.y)));
                    }
                }
            }

            DropArea {
                id: rowDropArea
                anchors.fill: parent
                keys: ["text/uri-list"]

                onPositionChanged: function (drag) {
                    const globalPt = control.mapToGlobal(drag.x, drag.y);
                    root.updateDragAutoScroll(globalPt.y);
                }

                onEntered: function (drag) {
                    if (!treeView.isExpanded(control.row)) {
                        autoExpandTimer.restart();
                    }
                }

                onExited: {
                    autoExpandTimer.stop();
                    root.stopDragAutoScroll();
                }

                onDropped: function (drop) {
                    autoExpandTimer.stop();
                    root.stopDragAutoScroll();
                    if (drop.hasUrls && drop.urls.length > 0) {
                        const idx = treeView.index(control.row, 0);
                        const targetUrl = root.treeModel.urlForIndex(idx);
                        const globalPt = control.mapToGlobal(drop.x, drop.y);
                        root.folderUrlsDropped(targetUrl, drop.urls, Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
                        drop.acceptProposedAction();
                    }
                }

                Timer {
                    id: autoExpandTimer
                    interval: 750
                    repeat: false
                    onTriggered: {
                        if (rowDropArea.containsDrag && !treeView.isExpanded(control.row)) {
                            treeView.expand(control.row);
                        }
                    }
                }
            }
        }
    }
}
