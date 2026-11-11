// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel
import "../../components"

/**
 * Scrollable list of regular workspace bookmarks and places.
 * Highlights entries that are currently active or open in any Dolphin tab / split-view.
 */
Item {
    id: root

    // --- Strongly typed model & state properties ---
    required property ZenSectionFilterProxy placesModel
    required property ZenTabsModel tabsModel
    property ZenPanelBridge bridge: null
    property bool highlightOpenTabPlaces: true

    // --- Internal drag reordering tracking ---
    property int draggingRow: -1
    property int targetHoverIndex: -1
    property bool targetHoverAfter: false

    function focusFirstPlace() {
        if (placesListView.count > 0) {
            if (placesListView.currentIndex < 0) {
                placesListView.currentIndex = 0;
            }
            placesListView.forceActiveFocus();
        }
    }
    signal placeClicked(url placeUrl)
    signal placeMiddleClicked(url placeUrl)
    signal placeRightClicked(int row, point mousePos)
    signal placeUrlsDropped(url targetUrl, var droppedUrls, point globalPos)
    signal backgroundRightClicked(point globalPos)

    implicitWidth: Kirigami.Units.gridUnit * 10
    implicitHeight: Kirigami.Units.gridUnit * 14

    // Right-click on empty viewport area (Add Entry... / Show All Entries)
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.RightButton
        onClicked: function (mouse) {
            const globalPt = root.mapToGlobal(mouse.x, mouse.y);
            root.backgroundRightClicked(Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
        }
    }

    ListView {
        id: placesListView
        anchors.fill: parent
        z: 1
        clip: true
        focus: true
        activeFocusOnTab: count > 0
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.placesModel

        section.property: "group"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            id: sectionHeaderItem
            required property string section
            readonly property bool showHeader: sectionHeaderItem.section.length > 0

            width: Math.max(0, placesListView.width - placesScrollBar.implicitWidth - 2)
            height: sectionHeaderItem.showHeader ? sectionHeaderCol.implicitHeight : 0
            visible: sectionHeaderItem.showHeader

            ColumnLayout {
                id: sectionHeaderCol
                visible: sectionHeaderItem.showHeader
                anchors.fill: parent
                anchors.leftMargin: (root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing) + 1
                anchors.rightMargin: (root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing) + 1
                spacing: 2

                Kirigami.Separator {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    weight: Kirigami.Separator.Weight.Light
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    text: sectionHeaderItem.section
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.DemiBold
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                }
            }
        }

        QQC2.ScrollBar.vertical: ZenScrollBar {
            id: placesScrollBar
            parent: placesListView
            x: placesListView.width - width
            y: 0
            height: placesListView.height
            sectionHovered: sectionHoverHandler.hovered
            sectionFocused: placesListView.activeFocus
        }

        ZenWheelScroller {
            flickable: placesListView
            bridge: root.bridge
            onScrolled: placesScrollBar.revealTemporarily()
        }

        onActiveFocusChanged: {
            if (activeFocus && currentIndex < 0 && count > 0) {
                currentIndex = 0;
            }
        }

        onMovementStarted: {
            if (root.bridge && (placesListView.dragging || placesListView.flicking)) {
                root.bridge.notifyTouchInteraction("workspace");
            }
        }

        onCurrentIndexChanged: {
            placesScrollBar.revealTemporarily();
        }

        Keys.onPressed: function (event) {
            if (root.bridge) {
                root.bridge.notifyKeyboardInteraction();
            }
            placesScrollBar.revealTemporarily();
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                const item = placesListView.currentItem as ZenPlaceListDelegate;
                if (item) {
                    root.placeClicked(item.url);
                    event.accepted = true;
                }
            }
        }

        delegate: ZenPlaceListDelegate {
            id: placeDelegate
            bridge: root.bridge
            // Permanently reserve the slim scrollbar lane on the right so items never shift when the scrollbar appears
            width: Math.max(0, placesListView.width - placesScrollBar.implicitWidth - 2)

            // Reactive multi-highlighting bound to ZenTabsModel::revision
            isCurrentLocation: root.tabsModel && root.tabsModel.revision >= 0 ? root.tabsModel.isUrlActive(placeDelegate.url) : false
            isOpenInAnyTab: root.highlightOpenTabPlaces && root.tabsModel && root.tabsModel.revision >= 0 ? root.tabsModel.hasUrl(placeDelegate.url) : false

            // Drop indicator states bound to central drag tracking
            isDropTargetBefore: (root.targetHoverIndex === placeDelegate.index && !root.targetHoverAfter && root.draggingRow !== placeDelegate.index && root.draggingRow >= 0)
            isDropTargetAfter: (root.targetHoverIndex === placeDelegate.index && root.targetHoverAfter && root.draggingRow !== placeDelegate.index && root.draggingRow >= 0)

            onDragStarted: function (fromRow) {
                root.draggingRow = fromRow;
            }

            onDragMoved: function (hoverRow, dropAfter) {
                root.targetHoverIndex = hoverRow;
                root.targetHoverAfter = dropAfter;
            }

            onDragFinished: function (fromRow, toRow, dropAfter) {
                if (fromRow >= 0 && toRow >= 0 && root.bridge) {
                    root.bridge.moveWorkspacePlace(fromRow, toRow, dropAfter);
                }
                root.draggingRow = -1;
                root.targetHoverIndex = -1;
            }

            onDragCanceled: {
                root.draggingRow = -1;
                root.targetHoverIndex = -1;
            }

            onClicked: {
                root.placeClicked(placeDelegate.url);
            }

            onMiddleClicked: {
                root.placeMiddleClicked(placeDelegate.url);
            }

            onRightClicked: function (mousePos) {
                const globalPt = placeDelegate.mapToGlobal(mousePos.x, mousePos.y);
                root.placeRightClicked(placeDelegate.index, Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
            }

            onUrlsDropped: function (urls, globalPos) {
                root.placeUrlsDropped(placeDelegate.url, urls, globalPos);
            }

            onAddPlaceRequested: function (url, targetIndex, dropAfter) {
                if (root.bridge) {
                    root.bridge.addPlaceFromUrl(url, targetIndex, dropAfter);
                }
            }
        }
    }

    // External drop handler on empty viewport area (append as new place)
    DropArea {
        id: emptyAreaDropArea
        anchors.fill: parent
        z: 0
        keys: ["text/uri-list"]

        onDropped: function (drop) {
            if (drop.hasUrls && drop.urls.length > 0 && root.bridge) {
                root.bridge.addPlaceFromUrl(drop.urls[0], -1, true);
                drop.acceptProposedAction();
            }
        }
    }

    // Drop indicator when dragging over empty area below existing places
    Rectangle {
        id: emptyDropMarker
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.min(parent.height - 4, Math.max(0, placesListView.contentHeight + 2))
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        height: 3
        radius: 1.5
        color: Kirigami.Theme.highlightColor
        visible: emptyAreaDropArea.containsDrag
        z: 10
    }

    HoverHandler {
        id: sectionHoverHandler
        onPointChanged: {
            if (hovered) {
                if (root.bridge) {
                    root.bridge.notifyMouseHoverSection("workspace");
                }
                placesScrollBar.revealTemporarily();
            }
        }
    }
}
