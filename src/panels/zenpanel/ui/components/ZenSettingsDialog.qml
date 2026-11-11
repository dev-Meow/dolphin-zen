// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ki18n
import org.kde.dolphin.zenpanel

/**
 * @brief Configuration page for ZenPanel.
 *
 * Implements a structured, categorized tab-based interface:
 * - Tab 1: General (Appearance & Trash)
 * - Tab 2: Essentials (Quick-access grid)
 * - Tab 3: Workspace (Places, Tabs & Folder Tree)
 * - Tab 4: Devices (Devices & Storage)
 */
Kirigami.ScrollablePage {
    id: root

    required property ZenPanelBridge bridge
    property bool showCloseButton: true

    title: KI18n.i18nc("@title:window", "ZenPanel Settings")

    readonly property var sectionIconSizeModel: [
        {
            text: KI18n.i18nc("@item:inlistbox", "follow \"General\" setting"),
            value: 0
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "16 Pixels (Very Small)"),
            value: 16
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "22 Pixels (Standard / Small)"),
            value: 22
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "32 Pixels (Medium)"),
            value: 32
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "48 Pixels (Large)"),
            value: 48
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "64 Pixels (Very Large)"),
            value: 64
        }
    ]

    readonly property var globalIconStyleModel: [
        {
            text: KI18n.i18nc("@item:inlistbox", "System Theme"),
            value: 0
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "always colorful"),
            value: 1
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "always schematic"),
            value: 2
        }
    ]

    readonly property var sectionIconStyleModel: [
        {
            text: KI18n.i18nc("@item:inlistbox", "follow \"General\" setting"),
            value: 0
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "System Theme"),
            value: 1
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "always colorful"),
            value: 2
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "always schematic"),
            value: 3
        }
    ]

    function findModelIndex(modelArray: var, val: int): int {
        if (!modelArray) {
            return 0;
        }
        for (let i = 0; i < modelArray.length; ++i) {
            if (modelArray[i].value === val) {
                return i;
            }
        }
        return 0;
    }

    // Category navigation bar at the top of the settings page
    header: QQC2.TabBar {
        id: categoryTabBar
        currentIndex: 0
        width: parent.width

        QQC2.TabButton {
            text: KI18n.i18nc("@title:tab", "General")
        }
        QQC2.TabButton {
            text: KI18n.i18nc("@title:tab", "Essentials")
        }
        QQC2.TabButton {
            text: KI18n.i18nc("@title:tab", "Workspace")
        }
        QQC2.TabButton {
            text: KI18n.i18nc("@title:tab", "Devices")
        }
    }

    // Category content pages
    StackLayout {
        id: categoryStack
        currentIndex: categoryTabBar.currentIndex
        width: parent ? parent.width : 0
        implicitHeight: (currentIndex >= 0 && currentIndex < count && itemAt(currentIndex)) ? itemAt(currentIndex).implicitHeight : 0

        // =============================================================
        // TAB 1: GENERAL (APPEARANCE & TRASH)
        // =============================================================
        Kirigami.FormLayout {
            id: generalTab
            Layout.fillWidth: true

            Kirigami.Heading {
                Kirigami.FormData.isSection: true
                text: KI18n.i18nc("@title:group", "Appearance")
            }

            QQC2.Label {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 25
                text: KI18n.i18nc("@info:whatsthis", "General settings are applied to all sections of ZenPanel, but can be overwritten in each section.")
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                wrapMode: Text.WordWrap
            }

            QQC2.ComboBox {
                id: lookFeelCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Display List Elements as:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"

                model: [
                    {
                        text: KI18n.i18nc("@item:inlistbox", "Dolphin Style (compact)"),
                        value: 0
                    },
                    {
                        text: KI18n.i18nc("@item:inlistbox", "Kirigami Style"),
                        value: 1
                    }
                ]

                currentIndex: root.bridge ? root.bridge.lookFeelMode : 0

                onActivated: {
                    if (root.bridge) {
                        root.bridge.lookFeelMode = lookFeelCombo.currentValue;
                    }
                }
            }

            QQC2.ComboBox {
                id: globalIconStyleCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Display Icons as:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.globalIconStyleModel

                currentIndex: root.findModelIndex(root.globalIconStyleModel, root.bridge ? root.bridge.globalIconStyle : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.globalIconStyle = globalIconStyleCombo.currentValue;
                    }
                }
            }

            QQC2.Label {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 25
                text: KI18n.i18nc("@info:whatsthis", "Icon packs can be incomplete, but most provide symbolic icons up to 22px and colorful icons for larger settings automaticaly. If set so, ZenPanel tries to overwrite this behavior, by scaling up, or down.")
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                wrapMode: Text.WordWrap
            }

            QQC2.ComboBox {
                id: iconSizeCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Global Icon Size:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"

                model: [
                    {
                        text: KI18n.i18nc("@item:inlistbox", "Automatic (Dolphin Default)"),
                        value: -1
                    },
                    {
                        text: KI18n.i18nc("@item:inlistbox", "16 Pixels (Very Small)"),
                        value: 16
                    },
                    {
                        text: KI18n.i18nc("@item:inlistbox", "22 Pixels (Standard / Small)"),
                        value: 22
                    },
                    {
                        text: KI18n.i18nc("@item:inlistbox", "32 Pixels (Medium)"),
                        value: 32
                    },
                    {
                        text: KI18n.i18nc("@item:inlistbox", "48 Pixels (Large)"),
                        value: 48
                    },
                    {
                        text: KI18n.i18nc("@item:inlistbox", "64 Pixels (Very Large)"),
                        value: 64
                    }
                ]

                currentIndex: root.findModelIndex(iconSizeCombo.model, root.bridge ? root.bridge.placesIconSizeSetting : -1)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.placesIconSizeSetting = iconSizeCombo.currentValue;
                    }
                }
            }

            Kirigami.Heading {
                Kirigami.FormData.isSection: true
                text: KI18n.i18nc("@title:group", "Trash")
            }

            QQC2.CheckBox {
                id: showTrashCheck
                text: KI18n.i18nc("@option:check", "Show trash section.")
                checked: root.bridge ? root.bridge.showTrashSection : true
                onToggled: {
                    if (root.bridge) {
                        root.bridge.showTrashSection = checked;
                    }
                }
            }

            QQC2.Label {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 25
                text: KI18n.i18nc("@info:whatsthis", "If selected, the trash section will be shown at the bottom (or right side, if docked horizontally) of ZenPanel.")
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                wrapMode: Text.WordWrap
            }

            QQC2.ComboBox {
                id: customTrashIconStyleCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Set icon style to:")
                enabled: showTrashCheck.checked
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.sectionIconStyleModel
                currentIndex: root.findModelIndex(root.sectionIconStyleModel, root.bridge ? root.bridge.customTrashIconStyle : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.customTrashIconStyle = customTrashIconStyleCombo.currentValue;
                    }
                }
            }

            QQC2.ComboBox {
                id: customTrashIconCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Set icon size to:")
                enabled: showTrashCheck.checked
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.sectionIconSizeModel
                currentIndex: root.findModelIndex(root.sectionIconSizeModel, root.bridge ? root.bridge.customTrashIconSize : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.customTrashIconSize = customTrashIconCombo.currentValue;
                    }
                }
            }
        }

        // =============================================================
        // TAB 2: ESSENTIALS (QUICK ACCESS GRID)
        // =============================================================
        Kirigami.FormLayout {
            id: essentialsTab
            Layout.fillWidth: true

            Kirigami.Heading {
                Kirigami.FormData.isSection: true
                text: KI18n.i18nc("@title:group", "Essentials")
            }

            QQC2.Label {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 25
                text: KI18n.i18nc("@info:whatsthis", "\"Essentials\" is the top (left, if docked horizontally) section of ZenPanel and provides a space saving icon grid for quick access. Icons can be arranged freely by drag & drop. There are several ways to add entries: drag & drop, context menu, or a dedicated \"add icon\" that can be activated.")
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                wrapMode: Text.WordWrap
            }

            QQC2.SpinBox {
                id: maxEssentialsSpin
                Kirigami.FormData.label: KI18n.i18nc("@label:spinbox", "Limit the allowed number of icons to:")
                Layout.maximumWidth: Kirigami.Units.gridUnit * 10
                from: 3
                to: 30
                stepSize: 1
                value: root.bridge ? root.bridge.maxEssentials : 12

                onValueModified: {
                    if (root.bridge) {
                        root.bridge.maxEssentials = value;
                    }
                }
            }

            QQC2.CheckBox {
                id: showAddButtonCheck
                Kirigami.FormData.label: KI18n.i18nc("@label:checkbox", "Add [+]:")
                text: KI18n.i18nc("@option:check", "Display an \"add\" icon [+]")
                checked: root.bridge ? root.bridge.showAddEssentialButton : true
                onToggled: {
                    if (root.bridge) {
                        root.bridge.showAddEssentialButton = checked;
                    }
                }
            }

            Kirigami.Heading {
                Kirigami.FormData.isSection: true
                text: KI18n.i18nc("@title:group", "Icon settings:")
            }

            QQC2.ComboBox {
                id: customEssentialsIconStyleCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Set icon style to:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.sectionIconStyleModel
                currentIndex: root.findModelIndex(root.sectionIconStyleModel, root.bridge ? root.bridge.customEssentialsIconStyle : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.customEssentialsIconStyle = customEssentialsIconStyleCombo.currentValue;
                    }
                }
            }

            QQC2.ComboBox {
                id: customEssentialsIconCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Set icon size to:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.sectionIconSizeModel
                currentIndex: root.findModelIndex(root.sectionIconSizeModel, root.bridge ? root.bridge.customEssentialsIconSize : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.customEssentialsIconSize = customEssentialsIconCombo.currentValue;
                    }
                }
            }
        }

        // =============================================================
        // TAB 3: WORKSPACE (PLACES, TABS & FOLDER TREE)
        // =============================================================
        Kirigami.FormLayout {
            id: workspaceTab
            Layout.fillWidth: true

            Kirigami.Heading {
                Kirigami.FormData.isSection: true
                text: KI18n.i18nc("@title:group", "Places & Bookmarks")
            }

            QQC2.Label {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 25
                text: KI18n.i18nc("@info:whatsthis", "\"Workspace\" is the middle section of ZenPanel. It consists of \"Places & Bookmarks\", a list style panel and \"Folders\", a tree view style panel, between which you can easily switch.")
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                wrapMode: Text.WordWrap
            }

            QQC2.ComboBox {
                id: defaultViewCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Default View:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"

                model: [
                    {
                        text: KI18n.i18nc("@item:inlistbox", "Places"),
                        value: 0
                    },
                    {
                        text: KI18n.i18nc("@item:inlistbox", "Folders"),
                        value: 1
                    }
                ]

                currentIndex: root.bridge ? root.bridge.defaultWorkspaceView : 0

                onActivated: {
                    if (root.bridge) {
                        root.bridge.defaultWorkspaceView = defaultViewCombo.currentValue;
                    }
                }
            }

            QQC2.Label {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 25
                text: KI18n.i18nc("@info:whatsthis", "Panel which will be displayed by default at startup.")
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                wrapMode: Text.WordWrap
            }

            QQC2.ComboBox {
                id: customPlacesIconStyleCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Set icon style to:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.sectionIconStyleModel
                currentIndex: root.findModelIndex(root.sectionIconStyleModel, root.bridge ? root.bridge.customPlacesIconStyle : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.customPlacesIconStyle = customPlacesIconStyleCombo.currentValue;
                    }
                }
            }

            QQC2.ComboBox {
                id: customPlacesIconCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Set icon size to:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.sectionIconSizeModel
                currentIndex: root.findModelIndex(root.sectionIconSizeModel, root.bridge ? root.bridge.customPlacesIconSize : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.customPlacesIconSize = customPlacesIconCombo.currentValue;
                    }
                }
            }

            QQC2.CheckBox {
                id: highlightTabsCheck
                Kirigami.FormData.label: KI18n.i18nc("@label:checkbox", "Tabs:")
                text: KI18n.i18nc("@option:check", "Highlight places currently open in tabs.")
                checked: root.bridge ? root.bridge.highlightOpenTabPlaces : true
                onToggled: {
                    if (root.bridge) {
                        root.bridge.highlightOpenTabPlaces = checked;
                    }
                }
            }

            QQC2.CheckBox {
                id: switchTabsCheck
                text: KI18n.i18nc("@option:check", "Switch to tab, if already open.")
                checked: root.bridge ? root.bridge.switchToExistingTab : true
                onToggled: {
                    if (root.bridge) {
                        root.bridge.switchToExistingTab = checked;
                    }
                }
            }

            QQC2.CheckBox {
                id: hideEssentialsInWorkspaceCheck
                Kirigami.FormData.label: KI18n.i18nc("@label:checkbox", "Auto hide:")
                text: KI18n.i18nc("@option:check", "Hide places already in quick access.")
                checked: root.bridge ? root.bridge.hideEssentialsInWorkspace : true
                onToggled: {
                    if (root.bridge) {
                        root.bridge.hideEssentialsInWorkspace = checked;
                    }
                }
            }

            Kirigami.Heading {
                Kirigami.FormData.isSection: true
                text: KI18n.i18nc("@title:group", "Folders")
            }

            QQC2.CheckBox {
                id: limitHomeCheck
                Kirigami.FormData.label: KI18n.i18nc("@label:checkbox", "Tree Scope:")
                text: KI18n.i18nc("@option:check", "Limit to user's home folder")
                checked: root.bridge ? root.bridge.limitTreeToHome : true
                onToggled: {
                    if (root.bridge) {
                        root.bridge.limitTreeToHome = checked;
                    }
                }
            }

            QQC2.CheckBox {
                id: showHiddenCheck
                text: KI18n.i18nc("@option:check", "Show hidden folders.")
                checked: root.bridge ? root.bridge.showHiddenFoldersInTree : false
                onToggled: {
                    if (root.bridge) {
                        root.bridge.showHiddenFoldersInTree = checked;
                    }
                }
            }

            QQC2.ComboBox {
                id: customTreeIconStyleCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Set icon style to:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.sectionIconStyleModel
                currentIndex: root.findModelIndex(root.sectionIconStyleModel, root.bridge ? root.bridge.customTreeIconStyle : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.customTreeIconStyle = customTreeIconStyleCombo.currentValue;
                    }
                }
            }

            QQC2.ComboBox {
                id: customTreeIconCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Set icon size to:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.sectionIconSizeModel
                currentIndex: root.findModelIndex(root.sectionIconSizeModel, root.bridge ? root.bridge.customTreeIconSize : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.customTreeIconSize = customTreeIconCombo.currentValue;
                    }
                }
            }
        }

        // =============================================================
        // TAB 4: DEVICES (DEVICES & STORAGE)
        // =============================================================
        Kirigami.FormLayout {
            id: devicesTab
            Layout.fillWidth: true

            Kirigami.Heading {
                Kirigami.FormData.isSection: true
                text: KI18n.i18nc("@title:group", "Devices & Network")
            }

            QQC2.Label {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 25
                text: KI18n.i18nc("@info:whatsthis", "\"Devices\" is the bottom (right, if docked horizontally) section of ZenPanel. It lists removable media, mounted partitions, and optionally network devices. It collapses, if not in use, but individual devices, or the section itself can be pinned.")
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                wrapMode: Text.WordWrap
            }

            QQC2.CheckBox {
                id: pinDevicesCheck
                Kirigami.FormData.label: KI18n.i18nc("@label:checkbox", "Pin Section:")
                text: KI18n.i18nc("@option:check", "Keep devices section permanently pinned (only if docked left or right)")
                checked: root.bridge ? root.bridge.devicesPinned : false
                onToggled: {
                    if (root.bridge) {
                        root.bridge.devicesPinned = checked;
                    }
                }
            }

            QQC2.CheckBox {
                id: expandNetworkCheck
                Kirigami.FormData.label: KI18n.i18nc("@label:checkbox", "Network Folder:")
                text: KI18n.i18nc("@option:check", "List network folder items directly as individual devices")
                checked: root.bridge ? root.bridge.expandNetworkFolder : false
                onToggled: {
                    if (root.bridge) {
                        root.bridge.expandNetworkFolder = checked;
                    }
                }
            }

            QQC2.ComboBox {
                id: customDevicesIconStyleCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Set icon style to:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.sectionIconStyleModel
                currentIndex: root.findModelIndex(root.sectionIconStyleModel, root.bridge ? root.bridge.customDevicesIconStyle : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.customDevicesIconStyle = customDevicesIconStyleCombo.currentValue;
                    }
                }
            }

            QQC2.ComboBox {
                id: customDevicesIconCombo
                Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Set icon size to:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                textRole: "text"
                valueRole: "value"
                model: root.sectionIconSizeModel
                currentIndex: root.findModelIndex(root.sectionIconSizeModel, root.bridge ? root.bridge.customDevicesIconSize : 0)

                onActivated: {
                    if (root.bridge) {
                        root.bridge.customDevicesIconSize = customDevicesIconCombo.currentValue;
                    }
                }
            }
        }
    }

    footer: QQC2.DialogButtonBox {
        visible: root.showCloseButton
        standardButtons: QQC2.DialogButtonBox.Close
        onClicked: function (button) {
            if (root.bridge) {
                root.bridge.closeSettingsDialog();
            }
        }
    }
}
