// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel

/**
 * Lightweight list item delegate for workspace section with drag reordering
 */
Item {
    id: root

    // --- Required model roles injected by ListView ---
    required property int index
    required property string display
    required property var decoration
    required property url url
    required property string formattedPath
    required property bool isHidden

    property ZenPanelBridge bridge: null

    // --- External state flags ---
    property bool isCurrentLocation: false
    property bool isOpenInAnyTab: false

    // --- Drop target visual state (controlled by parent ListView) ---
    property bool isDropTargetBefore: false
    property bool isDropTargetAfter: false

    // --- Touch / Drag state ---
    property bool isHeld: false
    property bool isDragging: false
    property int pressStartX: 0
    property int pressStartY: 0

    // --- Focus state ---
    readonly property bool isCurrentListItem: ListView.isCurrentItem
    readonly property bool listHasFocus: ListView.view ? ListView.view.activeFocus : false
    readonly property bool isItemFocused: root.activeFocus || (root.isCurrentListItem && root.listHasFocus)

    // --- Signals ---
    signal clicked
    signal middleClicked
    signal rightClicked(point mousePos)
    signal urlsDropped(var urls, point globalPos)
    signal addPlaceRequested(url placeUrl, int targetIndex, bool dropAfter)
    signal dragStarted(int fromRow)
    signal dragMoved(int hoverRow, bool dropAfter)
    signal dragFinished(int fromRow, int toRow, bool dropAfter)
    signal dragCanceled()

    // 0 = center/folder drop, 1 = top edge (insert before), 2 = bottom edge (insert after)
    property int externalDropMode: 0

    implicitWidth: Kirigami.Units.gridUnit * 10
    implicitHeight: root.bridge ? root.bridge.placesRowHeight : Math.round(Kirigami.Units.gridUnit * 1.35)
    opacity: root.isDragging ? 0.35 : (root.isHidden ? 0.6 : 1.0)
    scale: root.isHeld ? 1.03 : 1.0
    z: root.isDragging ? 100 : 0

    Behavior on scale {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }

    // Full accessibility support following KDE HIG
    Accessible.role: Accessible.ListItem
    Accessible.name: root.display
    Accessible.description: root.formattedPath

    onIsItemFocusedChanged: {
        if (root.isItemFocused && root.bridge) {
            root.bridge.focusedItemDescription = root.display;
        }
    }

    // List element background container
    Rectangle {
        id: bgRect
        anchors.fill: parent
        anchors.margins: 1
        radius: root.bridge ? root.bridge.itemRadius : Kirigami.Units.cornerRadius

        color: {
            if (dropArea.containsDrag && root.externalDropMode === 0) {
                return Qt.alpha(Kirigami.Theme.focusColor, 0.25);
            }
            if (mouseArea.containsPress) {
                return Qt.alpha(Kirigami.Theme.focusColor, 0.35);
            }
            if (root.isItemFocused) {
                return Qt.alpha(Kirigami.Theme.focusColor, 0.12);
            }
            if (hoverHandler.hovered) {
                return Kirigami.Theme.hoverColor;
            }
            if (root.isCurrentLocation) {
                return Qt.alpha(Kirigami.Theme.highlightColor, 0.16);
            }
            if (root.isOpenInAnyTab) {
                return Qt.alpha(Kirigami.Theme.highlightColor, 0.08);
            }
            return "transparent";
        }

        border.color: (root.isItemFocused || root.isHeld || (dropArea.containsDrag && root.externalDropMode === 0)) ? Qt.alpha(Kirigami.Theme.focusColor, 0.65) : "transparent"
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
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
            visible: root.isCurrentLocation
        }
    }

    // Drop target insertion marker: top edge
    Rectangle {
        id: dropMarkerTop
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        height: 3
        radius: 1.5
        color: Kirigami.Theme.highlightColor
        visible: root.isDropTargetBefore || (dropArea.containsDrag && root.externalDropMode === 1)
        z: 10
    }

    // Drop target insertion marker: bottom edge
    Rectangle {
        id: dropMarkerBottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        height: 3
        radius: 1.5
        color: Kirigami.Theme.highlightColor
        visible: root.isDropTargetAfter || (dropArea.containsDrag && root.externalDropMode === 2)
        z: 10
    }

    // External file drop handler (Dolphin file drops)
    DropArea {
        id: dropArea
        anchors.fill: parent
        z: 0
        keys: ["text/uri-list"]

        onPositionChanged: function (drag) {
            if (drag.y <= 6) {
                root.externalDropMode = 1;
            } else if (drag.y >= root.height - 6) {
                root.externalDropMode = 2;
            } else {
                root.externalDropMode = 0;
            }
        }

        onExited: {
            root.externalDropMode = 0;
        }

        onDropped: function (drop) {
            if (drop.hasUrls && drop.urls.length > 0) {
                const globalPt = root.mapToGlobal(drop.x, drop.y);
                if (root.externalDropMode === 1) {
                    root.addPlaceRequested(drop.urls[0], root.index, false);
                } else if (root.externalDropMode === 2) {
                    root.addPlaceRequested(drop.urls[0], root.index, true);
                } else {
                    root.urlsDropped(drop.urls, Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
                }
                drop.acceptProposedAction();
            }
            root.externalDropMode = 0;
        }
    }

    // Visual content: Icon + Title
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: (root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing) + 1
        anchors.rightMargin: (root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing) + 1
        spacing: root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing
        z: 0

        ZenSectionIcon {
            Layout.preferredWidth: root.bridge ? root.bridge.placesIconSize : Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            bridge: root.bridge
            section: "places"
            iconName: root.decoration
            fallbackIcon: "folder"
            highlighted: root.isCurrentLocation || root.isItemFocused
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: root.display
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            color: Kirigami.Theme.textColor
            font.weight: root.isCurrentLocation ? Font.DemiBold : Font.Normal
        }
    }

    // Pointer interaction area covering the entire delegate surface
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 1
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        pressAndHoldInterval: 400

        onPressed: function (mouse) {
            if (root.bridge) {
                root.bridge.notifyMouseInteraction("workspace");
            }
            root.pressStartX = Math.round(mouse.x);
            root.pressStartY = Math.round(mouse.y);
            root.isHeld = false;
            root.isDragging = false;

            const isTouch = (mouse.source !== Qt.MouseEventNotSynthesized);
            if (isTouch) {
                // Prevent Flickable from canceling hold gesture on slight finger micro-tremors
                mouseArea.preventStealing = true;
            }
        }

        onPositionChanged: function (mouse) {
            const isTouch = (mouse.source !== Qt.MouseEventNotSynthesized);
            const dist = Math.hypot(mouse.x - root.pressStartX, mouse.y - root.pressStartY);

            if (!root.isDragging) {
                if (isTouch) {
                    if (!root.isHeld && dist > Kirigami.Units.gridUnit) {
                        // User swiped deliberately before hold timer: yield touch grab to ListView scroll
                        mouseArea.preventStealing = false;
                        return;
                    }
                    if (root.isHeld && dist > 4) {
                        root.isDragging = true;
                        root.dragStarted(root.index);
                    }
                } else {
                    if ((mouse.buttons & Qt.LeftButton) && dist > 4) {
                        root.isDragging = true;
                        root.isHeld = true;
                        root.dragStarted(root.index);
                    }
                }
            }

            if (root.isDragging && root.ListView.view) {
                const view = root.ListView.view;
                const listPt = root.mapToItem(view.contentItem, mouse.x, mouse.y);
                const probeX = Math.max(1, Math.min(view.width - 2, view.width / 2));
                let hoverRow = -1;
                let dropAfter = false;

                if (listPt.y >= view.contentHeight - 5) {
                    hoverRow = view.count - 1;
                    dropAfter = true;
                } else if (listPt.y <= 5) {
                    hoverRow = 0;
                    dropAfter = false;
                } else {
                    const idx = view.indexAt(probeX, Math.max(0, Math.min(view.contentHeight - 1, listPt.y)));
                    if (idx >= 0) {
                        hoverRow = idx;
                        const targetItem = view.itemAtIndex(idx);
                        const itemY = targetItem ? targetItem.y : idx * root.height;
                        dropAfter = (listPt.y - itemY > root.height / 2);
                    }
                }
                root.dragMoved(hoverRow, dropAfter);
            }
        }

        onPressAndHold: function (mouse) {
            if (mouse.button === Qt.LeftButton) {
                if (root.bridge) {
                    root.bridge.notifyTouchInteraction("workspace");
                }
                root.isHeld = true;
                mouseArea.preventStealing = true;
            }
        }

        onReleased: function (mouse) {
            if (root.isDragging) {
                if (root.ListView.view) {
                    const view = root.ListView.view;
                    const listPt = root.mapToItem(view.contentItem, mouse.x, mouse.y);
                    const probeX = Math.max(1, Math.min(view.width - 2, view.width / 2));
                    let targetRow = -1;
                    let dropAfter = false;

                    if (listPt.y >= view.contentHeight - 5) {
                        targetRow = view.count - 1;
                        dropAfter = true;
                    } else if (listPt.y <= 5) {
                        targetRow = 0;
                        dropAfter = false;
                    } else {
                        const idx = view.indexAt(probeX, Math.max(0, Math.min(view.contentHeight - 1, listPt.y)));
                        if (idx >= 0) {
                            targetRow = idx;
                            const targetItem = view.itemAtIndex(idx);
                            const itemY = targetItem ? targetItem.y : idx * root.height;
                            dropAfter = (listPt.y - itemY > root.height / 2);
                        }
                    }
                    root.dragFinished(root.index, targetRow, dropAfter);
                } else {
                    root.dragCanceled();
                }
            }
            root.isDragging = false;
            root.isHeld = false;
            mouseArea.preventStealing = false;
        }

        onCanceled: {
            if (root.isDragging) {
                root.dragCanceled();
            }
            root.isDragging = false;
            root.isHeld = false;
            mouseArea.preventStealing = false;
        }

        onClicked: function (mouse) {
            if (root.isDragging) {
                return;
            }
            if (root.ListView.view) {
                root.ListView.view.currentIndex = root.index;
                root.ListView.view.forceActiveFocus();
            }
            if (mouse.button === Qt.LeftButton) {
                if (mouse.modifiers & Qt.ControlModifier) {
                    root.middleClicked();
                } else {
                    root.clicked();
                }
            } else if (mouse.button === Qt.MiddleButton) {
                root.middleClicked();
            } else if (mouse.button === Qt.RightButton) {
                root.rightClicked(Qt.point(mouse.x, mouse.y));
            }
        }
    }

    // Floating drag ghost following the cursor during reordering
    Rectangle {
        id: dragGhost
        x: 0
        y: Math.round(mouseArea.mouseY - height / 2)
        width: root.width
        height: root.height
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.25)
        border.color: Kirigami.Theme.highlightColor
        border.width: 1
        visible: root.isDragging
        z: 999

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing + 1
            anchors.rightMargin: Kirigami.Units.smallSpacing + 1
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                Layout.alignment: Qt.AlignVCenter
                source: root.decoration ? root.decoration : "folder"
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: root.display
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: Kirigami.Theme.textColor
                font.weight: Font.DemiBold
            }
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    ZenToolTip {
        bridge: root.bridge
        hovered: hoverHandler.hovered && !mouseArea.containsPress
        keyboardFocused: root.isItemFocused
        text: root.formattedPath
    }
}
