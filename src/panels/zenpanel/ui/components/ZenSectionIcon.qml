// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.dolphin.zenpanel

/**
 * @brief Shared section-aware icon wrapper around Kirigami.Icon.
 *
 * Centralizes theme revision reactivity, section icon resolution
 * (color vs. monochrome symbolic), mask detection, and Breeze active coloring.
 */
Kirigami.Icon {
    id: root

    property ZenPanelBridge bridge: null
    required property string section
    property string iconName: ""
    property string fallbackIcon: "folder"
    property bool highlighted: false
    property bool forceMask: false

    readonly property string effectiveIconName: root.iconName.length > 0 ? root.iconName : root.fallbackIcon

    source: {
        if (!root.bridge) {
            return root.effectiveIconName;
        }
        const _rev = root.bridge.themeMetricsRevision;
        return root.bridge.resolveSectionIcon(root.effectiveIconName, root.section);
    }

    isMask: root.forceMask || (root.bridge ? root.bridge.isSectionIconMask(root.effectiveIconName, root.section) : false)
    color: root.highlighted ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
}

