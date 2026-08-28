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

    // requestedVisible is the application-level presentation request.
    // mounted keeps the PanelWindow alive until exit motion completes.
    property bool requestedVisible: false
    property bool mounted: false
    property var presentationScreen: null

    readonly property real closedPresentationScale: 0.985

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

    function beginOpenPresentation() {
        shellExitAnimation.stop();

        if (root.targetScreen)
            root.presentationScreen = root.targetScreen;

        const wasMounted = root.mounted;

        if (!wasMounted) {
            shellSurface.opacity = 0.0;
            shellSurface.scale = root.closedPresentationScale;
            root.mounted = true;
        }

        Qt.callLater(function() {
            if (!root.requestedVisible)
                return;

            shellEnterAnimation.restart();
            root.requestInitialFocus();
        });
    }

    function beginClosePresentation() {
        if (!root.mounted)
            return;

        shellEnterAnimation.stop();
        shellExitAnimation.restart();
    }

    function playStatusMotion() {
        statusRow.opacity = root.theme.opacitySubtle;
        statusChangeAnimation.restart();
    }

    visible: root.mounted

    screen:
        root.presentationScreen
            || root.targetScreen

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

    // Intentionally unanchored: PanelWindow is presented as a
    // centered HUD/modal on presentationScreen instead of a sidebar.

    Shortcut {
        sequence: "Escape"

        onActivated: {
            if (!root.transitionLocked)
                root.closeRequested();
        }
    }

    onRequestedVisibleChanged: {
        if (root.requestedVisible)
            root.beginOpenPresentation();
        else
            root.beginClosePresentation();
    }

    onTargetScreenChanged: {
        // Allow an explicit output change while open, but keep the last
        // presentation screen frozen during exit motion.
        if (root.requestedVisible && root.targetScreen)
            root.presentationScreen = root.targetScreen;
    }

    onStatusTextChanged: {
        if (root.requestedVisible)
            Qt.callLater(root.playStatusMotion);
    }

    Component.onCompleted: {
        if (root.requestedVisible && !root.mounted)
            root.beginOpenPresentation();
    }

    ParallelAnimation {
        id: shellEnterAnimation

        NumberAnimation {
            target: shellSurface
            property: "opacity"

            to: root.theme.opacityEnabled

            duration: root.theme.motionPanel
            easing.type: root.theme.easingEnter
        }

        NumberAnimation {
            target: shellSurface
            property: "scale"

            to: 1.0

            duration: root.theme.motionPanel
            easing.type: root.theme.easingEnter
        }
    }

    ParallelAnimation {
        id: shellExitAnimation

        NumberAnimation {
            target: shellSurface
            property: "opacity"

            to: 0.0

            duration: root.theme.motionPanel
            easing.type: root.theme.easingStandard
        }

        NumberAnimation {
            target: shellSurface
            property: "scale"

            to: root.closedPresentationScale

            duration: root.theme.motionPanel
            easing.type: root.theme.easingStandard
        }

        onFinished: {
            if (root.requestedVisible) {
                root.beginOpenPresentation();
                return;
            }

            root.mounted = false;
            root.presentationScreen = null;
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

        opacity: 0.0
        scale: root.closedPresentationScale
        transformOrigin: Item.Center

        theme: root.theme
        surfaceRole: "glass-raised"
        bordered: false
        fillEnabled: false

        Components.JcHudFrame {
            id: shellHudFrame

            anchors.fill: parent
            anchors.margins: root.theme.space2Xs

            theme: root.theme
            surfaceRole: "glass-raised"

            fillEnabled: true
            fillColor: root.theme.surfaceGlassRaised
            contentPadding: 0

            cutSize: root.theme.spaceLg
            accentLength: root.theme.controlHeightLarge * 2

            glowEnabled: true
            showInnerFrame: true
            showCornerAccents: true
            showSecondaryAccent: true
        }
        cornerRadius: root.theme.radiusXl

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.theme.spaceLg

            spacing: root.theme.spaceLg

            RowLayout {
                Layout.fillWidth: true
                spacing: root.theme.spaceMd

                Item {
                    id: headerHudIndicator

                    Layout.preferredWidth:
                        root.theme.controlHeightDefault
                    Layout.preferredHeight:
                        root.theme.controlHeightDefault
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        id: headerHudConnector

                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.horizontalCenter
                        anchors.right: parent.right

                        height: root.theme.borderWidthStrong

                        color: root.theme.primary
                        opacity: root.theme.opacityDisabled
                    }

                    Rectangle {
                        anchors.centerIn: parent

                        width: root.theme.iconSizeLg
                        height: width
                        radius: width / 2

                        color: root.theme.transparentSurface

                        border.width:
                            root.theme.borderWidthThin
                        border.color:
                            root.theme.hudInnerFrame
                    }

                    Rectangle {
                        id: headerHudCore

                        anchors.centerIn: parent

                        width: root.theme.spaceSm
                        height: width
                        radius: width / 2

                        color: root.theme.primary
                    }
                }

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: root.title
                    subtitle: root.activeModuleTitle
                }

                Components.JcIconButton {
                    theme: root.theme
                    iconName: "close"
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

                Rectangle {
                    id: statusHudIndicator

                    Layout.preferredWidth: root.theme.spaceSm
                    Layout.preferredHeight: root.theme.spaceSm
                    Layout.alignment: Qt.AlignVCenter

                    radius: width / 2

                    color: root.transitionLocked
                        ? root.theme.warning
                        : root.theme.success

                    border.width:
                        root.theme.borderWidthThin
                    border.color:
                        root.transitionLocked
                            ? root.theme.warningBorder
                            : root.theme.successBorder

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.motionSelection
                            easing.type: root.theme.easingStandard
                        }
                    }
                }

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
