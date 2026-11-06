pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel

Item {
    id: root

    // --- Strongly typed model & state properties ---
    required property ZenSectionFilterProxy trashModel
    required property ZenTabsModel tabsModel
    property ZenPanelBridge bridge: null
    property bool highlightOpenTabPlaces: true
    property bool isHorizontal: false

    visible: root.bridge ? root.bridge.showTrashSection : true

    function focusTrashItem() {
        if (trashListView.count > 0) {
            trashListView.currentIndex = 0;
            trashListView.forceActiveFocus();
        }
    }

    // --- Signals to controller/bridge ---
    signal trashClicked(url trashUrl)
    signal trashMiddleClicked(url trashUrl)
    signal trashRightClicked(int row, point mousePos)
    signal trashUrlsDropped(url trashUrl, var droppedUrls, point globalPos)

    implicitWidth: root.isHorizontal
        ? (root.bridge ? root.bridge.essentialsTileWidth : Math.round(Kirigami.Units.gridUnit * 2.5))
        : (Kirigami.Units.gridUnit * 10)
    implicitHeight: root.isHorizontal
        ? (root.bridge ? root.bridge.essentialsTileHeight : Math.round(Kirigami.Units.gridUnit * 2.5))
        : (trashListView.count > 0 ? (root.bridge ? root.bridge.placesRowHeight : Math.round(Kirigami.Units.gridUnit * 2.0)) : 0)


    ListView {
        id: trashListView
        anchors.fill: parent
        orientation: root.isHorizontal ? ListView.Horizontal : ListView.Vertical
        interactive: false // Single fixed item; scrolling not required
        focus: true
        activeFocusOnTab: count > 0
        keyNavigationEnabled: true
        model: root.trashModel

        onActiveFocusChanged: {
            if (activeFocus && currentIndex < 0 && count > 0) {
                currentIndex = 0;
            }
        }

        Keys.onPressed: function(event) {
            if (root.bridge) {
                root.bridge.notifyKeyboardInteraction();
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (trashListView.count > 0) {
                    root.trashClicked("trash:/");
                    event.accepted = true;
                }
            }
        }

        delegate: Item {
            id: trashDelegate

            required property int index
            required property string display
            required property var decoration
            required property url url
            required property string formattedPath
            required property bool isHidden

            readonly property bool isCurrentListItem: ListView.isCurrentItem
            readonly property bool listHasFocus: ListView.view ? ListView.view.activeFocus : false
            readonly property bool isItemFocused: trashDelegate.activeFocus || (isCurrentListItem && listHasFocus)

            readonly property bool isCurrentLocation: root.tabsModel && root.tabsModel.revision >= 0
                ? root.tabsModel.isUrlActive(trashDelegate.url)
                : false
            readonly property bool isOpenInAnyTab: root.highlightOpenTabPlaces && root.tabsModel && root.tabsModel.revision >= 0
                ? root.tabsModel.hasUrl(trashDelegate.url)
                : false

            width: trashListView.width
            height: trashListView.height
            opacity: trashDelegate.isHidden ? 0.6 : 1.0

            Accessible.role: root.isHorizontal ? Accessible.Button : Accessible.ListItem
            Accessible.name: trashDelegate.display
            Accessible.description: trashDelegate.formattedPath

            onIsItemFocusedChanged: {
                if (trashDelegate.isItemFocused && root.bridge) {
                    root.bridge.focusedItemDescription = trashDelegate.display;
                }
            }

            Controls.ToolTip.visible: root.isHorizontal && delegateHoverHandler.hovered
            Controls.ToolTip.text: trashDelegate.display
            Controls.ToolTip.delay: Kirigami.Units.toolTipDelay

            Rectangle {
                id: bgRect
                anchors.fill: parent
                anchors.margins: root.isHorizontal ? 0 : 1
                radius: root.bridge ? root.bridge.itemRadius : Kirigami.Units.cornerRadius

                color: {
                    if (trashDropArea.containsDrag) {
                        return Qt.alpha(Kirigami.Theme.focusColor, 0.25);
                    }
                    if (trashMouseArea.containsPress) {
                        return Kirigami.Theme.focusColor;
                    }
                    if (delegateHoverHandler.hovered && (!root.bridge || (!root.bridge.keyboardNavigationActive && !root.bridge.touchInteractionActive))) {
                        return Kirigami.Theme.hoverColor;
                    }
                    if (trashDelegate.isCurrentLocation) {
                        return Qt.alpha(Kirigami.Theme.highlightColor, 0.16);
                    }
                    if (trashDelegate.isOpenInAnyTab) {
                        return Qt.alpha(Kirigami.Theme.highlightColor, 0.08);
                    }
                    return root.isHorizontal ? Kirigami.Theme.alternateBackgroundColor : "transparent";
                }

                border.color: ((trashDelegate.isItemFocused && (!root.bridge || root.bridge.keyboardNavigationActive)) || trashDropArea.containsDrag)
                    ? Kirigami.Theme.focusColor
                    : "transparent"
                border.width: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }

                // Accent bar indicating active location
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: root.isHorizontal ? undefined : parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: root.isHorizontal ? parent.right : undefined
                    height: root.isHorizontal ? 3 : undefined
                    width: root.isHorizontal ? undefined : 3
                    radius: 1.5
                    color: Kirigami.Theme.highlightColor
                    opacity: 0.7
                    visible: trashDelegate.isCurrentLocation
                }
            }

            // Vertical layout: Icon + Label
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.bridge ? (root.bridge.lateralMargin + 1) : (Kirigami.Units.smallSpacing + 1)
                anchors.rightMargin: root.bridge ? (root.bridge.lateralMargin + 1) : (Kirigami.Units.smallSpacing + 1)
                spacing: root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing
                visible: !root.isHorizontal

                Kirigami.Icon {
                    Layout.preferredWidth: root.bridge ? root.bridge.placesIconSize : Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment: Qt.AlignVCenter
                    source: {
                        const src = trashDelegate.decoration ? trashDelegate.decoration : "user-trash";
                        if (!root.bridge) {
                            return src;
                        }
                        const _rev = root.bridge.themeMetricsRevision;
                        return root.bridge.resolveSectionIcon(src, "trash");
                    }
                    isMask: root.bridge ? root.bridge.isSectionIconMask(trashDelegate.decoration, "trash") : false
                    color: (trashDelegate.isCurrentLocation || trashDelegate.isItemFocused) ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: trashDelegate.display
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    color: Kirigami.Theme.textColor
                    font.weight: trashDelegate.isCurrentLocation ? Font.DemiBold : Font.Normal
                }
            }

            // Horizontal layout: Centered Icon
            Kirigami.Icon {
                anchors.centerIn: parent
                visible: root.isHorizontal
                width: root.bridge ? root.bridge.essentialsIconSize : Kirigami.Units.iconSizes.medium
                height: width
                source: {
                    const src = trashDelegate.decoration ? trashDelegate.decoration : "user-trash";
                    if (!root.bridge) {
                        return src;
                    }
                    const _rev = root.bridge.themeMetricsRevision;
                    return root.bridge.resolveSectionIcon(src, "trash");
                }
                isMask: root.bridge ? root.bridge.isSectionIconMask(trashDelegate.decoration, "trash") : false
                color: (trashDelegate.isCurrentLocation || trashDelegate.isItemFocused) ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
            }

            HoverHandler {
                id: delegateHoverHandler
            }

            MouseArea {
                id: trashMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                onPressed: {
                    if (root.bridge) {
                        root.bridge.notifyMouseInteraction("trash");
                    }
                }

                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        if (mouse.modifiers & Qt.ControlModifier) {
                            root.trashMiddleClicked(trashDelegate.url);
                        } else {
                            root.trashClicked(trashDelegate.url);
                        }
                    } else if (mouse.button === Qt.MiddleButton) {
                        root.trashMiddleClicked(trashDelegate.url);
                    } else if (mouse.button === Qt.RightButton) {
                        const globalPt = trashDelegate.mapToGlobal(mouse.x, mouse.y);
                        root.trashRightClicked(trashDelegate.index, Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
                    }
                }
            }

            DropArea {
                id: trashDropArea
                anchors.fill: parent
                keys: ["text/uri-list"]

                onDropped: function(drop) {
                    if (drop.hasUrls && drop.urls.length > 0) {
                        const globalPt = trashDelegate.mapToGlobal(drop.x, drop.y);
                        root.trashUrlsDropped(trashDelegate.url, drop.urls, Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
                        drop.acceptProposedAction();
                    }
                }
            }
        }
    }
}
