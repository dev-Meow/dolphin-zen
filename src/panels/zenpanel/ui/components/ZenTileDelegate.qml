pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel
import org.kde.ki18n

/**
 *Lightweight tile delegate for essentials section
 */
Item {
    id: root

    // --- Required model roles injected by ListView ---
    required property int index
    property string display: ""
    property var decoration: "folder"
    property url url: ""
    property string formattedPath: ""
    property bool isHidden: false
    property bool isEssential: false

    property ZenPanelBridge bridge: null

    // --- External state flags ---
    property bool isAddButton: false
    property bool isCurrentLocation: false
    property bool isOpenInAnyTab: false
    property bool isDropTarget: false

    // --- Touch / Drag state ---
    property bool isHeld: false
    property bool isDragging: false
    property int pressStartX: 0
    property int pressStartY: 0

    // --- Focus state ---
    readonly property bool isItemFocused: root.activeFocus

    // --- Signals to Host ---
    signal clicked
    signal middleClicked
    signal rightClicked(point mousePos)
    signal addClicked
    signal urlsDropped(var urls, point globalPos)
    signal dragStarted(int fromIndex, point grabLocalPt)
    signal dragMoved(point globalPos)
    signal dragFinished(int fromIndex)
    signal dragCanceled()

    implicitWidth: root.bridge ? root.bridge.essentialsTileWidth : Math.round(Kirigami.Units.gridUnit * 3.0)
    implicitHeight: root.bridge ? root.bridge.essentialsTileHeight : Math.round(Kirigami.Units.gridUnit * 2.5)
    opacity: root.isDragging ? 0.35 : (root.isHidden ? 0.6 : 1.0)
    scale: root.isHeld ? 1.04 : 1.0
    z: root.isDragging ? 100 : 0

    Behavior on scale {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }

    focus: true
    activeFocusOnTab: false

    // Full accessibility support following KDE HIG
    Accessible.role: Accessible.Button
    Accessible.name: root.isAddButton ? KI18n.i18nc("@action:button", "Add new quick access item") : root.display
    Accessible.description: root.formattedPath

    onIsItemFocusedChanged: {
        if (root.isItemFocused && root.bridge) {
            root.bridge.focusedItemDescription = root.isAddButton ? "[+] Add Quick Access" : root.display;
        }
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (root.isAddButton) {
                root.addClicked();
            } else {
                root.clicked();
            }
            event.accepted = true;
        }
    }

    // Tile element background container
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: root.bridge ? root.bridge.itemRadius : Kirigami.Units.cornerRadius

        color: {
            if (root.isDropTarget) {
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
            return Kirigami.Theme.alternateBackgroundColor;
        }

        border.color: ((root.isItemFocused && (!root.bridge || root.bridge.keyboardNavigationActive)) || root.isHeld || root.isDropTarget || dropArea.containsDrag) ? Kirigami.Theme.focusColor : "transparent"
        border.width: root.isDropTarget ? 2 : 1

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
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.bottomMargin: Kirigami.Units.smallSpacing
            width: 3
            radius: 1.5
            color: Kirigami.Theme.highlightColor
            opacity: 0.7
            visible: root.isCurrentLocation
        }

        // Essential Icon
        Kirigami.Icon {
            id: tileIcon
            anchors.centerIn: parent
            width: root.bridge ? root.bridge.essentialsIconSize : Kirigami.Units.iconSizes.medium
            height: width
            source: {
                if (!root.bridge) {
                    return root.isAddButton ? "list-add" : root.decoration;
                }
                const _rev = root.bridge.themeMetricsRevision;
                return root.bridge.resolveSectionIcon(root.isAddButton ? "list-add" : root.decoration, "essentials");
            }
            opacity: root.isAddButton ? 0.7 : 1.0
            isMask: root.isAddButton || (root.bridge ? root.bridge.isSectionIconMask(root.decoration, "essentials") : false)
            color: (root.isCurrentLocation || root.isItemFocused) ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        }
    }

    // Pointer interaction area
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onPressed: function (mouse) {
            root.pressStartX = mouse.x;
            root.pressStartY = mouse.y;
            if (root.bridge) {
                root.bridge.notifyMouseInteraction("essentials");
            }
        }

        onPressAndHold: function (mouse) {
            if (!root.isAddButton && mouse.button === Qt.LeftButton) {
                if (root.bridge) {
                    root.bridge.notifyTouchInteraction("essentials");
                }
                root.isHeld = true;
                mouseArea.preventStealing = true;
                root.dragStarted(root.index, Qt.point(mouse.x, mouse.y));
            }
        }

        onPositionChanged: function (mouse) {
            if (!root.isAddButton) {
                const dist = Math.hypot(mouse.x - root.pressStartX, mouse.y - root.pressStartY);
                if (!root.isDragging) {
                    if (root.isHeld && dist > 8) {
                        root.isDragging = true;
                        mouseArea.preventStealing = false;
                        root.dragStarted(root.index, Qt.point(root.pressStartX, root.pressStartY));
                    } else if ((mouse.buttons & Qt.LeftButton) && dist > 8) {
                        root.isDragging = true;
                        root.isHeld = true;
                        root.dragStarted(root.index, Qt.point(root.pressStartX, root.pressStartY));
                    }
                }
                if (root.isDragging) {
                    const globalPt = root.mapToGlobal(mouse.x, mouse.y);
                    root.dragMoved(Qt.point(globalPt.x, globalPt.y));
                }
            }
        }

        onReleased: function (mouse) {
            if (root.isDragging) {
                root.dragFinished(root.index);
            }
            root.isDragging = false;
            root.isHeld = false;
            mouseArea.preventStealing = false;
        }

        onCanceled: {
            if (root.isDragging) {
                root.dragCanceled();
            }
            root.isDragging = false;
            root.isHeld = false;
            mouseArea.preventStealing = false;
        }

        onClicked: function (mouse) {
            if (root.isDragging) {
                return;
            }
            root.forceActiveFocus();
            if (mouse.button === Qt.LeftButton) {
                if (root.isAddButton) {
                    root.addClicked();
                } else if (mouse.modifiers & Qt.ControlModifier) {
                    root.middleClicked();
                } else {
                    root.clicked();
                }
            } else if (mouse.button === Qt.MiddleButton) {
                if (!root.isAddButton) {
                    root.middleClicked();
                }
            } else if (mouse.button === Qt.RightButton) {
                if (!root.isAddButton) {
                    root.rightClicked(Qt.point(mouse.x, mouse.y));
                }
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

    HoverHandler {
        id: hoverHandler
    }

    // Dolphin-style delayed overlay tooltip (indented to item center, placed below when space permits)
    ZenToolTip {
        bridge: root.bridge
        hovered: hoverHandler.hovered && !mouseArea.containsPress
        keyboardFocused: root.isItemFocused
        text: {
            if (root.isAddButton) {
                return KI18n.i18nc("@info:tooltip", "Pin new quick access item");
            }
            if (root.formattedPath.length > 0 && root.formattedPath !== root.display) {
                return root.display + " (" + root.formattedPath + ")";
            }
            return root.display;
        }
    }
}
