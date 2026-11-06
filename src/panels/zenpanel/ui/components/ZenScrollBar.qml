pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

/**
 * Minimalist, Zen Browser-inspired vertical/horizontal ScrollBar component (Tier 2).
 *
 * Features:
 * - Renders only a sleek rounded scroll handle without any QStyle groove or vertical separator line.
 * - Smoothly fades in when the parent section gains mouse/keyboard focus, pointer motion, or scroll activity.
 * - Smoothly fades out after a short inactivity timeout unless the handle itself is hovered or dragged.
 */
T.ScrollBar {
    id: root

    // External activity triggers bound by the enclosing section
    property bool sectionHovered: false
    property bool sectionFocused: false

    // Internal transient visibility state controlled by the inactivity timer
    property bool isRevealed: false

    readonly property bool isNeeded: root.size > 0.0 && root.size < 1.0 && root.policy !== T.ScrollBar.AlwaysOff

    implicitWidth: root.vertical ? Math.max(6, Math.round(Kirigami.Units.smallSpacing * 1.5)) : 0
    implicitHeight: root.horizontal ? Math.max(6, Math.round(Kirigami.Units.smallSpacing * 1.5)) : 0

    padding: 1
    hoverEnabled: true
    interactive: root.isNeeded

    /**
     * Reveals the scrollbar handle and restarts the auto-hide countdown.
     */
    function revealTemporarily() {
        if (!root.isNeeded) {
            root.isRevealed = false;
            hideTimer.stop();
            return;
        }
        root.isRevealed = true;
        if (!root.pressed && !root.hovered) {
            hideTimer.restart();
        } else {
            hideTimer.stop();
        }
    }

    onSectionHoveredChanged: {
        if (root.sectionHovered) {
            root.revealTemporarily();
        }
    }

    onSectionFocusedChanged: {
        if (root.sectionFocused) {
            root.revealTemporarily();
        }
    }

    onPositionChanged: {
        root.revealTemporarily();
    }

    onSizeChanged: {
        if (root.isNeeded && (root.sectionHovered || root.sectionFocused)) {
            root.revealTemporarily();
        } else if (!root.isNeeded) {
            root.isRevealed = false;
        }
    }

    onHoveredChanged: {
        if (root.hovered) {
            root.isRevealed = true;
            hideTimer.stop();
        } else if (root.isRevealed) {
            hideTimer.restart();
        }
    }

    onPressedChanged: {
        if (root.pressed) {
            root.isRevealed = true;
            hideTimer.stop();
        } else if (root.isRevealed) {
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 900
        repeat: false
        onTriggered: {
            if (!root.pressed && !root.hovered) {
                root.isRevealed = false;
            }
        }
    }

    // Explicitly empty background to suppress qqc2-desktop-style's QStyle groove and vertical separator
    background: Item {}

    contentItem: Rectangle {
        id: handleRect
        implicitWidth: root.vertical ? Math.max(4, root.implicitWidth - 2) : 0
        implicitHeight: root.horizontal ? Math.max(4, root.implicitHeight - 2) : 0
        radius: width / 2

        color: (root.pressed || root.hovered)
            ? Kirigami.Theme.highlightColor
            : Kirigami.Theme.textColor

        opacity: {
            if (!root.isNeeded) {
                return 0.0;
            }
            if (root.pressed) {
                return 0.85;
            }
            if (root.hovered) {
                return 0.70;
            }
            if (root.isRevealed) {
                return 0.42;
            }
            return 0.0;
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
}

