pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.ki18n
import org.kde.dolphin.zenpanel

/**
 * @brief Configuration modal dialog for ZenPanel (Milestone 5.3).
 *
 * Implements a structured, accessible Kirigami.FormLayout organized in the
 * same vertical section order as the ZenPanel dock layout:
 * 1. Quick Access (Essentials)
 * 2. Workspace & Tabs
 * 3. Devices & Folder Tree
 * 4. Trash
 * 5. General Appearance & Style
 */
Kirigami.ScrollablePage {
    id: root

    required property ZenPanelBridge bridge
    property bool showCloseButton: true

    title: KI18n.i18nc("@title:window", "ZenPanel Settings")

    readonly property var sectionIconSizeModel: [
        {
            text: KI18n.i18nc("@item:inlistbox", "Follow Global Setting"),
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
            text: KI18n.i18nc("@item:inlistbox", "KDE Standard (Theme default from 32px)"),
            value: 0
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "Full Color (Always rich color)"),
            value: 1
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "Schematic / Monochrome (Always outline)"),
            value: 2
        }
    ]

    readonly property var sectionIconStyleModel: [
        {
            text: KI18n.i18nc("@item:inlistbox", "Follow Global Setting"),
            value: 0
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "KDE Standard (Theme default from 32px)"),
            value: 1
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "Full Color (Always rich color)"),
            value: 2
        },
        {
            text: KI18n.i18nc("@item:inlistbox", "Schematic / Monochrome (Always outline)"),
            value: 3
        }
    ]

    function findComboIndex(combo: Controls.ComboBox, val: int): int {
        for (let i = 0; i < combo.count; ++i) {
            if (combo.valueAt(i) === val) {
                return i;
            }
        }
        return 0;
    }

    // Form layout for settings fields
    Kirigami.FormLayout {
        id: formLayout
        width: root.width

        // =============================================================
        // SECTION 1: Quick Access (Essentials) - Matches top panel area
        // =============================================================
        Kirigami.Heading {
            Kirigami.FormData.isSection: true
            text: KI18n.i18nc("@title:group", "Quick Access (Essentials)")
        }

        Controls.SpinBox {
            id: maxEssentialsSpin
            Kirigami.FormData.label: KI18n.i18nc("@label:spinbox", "Maximum Tiles:")
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

        Controls.ComboBox {
            id: customEssentialsIconStyleCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Tile Icon Style:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: root.sectionIconStyleModel
            currentIndex: root.findComboIndex(customEssentialsIconStyleCombo, root.bridge ? root.bridge.customEssentialsIconStyle : 0)

            onActivated: {
                if (root.bridge) {
                    root.bridge.customEssentialsIconStyle = customEssentialsIconStyleCombo.currentValue;
                }
            }
        }

        Controls.ComboBox {
            id: customEssentialsIconCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Tile Icon Size:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: root.sectionIconSizeModel
            currentIndex: root.findComboIndex(customEssentialsIconCombo, root.bridge ? root.bridge.customEssentialsIconSize : 0)

            onActivated: {
                if (root.bridge) {
                    root.bridge.customEssentialsIconSize = customEssentialsIconCombo.currentValue;
                }
            }
        }

        Controls.CheckBox {
            id: showAddButtonCheck
            text: KI18n.i18nc("@option:check", "Show add tile [+] at end of grid")
            checked: root.bridge ? root.bridge.showAddEssentialButton : true
            onToggled: {
                if (root.bridge) {
                    root.bridge.showAddEssentialButton = checked;
                }
            }
        }

        // =============================================================
        // SECTION 2: Workspace & Navigation - Matches middle panel area
        // =============================================================
        Kirigami.Heading {
            Kirigami.FormData.isSection: true
            text: KI18n.i18nc("@title:group", "Workspace & Tabs")
        }

        Controls.ComboBox {
            id: defaultViewCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Default View:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"

            model: [
                {
                    text: KI18n.i18nc("@item:inlistbox", "Places & Bookmarks"),
                    value: 0
                },
                {
                    text: KI18n.i18nc("@item:inlistbox", "Folder Structure (Tree View)"),
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

        Controls.ComboBox {
            id: customPlacesIconStyleCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Places Icon Style:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: root.sectionIconStyleModel
            currentIndex: root.findComboIndex(customPlacesIconStyleCombo, root.bridge ? root.bridge.customPlacesIconStyle : 0)

            onActivated: {
                if (root.bridge) {
                    root.bridge.customPlacesIconStyle = customPlacesIconStyleCombo.currentValue;
                }
            }
        }

        Controls.ComboBox {
            id: customPlacesIconCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Places Icon Size:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: root.sectionIconSizeModel
            currentIndex: root.findComboIndex(customPlacesIconCombo, root.bridge ? root.bridge.customPlacesIconSize : 0)

            onActivated: {
                if (root.bridge) {
                    root.bridge.customPlacesIconSize = customPlacesIconCombo.currentValue;
                }
            }
        }

        Controls.CheckBox {
            id: highlightTabsCheck
            Kirigami.FormData.label: KI18n.i18nc("@label:checkbox", "Tab Highlighting:")
            text: KI18n.i18nc("@option:check", "Subtly highlight places open in tabs/split view")
            checked: root.bridge ? root.bridge.highlightOpenTabPlaces : true
            onToggled: {
                if (root.bridge) {
                    root.bridge.highlightOpenTabPlaces = checked;
                }
            }
        }

        Controls.CheckBox {
            id: switchTabsCheck
            text: KI18n.i18nc("@option:check", "Switch to existing tab when clicking place")
            checked: root.bridge ? root.bridge.switchToExistingTab : true
            onToggled: {
                if (root.bridge) {
                    root.bridge.switchToExistingTab = checked;
                }
            }
        }

        // =============================================================
        // SECTION 3: Devices & Folder Tree - Matches lower panel area
        // =============================================================
        Kirigami.Heading {
            Kirigami.FormData.isSection: true
            text: KI18n.i18nc("@title:group", "Devices & Folder Tree")
        }

        Controls.CheckBox {
            id: pinDevicesCheck
            Kirigami.FormData.label: KI18n.i18nc("@label:checkbox", "Devices Section:")
            text: KI18n.i18nc("@option:check", "Keep devices section permanently pinned")
            checked: root.bridge ? root.bridge.devicesPinned : false
            onToggled: {
                if (root.bridge) {
                    root.bridge.devicesPinned = checked;
                }
            }
        }

        Controls.CheckBox {
            id: expandNetworkCheck
            text: KI18n.i18nc("@option:check", "List network folder items directly as individual devices")
            checked: root.bridge ? root.bridge.expandNetworkFolder : false
            onToggled: {
                if (root.bridge) {
                    root.bridge.expandNetworkFolder = checked;
                }
            }
        }

        Controls.ComboBox {
            id: customDevicesIconStyleCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Devices Icon Style:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: root.sectionIconStyleModel
            currentIndex: root.findComboIndex(customDevicesIconStyleCombo, root.bridge ? root.bridge.customDevicesIconStyle : 0)

            onActivated: {
                if (root.bridge) {
                    root.bridge.customDevicesIconStyle = customDevicesIconStyleCombo.currentValue;
                }
            }
        }

        Controls.ComboBox {
            id: customDevicesIconCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Devices Icon Size:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: root.sectionIconSizeModel
            currentIndex: root.findComboIndex(customDevicesIconCombo, root.bridge ? root.bridge.customDevicesIconSize : 0)

            onActivated: {
                if (root.bridge) {
                    root.bridge.customDevicesIconSize = customDevicesIconCombo.currentValue;
                }
            }
        }

        Controls.CheckBox {
            id: limitHomeCheck
            Kirigami.FormData.label: KI18n.i18nc("@label:checkbox", "Folder Tree:")
            text: KI18n.i18nc("@option:check", "Limit to user's home folder")
            checked: root.bridge ? root.bridge.limitTreeToHome : true
            onToggled: {
                if (root.bridge) {
                    root.bridge.limitTreeToHome = checked;
                }
            }
        }

        Controls.CheckBox {
            id: showHiddenCheck
            text: KI18n.i18nc("@option:check", "Show hidden folders in folder tree")
            checked: root.bridge ? root.bridge.showHiddenFoldersInTree : false
            onToggled: {
                if (root.bridge) {
                    root.bridge.showHiddenFoldersInTree = checked;
                }
            }
        }

        Controls.ComboBox {
            id: customTreeIconStyleCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Tree Icon Style:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: root.sectionIconStyleModel
            currentIndex: root.findComboIndex(customTreeIconStyleCombo, root.bridge ? root.bridge.customTreeIconStyle : 0)

            onActivated: {
                if (root.bridge) {
                    root.bridge.customTreeIconStyle = customTreeIconStyleCombo.currentValue;
                }
            }
        }

        Controls.ComboBox {
            id: customTreeIconCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Tree Icon Size:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: root.sectionIconSizeModel
            currentIndex: root.findComboIndex(customTreeIconCombo, root.bridge ? root.bridge.customTreeIconSize : 0)

            onActivated: {
                if (root.bridge) {
                    root.bridge.customTreeIconSize = customTreeIconCombo.currentValue;
                }
            }
        }

        // =============================================================
        // SECTION 4: Trash - Matches bottom panel area
        // =============================================================
        Kirigami.Heading {
            Kirigami.FormData.isSection: true
            text: KI18n.i18nc("@title:group", "Trash")
        }

        Controls.CheckBox {
            id: showTrashCheck
            Kirigami.FormData.label: KI18n.i18nc("@label:checkbox", "Trash Section:")
            text: KI18n.i18nc("@option:check", "Show dedicated trash section at bottom of panel")
            checked: root.bridge ? root.bridge.showTrashSection : true
            onToggled: {
                if (root.bridge) {
                    root.bridge.showTrashSection = checked;
                }
            }
        }

        // =============================================================
        // SECTION 5: General Appearance & Style
        // =============================================================
        Kirigami.Heading {
            Kirigami.FormData.isSection: true
            text: KI18n.i18nc("@title:group", "Appearance & Style")
        }

        Controls.ComboBox {
            id: lookFeelCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Look & Feel:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"

            model: [
                {
                    text: KI18n.i18nc("@item:inlistbox", "Dolphin Compact (Classic Information Density)"),
                    value: 0
                },
                {
                    text: KI18n.i18nc("@item:inlistbox", "Modern / Kirigami (Spacious & Touch-Friendly)"),
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

        Controls.ComboBox {
            id: globalIconStyleCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Global Icon Style:")
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: root.globalIconStyleModel

            currentIndex: root.findComboIndex(globalIconStyleCombo, root.bridge ? root.bridge.globalIconStyle : 0)

            onActivated: {
                if (root.bridge) {
                    root.bridge.globalIconStyle = globalIconStyleCombo.currentValue;
                }
            }
        }

        Controls.ComboBox {
            id: iconSizeCombo
            Kirigami.FormData.label: KI18n.i18nc("@label:listbox", "Global Icon Size:")
            Layout.fillWidth: true
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

            currentIndex: {
                if (!root.bridge) {
                    return 0;
                }
                const currentVal = root.bridge.placesIconSizeSetting;
                for (let i = 0; i < count; ++i) {
                    if (valueAt(i) === currentVal) {
                        return i;
                    }
                }
                return 0;
            }

            onActivated: {
                if (root.bridge) {
                    root.bridge.placesIconSizeSetting = iconSizeCombo.currentValue;
                }
            }
        }
    }

    footer: Controls.DialogButtonBox {
        visible: root.showCloseButton
        standardButtons: Controls.DialogButtonBox.Close
        onClicked: function(button) {
            if (root.bridge) {
                root.bridge.closeSettingsDialog();
            }
        }
    }
}
