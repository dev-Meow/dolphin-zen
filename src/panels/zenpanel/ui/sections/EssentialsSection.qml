pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel

Item {
    id: root

    // --- Strongly typed properties (injected from ZenPanel.qml) ---
    required property ZenSectionFilterProxy essentialsModel
    required property ZenTabsModel tabsModel
    property ZenPanelBridge bridge: null

    // Configuration values (from KConfigXT)
    property int maxEssentials: 12
    property bool showAddButton: true
    property bool highlightOpenTabPlaces: true

    // Internal drag reordering tracking
    property int draggingTileIndex: -1
    property int targetHoverSlot: -1
    property point dragCursorPos: Qt.point(0, 0)
    property point dragGrabOffset: Qt.point(0, 0)
    property var draggingDecoration: "folder"
    property string draggingDisplay: ""

    // --- Signals to controller/bridge ---
    signal placeClicked(url placeUrl)
    signal placeMiddleClicked(url placeUrl)
    signal placeRightClicked(int row, point mousePos)
    signal placeUrlsDropped(url targetUrl, var droppedUrls, point globalPos)
    signal addUrlDropped(url folderUrl)
    signal addClicked()

    implicitWidth: Kirigami.Units.gridUnit * 10
    implicitHeight: gridContainer.implicitHeight + Kirigami.Units.smallSpacing * 2

    focus: true
    activeFocusOnTab: true

    onActiveFocusChanged: {
        if (activeFocus && !root.hasActiveTileFocus()) {
            root.focusTileAt(0);
        }
    }

    function hasActiveTileFocus(): bool {
        const count = tileRepeater.count;
        for (let i = 0; i < count; ++i) {
            const item = tileRepeater.itemAt(i) as Item;
            if (item && item.activeFocus) {
                return true;
            }
        }
        return addTile.activeFocus;
    }

    // Move keyboard focus to a target tile index (or the add button at tileRepeater.count)
    function focusTileAt(targetIndex: int) {
        const count = tileRepeater.count;
        if (targetIndex >= 0 && targetIndex < count) {
            const item = tileRepeater.itemAt(targetIndex) as Item;
            if (item) {
                item.forceActiveFocus();
            }
        } else if (targetIndex === count && addTile.visible) {
            addTile.forceActiveFocus();
        }
    }


    // Fluid animated grid layout container
    Item {
        id: gridContainer
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing

        readonly property int iconSz: root.bridge ? root.bridge.essentialsIconSize : Kirigami.Units.iconSizes.medium
        readonly property real spacing: Kirigami.Units.smallSpacing

        // Dynamic minimum tile width to enclose the icon comfortably with lateral padding
        readonly property real minTileWidth: Math.max(Math.round(Kirigami.Units.gridUnit * 3.0), iconSz + Math.round(spacing * 2.5))
        readonly property int columns: Math.max(1, Math.floor((width + spacing) / (minTileWidth + spacing)))
        readonly property real tileWidth: Math.floor((width - Math.max(0, columns - 1) * spacing) / Math.max(1, columns))

        // Tile height scales up to match or enclose the icon at least squarely
        readonly property real tileHeight: Math.max(Math.round(Kirigami.Units.gridUnit * 2.4), Math.min(tileWidth, iconSz + Math.round(spacing * 3.0)))

        readonly property int totalCount: tileRepeater.count + (addTile.visible ? 1 : 0)
        readonly property int totalRows: Math.max(1, Math.ceil(totalCount / columns))

        implicitHeight: totalRows * tileHeight + Math.max(0, totalRows - 1) * spacing

        function slotX(slotIndex: int): real {
            const col = slotIndex % columns;
            return col * (tileWidth + spacing);
        }

        function slotY(slotIndex: int): real {
            const row = Math.floor(slotIndex / columns);
            return row * (tileHeight + spacing);
        }

        function slotAtPos(x: real, y: real): int {
            const col = Math.max(0, Math.min(columns - 1, Math.floor(x / (tileWidth + spacing))));
            const row = Math.max(0, Math.floor(y / (tileHeight + spacing)));
            const slot = row * columns + col;
            return Math.max(0, Math.min(tileRepeater.count - 1, slot));
        }

        function computeVisualSlot(modelIndex: int): int {
            if (root.draggingTileIndex < 0 || root.targetHoverSlot < 0) {
                return modelIndex;
            }
            if (modelIndex === root.draggingTileIndex) {
                return root.targetHoverSlot;
            }
            if (root.draggingTileIndex < root.targetHoverSlot) {
                if (modelIndex > root.draggingTileIndex && modelIndex <= root.targetHoverSlot) {
                    return modelIndex - 1;
                }
            } else if (root.draggingTileIndex > root.targetHoverSlot) {
                if (modelIndex >= root.targetHoverSlot && modelIndex < root.draggingTileIndex) {
                    return modelIndex + 1;
                }
            }
            return modelIndex;
        }

        // 1. Regular essential tiles from the filter proxy model
        Repeater {
            id: tileRepeater
            model: root.essentialsModel

            delegate: ZenTileDelegate {
                id: tileDelegate
                bridge: root.bridge

                // Mark all model roles as required so Repeater binds them in Bound mode
                required display
                required decoration
                required formattedPath
                required isEssential
                required isHidden
                required url

                width: gridContainer.tileWidth
                height: gridContainer.tileHeight

                readonly property int visualSlot: gridContainer.computeVisualSlot(tileDelegate.index)

                x: gridContainer.slotX(visualSlot)
                y: gridContainer.slotY(visualSlot)

                Behavior on x {
                    enabled: root.draggingTileIndex >= 0 && root.draggingTileIndex !== tileDelegate.index
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    enabled: root.draggingTileIndex >= 0 && root.draggingTileIndex !== tileDelegate.index
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                // Reactive multi-highlighting bound to ZenTabsModel::revision
                isCurrentLocation: root.tabsModel && root.tabsModel.revision >= 0
                    ? root.tabsModel.isUrlActive(tileDelegate.url)
                    : false
                isOpenInAnyTab: root.highlightOpenTabPlaces && root.tabsModel && root.tabsModel.revision >= 0
                    ? root.tabsModel.hasUrl(tileDelegate.url)
                    : false
                isDropTarget: (root.targetHoverSlot === visualSlot && root.draggingTileIndex !== tileDelegate.index && root.draggingTileIndex >= 0)

                onDragStarted: function (fromIdx, grabLocalPt) {
                    root.draggingTileIndex = fromIdx;
                    root.targetHoverSlot = fromIdx;
                    root.draggingDecoration = tileDelegate.decoration;
                    root.draggingDisplay = tileDelegate.display;
                    root.dragGrabOffset = grabLocalPt;
                    const containerPt = gridContainer.mapFromItem(tileDelegate, grabLocalPt.x, grabLocalPt.y);
                    root.dragCursorPos = Qt.point(containerPt.x, containerPt.y);
                }

                onDragMoved: function (globalPt) {
                    const containerPt = gridContainer.mapFromGlobal(globalPt.x, globalPt.y);
                    root.dragCursorPos = Qt.point(containerPt.x, containerPt.y);
                    root.targetHoverSlot = gridContainer.slotAtPos(containerPt.x, containerPt.y);
                }

                onDragFinished: function (fromIdx) {
                    if (fromIdx >= 0 && root.targetHoverSlot >= 0 && fromIdx !== root.targetHoverSlot && root.bridge) {
                        root.bridge.moveEssential(fromIdx, root.targetHoverSlot);
                    }
                    root.draggingTileIndex = -1;
                    root.targetHoverSlot = -1;
                }

                onDragCanceled: {
                    root.draggingTileIndex = -1;
                    root.targetHoverSlot = -1;
                }

                Keys.onBacktabPressed: function(event) {
                    if (tileDelegate.index === 0 && root.bridge) {
                        root.bridge.focusPreviousWidget();
                        event.accepted = true;
                    }
                }

                Keys.onLeftPressed: function(event) {
                    if (root.bridge) {
                        root.bridge.notifyKeyboardInteraction();
                    }
                    if (tileDelegate.index > 0) {
                        root.focusTileAt(tileDelegate.index - 1);
                        event.accepted = true;
                    }
                }

                Keys.onRightPressed: function(event) {
                    if (root.bridge) {
                        root.bridge.notifyKeyboardInteraction();
                    }
                    root.focusTileAt(tileDelegate.index + 1);
                    event.accepted = true;
                }

                Keys.onUpPressed: function(event) {
                    if (root.bridge) {
                        root.bridge.notifyKeyboardInteraction();
                    }
                    if (tileDelegate.index - gridContainer.columns >= 0) {
                        root.focusTileAt(tileDelegate.index - gridContainer.columns);
                        event.accepted = true;
                    }
                }

                Keys.onDownPressed: function(event) {
                    if (root.bridge) {
                        root.bridge.notifyKeyboardInteraction();
                    }
                    root.focusTileAt(tileDelegate.index + gridContainer.columns);
                    event.accepted = true;
                }

                onClicked: {
                    root.placeClicked(tileDelegate.url);
                }

                onMiddleClicked: {
                    root.placeMiddleClicked(tileDelegate.url);
                }

                onRightClicked: function(mousePos) {
                    const globalPt = tileDelegate.mapToGlobal(mousePos.x, mousePos.y);
                    root.placeRightClicked(tileDelegate.index, Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
                }

                onUrlsDropped: function(urls, globalPos) {
                    root.placeUrlsDropped(tileDelegate.url, urls, globalPos);
                }
            }
        }

        // 2. The [+] tile for pinning additional essential places
        ZenTileDelegate {
            id: addTile
            bridge: root.bridge
            visible: root.showAddButton && (root.essentialsModel ? root.essentialsModel.rowCount() < root.maxEssentials : true)

            width: gridContainer.tileWidth
            height: gridContainer.tileHeight

            x: gridContainer.slotX(tileRepeater.count)
            y: gridContainer.slotY(tileRepeater.count)

            index: -1
            isAddButton: true

            Keys.onLeftPressed: function(event) {
                if (tileRepeater.count > 0) {
                    root.focusTileAt(tileRepeater.count - 1);
                    event.accepted = true;
                }
            }

            Keys.onUpPressed: function(event) {
                if (tileRepeater.count - gridContainer.columns >= 0) {
                    root.focusTileAt(tileRepeater.count - gridContainer.columns);
                    event.accepted = true;
                }
            }

            onAddClicked: {
                root.addClicked();
            }

            onUrlsDropped: function(urls) {
                if (urls.length > 0) {
                    root.addUrlDropped(urls[0]);
                }
            }
        }
    }

    // --- Floating Drag Tile follows pointer/finger at root level ---
    Rectangle {
        id: floatingDragTile
        visible: root.draggingTileIndex >= 0
        z: 100
        x: gridContainer.x + root.dragCursorPos.x - root.dragGrabOffset.x
        y: gridContainer.y + root.dragCursorPos.y - root.dragGrabOffset.y
        width: gridContainer.tileWidth
        height: gridContainer.tileHeight
        radius: Kirigami.Units.cornerRadius
        scale: 1.06
        color: Kirigami.Theme.highlightColor
        opacity: 0.92

        border.color: Kirigami.Theme.focusColor
        border.width: 1

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.medium
            height: Kirigami.Units.iconSizes.medium
            source: root.draggingDecoration ? root.draggingDecoration : "folder"
        }

        Behavior on scale {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
    }
}
