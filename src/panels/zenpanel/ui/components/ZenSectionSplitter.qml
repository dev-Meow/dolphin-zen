// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/**
 * @brief Interactive section divider combining a 1px Kirigami.Separator hairline
 *        with an expanded hover/drag grab zone when unlocked.
 */
Item {
    id: root

    required property bool isVertical
    property bool canResizeVertical: false
    property bool canResizeHorizontal: false

    readonly property bool canResize: root.canResizeVertical || root.canResizeHorizontal

    signal resizeStarted(bool vertical)
    signal resizeMoved(real delta, bool vertical)
    signal resizeFinished()

    Layout.fillWidth: root.isVertical
    Layout.fillHeight: !root.isVertical
    Layout.preferredWidth: root.isVertical ? -1 : (root.canResizeHorizontal ? Kirigami.Units.smallSpacing * 2 : 1)
    Layout.preferredHeight: root.isVertical ? (root.canResizeVertical ? Kirigami.Units.smallSpacing * 2 : 1) : -1
    Layout.leftMargin: root.isVertical ? Kirigami.Units.smallSpacing : 0
    Layout.rightMargin: root.isVertical ? Kirigami.Units.smallSpacing : 0
    Layout.topMargin: root.isVertical ? 0 : Kirigami.Units.smallSpacing
    Layout.bottomMargin: root.isVertical ? 0 : Kirigami.Units.smallSpacing

    Kirigami.Separator {
        anchors.centerIn: parent
        width: root.isVertical ? parent.width : 1
        height: root.isVertical ? 1 : parent.height
        weight: Kirigami.Separator.Weight.Light
    }

    // Visual highlight across the wider interactive grab area while hovered or dragged
    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.highlightColor
        opacity: (resizerMouse.containsMouse || resizerMouse.pressed) ? 0.35 : 0.0
        visible: root.canResize
        radius: 1
    }

    MouseArea {
        id: resizerMouse
        anchors.fill: parent
        enabled: root.canResize
        hoverEnabled: enabled
        cursorShape: root.canResizeVertical ? Qt.SplitVCursor : (root.canResizeHorizontal ? Qt.SplitHCursor : Qt.ArrowCursor)
        preventStealing: true

        property real startGlobalPos: 0

        onPressed: function (mouse) {
            const globalPt = resizerMouse.mapToGlobal(mouse.x, mouse.y);
            startGlobalPos = root.canResizeVertical ? globalPt.y : globalPt.x;
            root.resizeStarted(root.canResizeVertical);
        }

        onPositionChanged: function (mouse) {
            if (pressed && root.canResize) {
                const globalPt = resizerMouse.mapToGlobal(mouse.x, mouse.y);
                const pos = root.canResizeVertical ? globalPt.y : globalPt.x;
                root.resizeMoved(pos - startGlobalPos, root.canResizeVertical);
            }
        }

        onReleased: {
            root.resizeFinished();
        }
    }
}

