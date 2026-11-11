// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// SPDX-FileCopyrightText: 2026 Meow <meow@example.com>

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

/**
 * @brief Compact, theme-resilient disk capacity bar based on standard QQC2.ProgressBar.
 *
 * Provides a slim (3-4px) Dolphin-style capacity gauge that is completely immune to
 * desktop style overrides (such as plasma-union's CSS selector issues) while preserving
 * standard QQC2 ProgressBar contracts, value bindings, and accessibility semantics.
 */
QQC2.ProgressBar {
    id: control

    from: 0
    to: 100

    implicitWidth: 100
    implicitHeight: Math.max(3, Math.round(Kirigami.Units.smallSpacing * 0.75))

    hoverEnabled: false

    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0

    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0

    contentItem: Item {
        implicitWidth: control.implicitWidth
        implicitHeight: control.implicitHeight

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, Math.min(parent.width, control.position * parent.width))
            radius: height / 2

            color: control.value > 95 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor

            Behavior on width {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    background: Rectangle {
        implicitWidth: control.implicitWidth
        implicitHeight: control.implicitHeight
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
    }
}

