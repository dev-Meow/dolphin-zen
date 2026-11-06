pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.ki18n
import org.kde.dolphin.zenpanel
import "../components"

/**
 * Collapsible Devices & Network section (Section 3.3).
 *
 * Behavior:
 * - Unpinned & idle: collapses in-layout to show only the section header and individually pinned devices.
 * - Unpinned & hovered/focused: expands upward as a floating overlay above the workspace without resizing the layout.
 * - Pinned (via header pin button): integrates the full device list permanently into the panel layout.
 */
Item {
    id: root

    // --- Strongly typed model properties ---
    required property ZenSectionFilterProxy devicesModel
    required property ZenTabsModel tabsModel
    property ZenPanelBridge bridge: null

    // --- Configuration state (persisted via KConfigXT) ---
    property bool isPinned: false
    property bool isHorizontal: false
    property bool highlightOpenTabPlaces: true

    // --- Transient auto-hide expansion state ---
    property bool isHoverExpanded: false

    // Tracks the in-layout list height when only individually pinned devices are shown
    property real collapsedListHeight: 0

    // When docked horizontally (top/bottom), the section is automatically forced into pinned state
    readonly property bool effectivePinned: root.isPinned || root.isHorizontal

    // Whether all devices (including unpinned ones) should currently be visible
    readonly property bool showAllDevices: root.effectivePinned || root.isHoverExpanded || devicesListView.activeFocus

    // Current bounded height of the ListView content (capped at 12 gridUnits before scrolling)
    readonly property real currentBoundedListHeight: devicesListView.count > 0 ? Math.min(devicesListView.contentHeight, Kirigami.Units.gridUnit * 12) : 0

    // Target visual height of the section surface (header + currently visible list)
    readonly property real targetSurfaceHeight: header.implicitHeight + (root.currentBoundedListHeight > 0 ? Kirigami.Units.smallSpacing + root.currentBoundedListHeight : 0)

    // True when floating as an overlay over the workspace section (vertical unpinned mode only)
    readonly property bool isOverlayActive: !root.effectivePinned && root.showAllDevices

    // In-layout height reserved inside ZenPanel's GridLayout:
    // Frozen at the collapsed (pinned-only) height during hover overlay; matches targetSurfaceHeight otherwise
    readonly property real inLayoutHeight: root.isOverlayActive ? (header.implicitHeight + (root.collapsedListHeight > 0 ? Kirigami.Units.smallSpacing + root.collapsedListHeight : 0)) : root.targetSurfaceHeight

    function focusFirstDevice() {
        if (devicesListView.count > 0) {
            if (devicesListView.currentIndex < 0) {
                devicesListView.currentIndex = 0;
            }
            devicesListView.forceActiveFocus();
        }
    }
    signal deviceClicked(int row)
    signal deviceMiddleClicked(int row)
    signal deviceRightClicked(int row, point mousePos)
    signal devicePinToggled(int row)
    signal deviceUrlsDropped(int row, var droppedUrls, point globalPos)
    signal pinToggled(bool pinned)

    implicitWidth: Kirigami.Units.gridUnit * 10
    implicitHeight: root.inLayoutHeight

    // Ensure pointer hit-testing covers the upward-expanding overlay surface
    containmentMask: sectionSurface

    onCurrentBoundedListHeightChanged: {
        if (!root.showAllDevices) {
            root.collapsedListHeight = root.currentBoundedListHeight;
        }
    }

    onShowAllDevicesChanged: {
        if (root.showAllDevices) {
            // Snapshot the collapsed height before switching the proxy to show all devices
            root.collapsedListHeight = root.currentBoundedListHeight;
        }
        if (root.devicesModel) {
            root.devicesModel.onlyPinned = !root.showAllDevices;
        }
        if (!root.showAllDevices) {
            root.collapsedListHeight = root.currentBoundedListHeight;
        }
    }

    Component.onCompleted: {
        if (root.devicesModel) {
            root.devicesModel.onlyPinned = !root.showAllDevices;
        }
        if (!root.showAllDevices) {
            root.collapsedListHeight = root.currentBoundedListHeight;
        }
    }

    // Visual container:
    // - Vertical mode: anchored to the bottom of the section slot (`y = root.height - height`), growing upward in overlay mode.
    // - Horizontal mode: anchored to the top edge of the panel (`y = 0`, `height = root.height`) so the header and list
    //   align with the top of WorkspaceSection alongside it.
    Rectangle {
        id: sectionSurface
        anchors.left: parent.left
        anchors.right: parent.right
        y: root.isHorizontal ? 0 : (root.height - height)
        height: root.isHorizontal ? root.height : root.targetSurfaceHeight
        clip: true
        color: Kirigami.Theme.backgroundColor

        Behavior on height {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.InOutQuad
            }
        }

        // Top separator line when floating as an overlay (matches ZenPanel's section separators)
        Kirigami.Separator {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            visible: root.isOverlayActive
            weight: Kirigami.Separator.Weight.Light
        }

        // Prevent pointer and wheel events inside the overlay from leaking through to WorkspaceSection
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            preventStealing: true
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }

        ColumnLayout {
            id: columnLayout
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            // Section header with section-wide Pin toggle button
            ZenSectionHeader {
                id: header
                Layout.fillWidth: true
                text: KI18n.i18nc("@title:group", "Devices & Network")
                actionIconName: "pin"
                actionCheckable: true
                actionChecked: root.effectivePinned
                actionEnabled: !root.isHorizontal
                actionToolTipText: root.effectivePinned ? KI18n.i18nc("@info:tooltip", "Automatically collapse device list") : KI18n.i18nc("@info:tooltip", "Keep device list permanently pinned in panel")

                onActionToggled: function (checked) {
                    if (!checked) {
                        collapseTimer.stop();
                        root.isHoverExpanded = false;
                    }
                    root.pinToggled(checked);
                }
            }

            // Scrollable device list container
            Item {
                id: listContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: devicesListView
                    anchors.fill: parent
                    model: root.devicesModel
                    boundsBehavior: Flickable.StopAtBounds
                    focus: true
                    activeFocusOnTab: count > 0
                    keyNavigationEnabled: true

                    Controls.ScrollBar.vertical: ZenScrollBar {
                        id: deviceScrollBar
                        parent: devicesListView
                        x: devicesListView.width - width
                        y: 0
                        height: devicesListView.height
                        sectionHovered: hoverHandler.hovered
                        sectionFocused: devicesListView.activeFocus
                    }

                    onActiveFocusChanged: {
                        if (activeFocus && currentIndex < 0 && count > 0) {
                            currentIndex = 0;
                        }
                        if (activeFocus && currentIndex >= 0) {
                            devicesListView.positionViewAtIndex(currentIndex, ListView.Contain);
                        }
                    }

                    onMovementStarted: {
                        if (root.bridge) {
                            root.bridge.notifyTouchInteraction("devices");
                        }
                    }

                    onCurrentIndexChanged: {
                        deviceScrollBar.revealTemporarily();
                        if (activeFocus && currentIndex >= 0) {
                            devicesListView.positionViewAtIndex(currentIndex, ListView.Contain);
                        }
                    }

                    Keys.onPressed: function (event) {
                        if (root.bridge) {
                            root.bridge.notifyKeyboardInteraction();
                        }
                        deviceScrollBar.revealTemporarily();
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            if (devicesListView.currentIndex >= 0) {
                                root.deviceClicked(devicesListView.currentIndex);
                                event.accepted = true;
                            }
                        }
                    }

                    delegate: ZenDeviceDelegate {
                        id: deviceDelegate
                        bridge: root.bridge
                        // Permanently reserve the slim scrollbar lane on the right so items and the pin button never shift
                        width: Math.max(0, devicesListView.width - deviceScrollBar.implicitWidth - 2)

                        // Active & open-tab location highlighting
                        isCurrentLocation: root.tabsModel && root.tabsModel.revision >= 0 ? root.tabsModel.isUrlActive(deviceDelegate.url) : false
                        isOpenInAnyTab: root.highlightOpenTabPlaces && root.tabsModel && root.tabsModel.revision >= 0 ? root.tabsModel.hasUrl(deviceDelegate.url) : false

                        onClicked: {
                            root.deviceClicked(deviceDelegate.index);
                        }

                        onMiddleClicked: {
                            root.deviceMiddleClicked(deviceDelegate.index);
                        }

                        onRightClicked: function (mousePos) {
                            const globalPt = deviceDelegate.mapToGlobal(mousePos.x, mousePos.y);
                            root.deviceRightClicked(deviceDelegate.index, Qt.point(Math.round(globalPt.x), Math.round(globalPt.y)));
                        }

                        onPinToggled: {
                            root.devicePinToggled(deviceDelegate.index);
                        }

                        onUrlsDropped: function (urls, globalPos) {
                            root.deviceUrlsDropped(deviceDelegate.index, urls, globalPos);
                        }
                    }
                }
            }
        }

        // Auto-expand detection when hovering anywhere over the section surface (header or expanded overlay)
        HoverHandler {
            id: hoverHandler
            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop();
                    root.isHoverExpanded = true;
                    deviceScrollBar.revealTemporarily();
                } else {
                    collapseTimer.restart();
                }
            }
        }
    }

    // Delayed auto-collapse after the pointer leaves the section surface
    Timer {
        id: collapseTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!hoverHandler.hovered) {
                if (devicesListView.activeFocus) {
                    devicesListView.focus = false;
                }
                root.isHoverExpanded = false;
            }
        }
    }
}
