// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Meow <meow@example.com>

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel 1.0

/**
 * @brief Responsive desktop smooth wheel & precision touchpad scrolling helper.
 *
 * Supports both discrete mouse wheel notches (PointerDevice.Mouse) with OutQuad easing
 * and continuous precision touchpad 2-finger gestures (PointerDevice.TouchPad) with
 * zero-latency 1:1 pixel tracking. Both paths honor the user-configurable speed multiplier
 * from zenpanelrc (WheelScrollSpeedModifier).
 */
Item {
    id: root

    required property Flickable flickable
    property ZenPanelBridge bridge: null
    property real rowHeight: bridge ? bridge.itemRowHeight : 24
    property int linesToScroll: bridge ? bridge.wheelScrollLines() : 3
    property real speedMultiplier: bridge ? bridge.wheelScrollSpeedModifier() : 1.0

    signal scrolled()

    // Explicitly parent to the flickable viewport (not contentItem) so it spans the entire visible area
    parent: flickable
    anchors.fill: parent
    z: -1

    readonly property real effectiveRowHeight: (root.rowHeight > 0) ? root.rowHeight : 24
    readonly property real effectiveLines: (root.linesToScroll > 0) ? root.linesToScroll : 3
    readonly property real stepSize: root.effectiveLines * root.effectiveRowHeight

    NumberAnimation {
        id: scrollAnimation
        target: root.flickable
        property: "contentY"
        duration: Kirigami.Units.shortDuration // ~80-100ms snappy response
        easing.type: Easing.OutQuad
    }

    Connections {
        target: root.flickable
        function onMovementStarted() {
            scrollAnimation.stop();
        }
    }

    WheelHandler {
        id: wheelHandler
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        orientation: Qt.Vertical

        onWheel: function (event) {
            const maxContentY = Math.max(0, root.flickable.contentHeight - root.flickable.height);
            if (maxContentY <= 0) {
                event.accepted = true;
                return;
            }

            // High-precision touchpad 2-finger gesture with pixelDelta:
            // Apply instant, zero-latency pixel tracking scaled by speedMultiplier
            if (event.pixelDelta && event.pixelDelta.y !== 0) {
                scrollAnimation.stop();
                const delta = event.pixelDelta.y * root.speedMultiplier;
                const newY = Math.max(0, Math.min(maxContentY, root.flickable.contentY - delta));
                if (newY !== root.flickable.contentY) {
                    root.flickable.contentY = newY;
                    root.scrolled();
                }
                event.accepted = true;
                return;
            }

            // Discrete mouse wheel notch (angleDelta):
            if (event.angleDelta.y !== 0) {
                const currentTargetY = scrollAnimation.running ? Number(scrollAnimation.to) : root.flickable.contentY;
                const deltaY = (event.angleDelta.y / 120.0) * root.stepSize * root.speedMultiplier;
                const newTargetY = Math.max(0, Math.min(maxContentY, currentTargetY - deltaY));

                if (newTargetY !== root.flickable.contentY) {
                    scrollAnimation.stop();
                    scrollAnimation.from = root.flickable.contentY;
                    scrollAnimation.to = newTargetY;
                    scrollAnimation.start();
                    root.scrolled();
                }
                event.accepted = true;
            }
        }
    }
}
