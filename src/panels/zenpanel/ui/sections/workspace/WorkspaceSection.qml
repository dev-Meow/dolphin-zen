// SPDX-FileCopyrightText: 2026 dev-Meow <355019589+dev-Meow@users.noreply.github.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ki18n
import org.kde.dolphin.zenpanel
import "../../components"

Item {
    id: root

    // --- Strongly typed model & state properties ---
    required property ZenSectionFilterProxy placesModel
    required property ZenTabsModel tabsModel
    required property ZenFolderTreeModel treeModel
    property ZenPanelBridge bridge: null
    property bool highlightOpenTabPlaces: true

    function focusFirstItem() {
        if (root.currentViewIndex === 0) {
            placesView.focusFirstPlace();
        } else {
            treeViewSection.focusFirstFolder();
        }
    }
    property int currentViewIndex: 0

    // --- Signals to controller / bridge ---
    signal placeClicked(url placeUrl)
    signal placeMiddleClicked(url placeUrl)
    signal placeRightClicked(int row, point mousePos)
    signal placeUrlsDropped(url targetUrl, var droppedUrls, point globalPos)
    signal placesBackgroundRightClicked(point globalPos)
    signal folderRightClicked(url folderUrl, point globalPos)
    signal treeBackgroundRightClicked(url rootUrl, point globalPos)
    signal viewModeChanged(int newIndex)

    implicitWidth: Kirigami.Units.gridUnit * 10
    implicitHeight: Kirigami.Units.gridUnit * 18

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // Section header with [⇄] view-mode switcher
        ZenSectionHeader {
            id: header
            bridge: root.bridge
            Layout.fillWidth: true
            text: root.currentViewIndex === 0 ? KI18n.i18nc("@title:group", "Places") : KI18n.i18nc("@title:group", "Folders")
            actionIconName: "exchange-positions"
            actionCheckable: false
            actionToolTipText: root.currentViewIndex === 0 ? KI18n.i18nc("@info:tooltip", "Switch to Folders") : KI18n.i18nc("@info:tooltip", "Switch to \"Places\"")

            onActionTriggered: {
                root.currentViewIndex = (root.currentViewIndex === 0) ? 1 : 0;
                root.viewModeChanged(root.currentViewIndex);
            }

            // Smart-Switch: Toggle between Places and Tree view on sustained drag-hover
            onDragHoverTriggered: {
                root.currentViewIndex = (root.currentViewIndex === 0) ? 1 : 0;
                root.viewModeChanged(root.currentViewIndex);
            }
        }

        // Dynamic StackLayout fills remaining vertical/horizontal space
        StackLayout {
            id: stackLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentViewIndex

            // View 0: Workspace Places
            WorkspacePlacesAndTabs {
                id: placesView
                placesModel: root.placesModel
                tabsModel: root.tabsModel
                bridge: root.bridge
                highlightOpenTabPlaces: root.highlightOpenTabPlaces

                onPlaceClicked: function (placeUrl) {
                    root.placeClicked(placeUrl);
                }

                onPlaceMiddleClicked: function (placeUrl) {
                    root.placeMiddleClicked(placeUrl);
                }

                onPlaceRightClicked: function (row, mousePos) {
                    root.placeRightClicked(row, mousePos);
                }

                onPlaceUrlsDropped: function (targetUrl, droppedUrls, globalPos) {
                    root.placeUrlsDropped(targetUrl, droppedUrls, globalPos);
                }

                onBackgroundRightClicked: function (globalPos) {
                    root.placesBackgroundRightClicked(globalPos);
                }
            }

            // Ansicht 1: KDirModel Verzeichnisbaum
            WorkspaceTreeView {
                id: treeViewSection
                Layout.fillWidth: true
                Layout.fillHeight: true
                treeModel: root.treeModel
                tabsModel: root.tabsModel
                bridge: root.bridge

                onFolderClicked: function (folderUrl) {
                    root.placeClicked(folderUrl);
                }
                onFolderMiddleClicked: function (folderUrl) {
                    root.placeMiddleClicked(folderUrl);
                }
                onFolderRightClicked: function (folderUrl, globalPos) {
                    root.folderRightClicked(folderUrl, globalPos);
                }
                onFolderUrlsDropped: function (targetUrl, droppedUrls, globalPos) {
                    root.placeUrlsDropped(targetUrl, droppedUrls, globalPos);
                }
                onBackgroundRightClicked: function (rootUrl, globalPos) {
                    root.treeBackgroundRightClicked(rootUrl, globalPos);
                }
            }
        }
    }
}
