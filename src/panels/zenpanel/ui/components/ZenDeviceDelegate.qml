pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.ki18n
import org.kde.dolphin.zenpanel

/**
 * Specialized list item delegate for hardware drives, removable media, and network shares (Section 3.3).
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
    implicitHeight: root.bridge ? (root.capacityPercentage >= 0 ? root.bridge.devicesRowHeight + Math.round(Kirigami.Units.smallSpacing * 0.8) : root.bridge.devicesRowHeight) : (root.capacityPercentage >= 0 ? Math.round(Kirigami.Units.gridUnit * 2.2) : Math.round(Kirigami.Units.gridUnit * 2.0))
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
                return Kirigami.Theme.focusColor;
            }
            if (hoverHandler.hovered && (!root.bridge || (!root.bridge.keyboardNavigationActive && !root.bridge.touchInteractionActive))) {
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

        border.color: ((root.isItemFocused && (!root.bridge || root.bridge.keyboardNavigationActive)) || dropArea.containsDrag) ? Kirigami.Theme.focusColor : "transparent"
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
        anchors.leftMargin: root.bridge ? (root.bridge.lateralMargin + 1) : (Kirigami.Units.smallSpacing + 1)
        anchors.rightMargin: root.bridge ? (root.bridge.lateralMargin + 1) : (Kirigami.Units.smallSpacing + 1)
        spacing: root.bridge ? root.bridge.lateralMargin : Kirigami.Units.smallSpacing

        // Device or network icon
        Kirigami.Icon {
            Layout.preferredWidth: root.bridge ? root.bridge.devicesIconSize : Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            source: {
                if (!root.bridge) {
                    return root.decoration ? root.decoration : "drive-harddisk";
                }
                const _rev = root.bridge.themeMetricsRevision;
                return root.bridge.resolveSectionIcon(root.decoration ? root.decoration : "drive-harddisk", "devices");
            }
            isMask: root.bridge ? root.bridge.isSectionIconMask(root.decoration, "devices") : false
            color: (root.isCurrentLocation || root.isItemFocused) ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        }

            // Device title and optional compact Dolphin-style capacity bar
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Controls.Label {
                    Layout.fillWidth: true
                    text: root.display
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    color: Kirigami.Theme.textColor
                    font.weight: root.isCurrentLocation ? Font.DemiBold : Font.Normal
                }

                // Zero out qqc2-desktop-style's default largeSpacing vertical insets so the bar renders at compact height
                // Switch to Kirigami.Theme.negativeTextColor above 95% usage (matching KFilePlacesViewDelegate)
                Controls.ProgressBar {
                    id: capacityBar
                    visible: root.capacityPercentage >= 0
                    Layout.fillWidth: true
                    topInset: 0
                    bottomInset: 0
                    from: 0
                    to: 100
                    value: Math.max(0, root.capacityPercentage)
                    Kirigami.Theme.inherit: false
                    Kirigami.Theme.colorSet: Kirigami.Theme.View
                    Kirigami.Theme.highlightColor: root.capacityPercentage > 95 ? Kirigami.Theme.negativeTextColor : root.Kirigami.Theme.highlightColor
                }
            }

            // Per-device pin overlay button (shown only on row hover, subtler than the section header pin)
            Controls.ToolButton {
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
                return root.isPinnedDevice ? KI18n.i18nc("@info:tooltip", "Do not keep device permanently shown") : KI18n.i18nc("@info:tooltip", "Show device permanently even when collapsed");
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
