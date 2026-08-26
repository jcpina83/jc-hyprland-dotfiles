import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.components as Components

PanelWindow {
    id: root

    required property var targetScreen
    required property var theme

    property string title: "Control Center"
    property string activeModuleId: "displays"
    property string activeModuleTitle: "Displays"
    property string statusText: "Ready"
    property string statusDetail: ""
    property bool transitionLocked: false
    property Component contentComponent: null

    readonly property var activeContentItem:
        contentLoader.item

    readonly property int preferredWidth: 1080
    readonly property int preferredHeight: 820
    readonly property int screenMargin: root.theme.spaceMd

    readonly property int availableScreenWidth:
        root.targetScreen
            ? Math.max(
                1,
                Number(root.targetScreen.width)
                    - (root.screenMargin * 2)
            )
            : root.preferredWidth

    readonly property int availableScreenHeight:
        root.targetScreen
            ? Math.max(
                1,
                Number(root.targetScreen.height)
                    - (root.screenMargin * 2)
            )
            : root.preferredHeight

    signal closeRequested()
    signal moduleRequested(string moduleId)

    function requestInitialFocus() {
        Qt.callLater(function() {
            navigation.focusActiveItem();
        });
    }

    function playShellEnterMotion() {
        shellEnterAnimation.restart();
    }

    function playStatusMotion() {
        statusRow.opacity = root.theme.opacitySubtle;
        statusChangeAnimation.restart();
    }

    screen: root.targetScreen

    implicitWidth:
        Math.min(
            root.preferredWidth,
            root.availableScreenWidth
        )

    implicitHeight:
        Math.min(
            root.preferredHeight,
            root.availableScreenHeight
        )

    color: "transparent"
    focusable: true
    exclusiveZone: 0

    anchors {
        top: true
        right: true
    }

    margins {
        top: root.screenMargin
        right: root.screenMargin
    }

    Shortcut {
        sequence: "Escape"

        onActivated: {
            if (!root.transitionLocked)
                root.closeRequested();
        }
    }

    onVisibleChanged: {
        if (root.visible) {
            root.requestInitialFocus();
            root.playShellEnterMotion();
        }
    }

    onStatusTextChanged: {
        if (root.visible)
            Qt.callLater(root.playStatusMotion);
    }

    Component.onCompleted: {
        if (root.visible) {
            root.requestInitialFocus();
            root.playShellEnterMotion();
        }
    }

    ParallelAnimation {
        id: shellEnterAnimation

        NumberAnimation {
            target: shellSurface
            property: "opacity"

            from: 0.0
            to: root.theme.opacityEnabled

            duration: root.theme.motionPanel
            easing.type: root.theme.easingEnter
        }

        NumberAnimation {
            target: shellTranslate
            property: "x"

            from: root.theme.spaceSm
            to: 0

            duration: root.theme.motionPanel
            easing.type: root.theme.easingEnter
        }
    }

    ParallelAnimation {
        id: contentEnterAnimation

        NumberAnimation {
            target: contentLoader
            property: "opacity"

            from: 0.0
            to: root.theme.opacityEnabled

            duration: root.theme.motionSelection
            easing.type: root.theme.easingEnter
        }

        NumberAnimation {
            target: contentTranslate
            property: "x"

            from: root.theme.spaceSm
            to: 0

            duration: root.theme.motionSelection
            easing.type: root.theme.easingEnter
        }
    }

    NumberAnimation {
        id: statusChangeAnimation

        target: statusRow
        property: "opacity"

        to: root.theme.opacityEnabled

        duration: root.theme.motionSelection
        easing.type: root.theme.easingEnter
    }

    Components.JcSurface {
        id: shellSurface

        anchors.fill: parent

        opacity: root.theme.opacityEnabled

        transform: Translate {
            id: shellTranslate
            x: 0
        }

        theme: root.theme
        surfaceRole: "glass-raised"
        cornerRadius: root.theme.radiusXl

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.theme.spaceLg

            spacing: root.theme.spaceLg

            RowLayout {
                Layout.fillWidth: true
                spacing: root.theme.spaceMd

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: root.title
                    subtitle: root.activeModuleTitle
                }

                Components.JcIconButton {
                    theme: root.theme
                    icon: "×"
                    accessibleName: "Close Control Center"
                    controlEnabled: !root.transitionLocked

                    onClicked: root.closeRequested()
                }
            }

            Components.JcDivider {
                Layout.fillWidth: true
                theme: root.theme
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: root.theme.spaceMd

                ControlCenterNavigation {
                    id: navigation

                    Layout.preferredWidth:
                        root.theme.controlHeightLarge * 5

                    Layout.fillHeight: true

                    theme: root.theme
                    activeModuleId: root.activeModuleId
                    navigationLocked: root.transitionLocked

                    onModuleRequested: moduleId =>
                        root.moduleRequested(moduleId)
                }

                Item {
                    id: contentHost

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Loader {
                        id: contentLoader

                        anchors.fill: parent

                        opacity: root.theme.opacityEnabled
                        sourceComponent: root.contentComponent

                        transform: Translate {
                            id: contentTranslate
                            x: 0
                        }

                        onLoaded:
                            contentEnterAnimation.restart()
                    }
                }
            }

            Components.JcDivider {
                Layout.fillWidth: true
                theme: root.theme
            }

            RowLayout {
                id: statusRow

                Layout.fillWidth: true
                spacing: root.theme.spaceMd

                opacity: root.theme.opacityEnabled

                Text {
                    text: root.statusText

                    color: root.transitionLocked
                        ? root.theme.warning
                        : root.theme.textSecondary

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.motionSelection
                            easing.type: root.theme.easingStandard
                        }
                    }

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeBody
                    font.weight: root.theme.fontWeightMedium
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    Layout.maximumWidth:
                        Math.max(240, root.implicitWidth * 0.46)

                    text: root.statusDetail
                    color: root.theme.textMuted

                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                }
            }
        }
    }
}
