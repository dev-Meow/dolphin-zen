// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: root

    // --- Configuration ---
    property string text: ""
    property bool showActionButton: true
    property bool actionEnabled: true
    property string actionIconName: ""
    property string actionToolTipText: ""
    property bool actionCheckable: false
    property bool actionChecked: false
    property ZenPanelBridge bridge: null

    // Dwell duration for drag-hover auto-expand in ms (KDE Dolphin standard: 750 ms)
    property int dragHoverInterval: 750

    // --- Signals ---
    signal actionTriggered()
    signal actionToggled(bool checked)
    signal dragHoverTriggered()

    implicitWidth: Kirigami.Units.gridUnit * 10
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.6)

    Accessible.role: Accessible.Grouping
    Accessible.name: root.text

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // Section title (adheres cleanly to global KDE/Dolphin font settings)
        QQC2.Label {
            id: label
            Layout.fillWidth: true
            text: root.text
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            font.family: Kirigami.Theme.defaultFont.family
            font.weight: Font.DemiBold
            color: Kirigami.Theme.textColor
            opacity: 0.85
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        // Optional action button (e.g. view toggle or pin toggle)
        QQC2.ToolButton {
            id: actionButton
            visible: root.showActionButton && root.actionIconName.length > 0
            enabled: root.actionEnabled
            activeFocusOnTab: true
            Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 1.3)
            Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 1.3)
            icon.name: root.actionIconName
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
            checkable: root.actionCheckable
            checked: root.actionChecked

            // Subtle highlight background behind icon for drag hover, trigger pulse and keyboard focus
            Rectangle {
                id: actionButtonHighlight
                anchors.fill: parent
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.highlightColor
                opacity: dropArea.containsDrag ? 0.22 : (actionButton.activeFocus ? 0.18 : 0.0)
                border.width: (dropArea.containsDrag || actionButton.activeFocus) ? 1 : 0
                border.color: actionButton.activeFocus ? Kirigami.Theme.focusColor : Kirigami.Theme.highlightColor
                z: -1

                Behavior on opacity {
                    enabled: !triggerFeedbackAnim.running
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
            }

            // Visual feedback animation triggered on dwell threshold
            SequentialAnimation {
                id: triggerFeedbackAnim
                running: false

                ParallelAnimation {
                    NumberAnimation {
                        target: actionButton
                        property: "scale"
                        from: 1.0
                        to: 1.18
                        duration: 80
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: actionButtonHighlight
                        property: "opacity"
                        from: 0.7
                        to: 0.7
                        duration: 80
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: actionButton
                        property: "scale"
                        from: 1.18
                        to: 1.0
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: actionButtonHighlight
                        property: "opacity"
                        from: 0.7
                        to: dropArea.containsDrag ? 0.22 : 0.0
                        duration: 220
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Accessible.name: root.actionToolTipText.length > 0 ? root.actionToolTipText : root.text

            function triggerAction() {
                triggerFeedbackAnim.restart();
                if (root.actionCheckable) {
                    root.actionToggled(!root.actionChecked);
                } else {
                    root.actionTriggered();
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Space) {
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    actionButton.triggerAction();
                    event.accepted = true;
                }
            }

            onClicked: {
                actionButton.triggerAction();
            }
        }
    }

    ZenToolTip {
        bridge: root.bridge
        hovered: actionButton.hovered && !actionButton.down
        keyboardFocused: actionButton.activeFocus
        text: root.actionToolTipText
    }

    // --- Smart drag-hover detection ---
    DropArea {
        id: dropArea
        anchors.fill: parent

        onEntered: {
            hoverTimer.restart();
        }

        onExited: {
            hoverTimer.stop();
        }

        onDropped: {
            hoverTimer.stop();
        }
    }

    Timer {
        id: hoverTimer
        interval: root.dragHoverInterval
        repeat: false
        onTriggered: {
            if (dropArea.containsDrag) {
                triggerFeedbackAnim.restart();
                root.dragHoverTriggered();
            }
        }
    }
}
