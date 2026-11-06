# SPDX-FileCopyrightText: 2026 Meow <meow@zenpanel.local>
# SPDX-License-Identifier: GPL-2.0-or-later

include(ECMQmlModule)

add_library(zenpanel_panel STATIC
    zendockpanel.h
    zendockpanel.cpp
)

kconfig_add_kcfg_files(zenpanel_panel GENERATE_MOC
    config/zenpanelsettings.kcfgc
)

target_include_directories(zenpanel_panel PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/backend
    ${CMAKE_CURRENT_SOURCE_DIR}/config
    ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_BINARY_DIR}/src
)

target_link_libraries(zenpanel_panel PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Quick
    Qt6::QuickWidgets
    Qt6::QuickControls2
    Qt6::Qml
    KF6::CoreAddons
    KF6::ConfigCore
    KF6::ConfigGui
    KF6::I18n
    KF6::I18nQml
    KF6::ItemModels
    KF6::KIOWidgets
    KF6::Kirigami
    KF6::KIOFileWidgets
    KF6::Bookmarks
    KF6::IconThemes
    KF6::XmlGui
    dolphinprivate
)

ecm_add_qml_module(zenpanel_panel
    URI "org.kde.dolphin.zenpanel"
    VERSION 1.0
    SOURCES
        backend/ZenPanelBridge.h
        backend/ZenPanelBridge.cpp
        backend/ZenPlacesMasterModel.h
        backend/ZenPlacesMasterModel.cpp
        backend/ZenNetworkPlacesModel.h
        backend/ZenNetworkPlacesModel.cpp
        backend/ZenSectionFilterProxy.h
        backend/ZenSectionFilterProxy.cpp
        backend/ZenTabsModel.h
        backend/ZenTabsModel.cpp
        backend/ZenFolderTreeModel.h
        backend/ZenFolderTreeModel.cpp
        backend/ZenSettingsWidget.h
        backend/ZenSettingsWidget.cpp
    QML_FILES
        ui/ZenPanel.qml
        ui/components/ZenTileDelegate.qml
        ui/components/ZenSectionHeader.qml
        ui/components/ZenPlaceListDelegate.qml
        ui/components/ZenDeviceDelegate.qml
        ui/components/ZenScrollBar.qml
        ui/components/ZenToolTip.qml
        ui/components/ZenSettingsDialog.qml
        ui/sections/EssentialsSection.qml
        ui/sections/TrashSection.qml
        ui/sections/DevicesSection.qml
        ui/sections/workspace/WorkspacePlacesAndTabs.qml
        ui/sections/workspace/WorkspaceTreeView.qml
        ui/sections/workspace/WorkspaceSection.qml
)
