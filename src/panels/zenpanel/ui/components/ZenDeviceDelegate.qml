// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ki18n
import org.kde.dolphin.zenpanel

/**
 * Specialized list item delegate for hardware drives, removable media, and network shares.
 *
 * Provides a compact Dolphin-style capacity bar underneath the label and a subtle per-device
 * hover pin overlay button (similar to Zen Browser's tab close button).
 * Unmount / eject actions are handled via the native KFilePlacesModel context menu actions.
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
    required property bool isPinnedDevice
    required property int capacityPercentage
    required property string freeSpaceText

    property ZenPanelBridge bridge: null

    // --- External state flags ---
    property bool isCurrentLocation: false
    property bool isOpenInAnyTab: false

    // --- Focus state ---
    readonly property bool isCurrentListItem: ListView.isCurrentItem
    readonly property bool listHasFocus: ListView.view ? ListView.view.activeFocus : false
    readonly property bool isItemFocused: root.activeFocus || (root.isCurrentListItem && root.listHasFocus)

    // --- Signals ---
    signal clicked
    signal middleClicked
    signal rightClicked(point mousePos)
    signal pinToggled
    signal urlsDropped(var urls, point globalPos)

    implicitWidth: Kirigami.Units.gridUnit * 10
    implicitHeight: (root.bridge ? root.bridge.devicesRowHeight : Math.round(Kirigami.Units.gridUnit * 1.35)) + (root.capacityPercentage >= 0 ? 5 : 0)
    opacity: root.isHidden ? 0.6 : 1.0

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
            if (dropArea.containsDrag) {
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

        border.color: (root.isItemFocused || dropArea.containsDrag) ? Qt.alpha(Kirigami.Theme.focusColor, 0.65) : "transparent"
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

    // Pointer interaction area
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onPressed: {
            if (root.bridge) {
                root.bridge.notifyMouseInteraction("devices");
            }
        }

        onClicked: function (mouse) {
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

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list"]

        onDropped: function (drop) {
            if (drop.hasUrls && drop.urls.length > 0) {
                const globalPt = root.mapToGlobal(drop.x, drop.y);
                root.urlsDropped(drop.urls, Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
                drop.acceptProposedAction();
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: (root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing) + 1
        anchors.rightMargin: (root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing) + 1
        spacing: root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing

        // Device or network icon
        ZenSectionIcon {
            Layout.preferredWidth: root.bridge ? root.bridge.devicesIconSize : Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            bridge: root.bridge
            section: "devices"
            iconName: root.decoration
            fallbackIcon: "drive-harddisk"
            highlighted: root.isCurrentLocation || root.isItemFocused
        }

            // Device title and optional compact Dolphin-style capacity bar
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                QQC2.Label {
                    Layout.fillWidth: true
                    text: root.display
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    color: Kirigami.Theme.textColor
                    font.weight: root.isCurrentLocation ? Font.DemiBold : Font.Normal
                }

                ZenCapacityBar {
                    id: capacityBar
                    visible: root.capacityPercentage >= 0
                    Layout.fillWidth: true
                    value: Math.max(0, root.capacityPercentage)
                }
            }

            // Per-device pin overlay button (shown only on row hover, subtler than the section header pin)
            QQC2.ToolButton {
                id: pinButton
                visible: hoverHandler.hovered
                focusPolicy: Qt.NoFocus
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.1
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.1
                Layout.alignment: Qt.AlignVCenter
                icon.name: "pin"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                checkable: true
                checked: root.isPinnedDevice
                opacity: root.isPinnedDevice ? (hovered ? 0.9 : 0.75) : (hovered ? 0.75 : 0.45)

                Accessible.name: root.isPinnedDevice ? KI18n.i18nc("@action:button", "Unpin device") : KI18n.i18nc("@action:button", "Pin device")

                onClicked: {
                    root.pinToggled();
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
        text: {
            if (pinButton.hovered) {
                return root.isPinnedDevice ? KI18n.i18nc("@info:tooltip", "Release from permanently shown devices") : KI18n.i18nc("@info:tooltip", "Show device permanently even when collapsed");
            }
            if (root.formattedPath.length > 0 && root.freeSpaceText.length > 0) {
                return root.formattedPath + "\n" + root.freeSpaceText;
            }
            if (root.freeSpaceText.length > 0) {
                return root.freeSpaceText;
            }
            return root.formattedPath;
        }
    }
}
