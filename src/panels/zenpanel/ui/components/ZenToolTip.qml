pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel

/**
 * Dolphin-style overlay tooltip / accessibility hint (Tier 2).
 *
 * Positioning & exclusivity rules:
 * - Renders as a passive, pointer-transparent top-level overlay above panel contents.
 * - Horizontally indented to start at the horizontal center of the target item (`parent.width / 2`).
 * - Vertically positioned below the target item (`parent.height + 4`) as long as sufficient space
 *   is available below in the panel/overlay; automatically flips above (`-implicitHeight - 4`)
 *   for bottommost items (e.g. Trash or bottom Devices).
 * - Disables popup viewport margin clamping (`margins: -1`) so the background box scales freely
 *   with the full text width even when extending beyond the panel width.
 * - Strictly tied to the single active focus item (`keyboardFocused`) during keyboard navigation,
 *   or active mouse hover during mouse navigation. Touch interactions never show tooltips.
 */
T.ToolTip {
    id: root

    // True while the pointer is hovering the target item (not pressed)
    property bool hovered: false

    // True while the target item holds the single active focus in the panel
    property bool keyboardFocused: false

    // Computed vertical placement state (true = below item, false = above item)
    property bool placeBelow: true

    property ZenPanelBridge bridge: null

    readonly property bool isKeyboardMode: root.bridge ? root.bridge.keyboardNavigationActive : false
    readonly property bool isTouchMode: root.bridge ? root.bridge.touchInteractionActive : false

    Kirigami.Theme.colorSet: Kirigami.Theme.Tooltip
    Kirigami.Theme.inherit: false

    z: 9999

    // Make the popup completely transparent to pointer/hover events so it never blocks
    // MouseArea/HoverHandler state transitions on the underlying or neighboring items
    enabled: false
    closePolicy: T.Popup.NoAutoClose

    // Disable QQuickPopupPositioner viewport clamping so x stays at parent.width / 2
    // and the background width is never restricted to the panel width
    margins: -1
    padding: 6

    implicitWidth: Math.ceil(label.implicitWidth) + leftPadding + rightPadding
    implicitHeight: Math.ceil(label.implicitHeight) + topPadding + bottomPadding
    width: implicitWidth
    height: implicitHeight

    x: root.parent ? Math.round(root.parent.width / 2) : 0
    y: root.placeBelow ? (root.parent ? root.parent.height + 4 : 0) : (-root.implicitHeight - 4)

    delay: Kirigami.Units.toolTipDelay

    function updateVerticalPlacement() {
        const parentItem = root.parent;
        const overlayItem = parentItem ? parentItem.T.Overlay.overlay : null;
        if (!parentItem || !overlayItem) {
            root.placeBelow = true;
            return;
        }
        const bottomPt = parentItem.mapToItem(overlayItem, 0, parentItem.height);
        const requiredHeight = root.implicitHeight + 6;
        root.placeBelow = (bottomPt.y + requiredHeight) <= overlayItem.height;
    }

    function hideImmediately() {
        showTimer.stop();
        keyboardAutoHideTimer.stop();
        root.close();
    }

    function armShowTimer() {
        if (root.isTouchMode || root.text.length === 0) {
            root.hideImmediately();
            return;
        }
        if (root.isKeyboardMode) {
            if (root.keyboardFocused) {
                keyboardAutoHideTimer.stop();
                root.updateVerticalPlacement();
                showTimer.restart();
            } else {
                root.hideImmediately();
            }
        } else {
            // Mouse mode: triggered purely by hover
            if (root.hovered) {
                keyboardAutoHideTimer.stop();
                root.updateVerticalPlacement();
                showTimer.restart();
            } else {
                root.hideImmediately();
            }
        }
    }

    onHoveredChanged: {
        root.armShowTimer();
    }

    onKeyboardFocusedChanged: {
        root.armShowTimer();
    }

    onIsKeyboardModeChanged: {
        root.armShowTimer();
    }

    onIsTouchModeChanged: {
        if (root.isTouchMode) {
            root.hideImmediately();
        } else {
            root.armShowTimer();
        }
    }

    onTextChanged: {
        if (root.text.length === 0) {
            root.hideImmediately();
        } else if (root.visible) {
            root.updateVerticalPlacement();
        }
    }

    onImplicitHeightChanged: {
        if (root.visible) {
            root.updateVerticalPlacement();
        }
    }

    onOpened: {
        root.updateVerticalPlacement();
    }

    Timer {
        id: showTimer
        interval: root.delay > 0 ? root.delay : 500
        repeat: false
        onTriggered: {
            if (root.isTouchMode) {
                return;
            }
            const shouldOpen = root.isKeyboardMode ? root.keyboardFocused : root.hovered;
            if (shouldOpen && root.text.length > 0) {
                root.updateVerticalPlacement();
                root.open();
                if (root.isKeyboardMode) {
                    keyboardAutoHideTimer.restart();
                }
            }
        }
    }

    Timer {
        id: keyboardAutoHideTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (root.isKeyboardMode) {
                root.close();
            }
        }
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    contentItem: Controls.Label {
        id: label
        enabled: false
        text: root.text
        wrapMode: Text.NoWrap
        font: root.font
        color: Kirigami.Theme.textColor
        Kirigami.Theme.colorSet: Kirigami.Theme.Tooltip
    }

    background: Kirigami.ShadowedRectangle {
        enabled: false
        implicitWidth: Math.ceil(label.implicitWidth) + root.leftPadding + root.rightPadding
        implicitHeight: Math.ceil(label.implicitHeight) + root.topPadding + root.bottomPadding
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.backgroundColor
        Kirigami.Theme.colorSet: Kirigami.Theme.Tooltip

        shadow.xOffset: 0
        shadow.yOffset: 3
        shadow.size: 12
        shadow.color: Qt.rgba(0, 0, 0, 0.22)

        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
    }
}
