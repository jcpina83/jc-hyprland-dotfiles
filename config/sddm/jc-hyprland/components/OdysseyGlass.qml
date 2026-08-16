import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // -------------------------------------------------------------------------
    // SDDM runtime contract
    // -------------------------------------------------------------------------

    property var userModelRef
    property var sessionModelRef

    signal loginRequested(
        string user,
        string password,
        int sessionIndex
    )

    signal suspendRequested()
    signal rebootRequested()
    signal powerOffRequested()

    signal authenticationFailed()

    // -------------------------------------------------------------------------
    // Theme contract
    // -------------------------------------------------------------------------

    property url backgroundSource: ""

    property color backgroundColor: "#0b1020"

    property color panelColor: "#99151a2a"
    property color panelBorderColor: "#66cba6f7"

    property color primaryColor: "#89b4fa"
    property color secondaryColor: "#cba6f7"

    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"

    property date currentDate: new Date()

    property int sessionIndex:
        root.sessionModelRef && root.sessionModelRef.lastIndex >= 0
            ? root.sessionModelRef.lastIndex
            : 0


    // -------------------------------------------------------------------------
    // Authentication behavior
    // -------------------------------------------------------------------------

    function submitLogin() {
        authenticationMessage.text = ""

        root.loginRequested(
            usernameInput.text,
            passwordInput.text,
            root.sessionIndex
        )
    }

    onAuthenticationFailed: {
        passwordInput.text = ""
        authenticationMessage.text = "Authentication failed"
        passwordInput.forceActiveFocus()
    }


    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: root.currentDate = new Date()
    }


    // -------------------------------------------------------------------------
    // Background
    // -------------------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    Image {
        anchors.fill: parent

        source: root.backgroundSource

        fillMode: Image.PreserveAspectCrop

        asynchronous: true
        cache: true
        smooth: true
    }


    // -------------------------------------------------------------------------
    // Subtle readable gradient behind the login side
    // -------------------------------------------------------------------------

    Rectangle {
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }

        width: parent.width * 0.46

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0.0
                color: "#cc080b16"
            }

            GradientStop {
                position: 0.72
                color: "#66101827"
            }

            GradientStop {
                position: 1.0
                color: "#00101827"
            }
        }
    }


    // -------------------------------------------------------------------------
    // Glass login panel
    // -------------------------------------------------------------------------

    Rectangle {
        id: loginPanel

        anchors {
            left: parent.left
            leftMargin: Math.max(28, parent.width * 0.035)

            verticalCenter: parent.verticalCenter
        }

        width: Math.min(610, parent.width * 0.38)
        height: Math.min(820, parent.height * 0.92)

        radius: 28

        color: root.panelColor

        border.width: 1
        border.color: root.panelBorderColor


        // ---------------------------------------------------------------------
        // Soft inner illumination
        // ---------------------------------------------------------------------

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }

            height: 170

            radius: parent.radius

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "#22cba6f7"
                }

                GradientStop {
                    position: 1.0
                    color: "#00151a2a"
                }
            }
        }


        ColumnLayout {
            anchors {
                fill: parent

                leftMargin: 58
                rightMargin: 58
                topMargin: 52
                bottomMargin: 46
            }

            spacing: 18


            // -----------------------------------------------------------------
            // Clock
            // -----------------------------------------------------------------

            Text {
                Layout.alignment: Qt.AlignHCenter

                text: Qt.formatDateTime(
                    root.currentDate,
                    "HH:mm"
                )

                color: root.textColor

                font.pixelSize: 70
                font.weight: Font.Light
            }

            Text {
                Layout.alignment: Qt.AlignHCenter

                text: Qt.formatDateTime(
                    root.currentDate,
                    "dddd, dd MMMM yyyy"
                )

                color: root.mutedColor

                font.pixelSize: 17
            }


            Item {
                Layout.preferredHeight: 12
            }


            // -----------------------------------------------------------------
            // Username
            // -----------------------------------------------------------------

            Text {
                text: "Username"

                color: root.textColor

                font.pixelSize: 15
                font.weight: Font.Medium
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58

                radius: 14

                color: "#33101827"

                border.width: 1
                border.color: root.panelBorderColor

                TextInput {
                    id: usernameInput

                    anchors {
                        fill: parent

                        leftMargin: 20
                        rightMargin: 20
                    }

                    verticalAlignment: TextInput.AlignVCenter

                    color: root.textColor
                    selectionColor: root.primaryColor

                    font.pixelSize: 16

                    clip: true
                    activeFocusOnTab: true

                    Keys.onReturnPressed: passwordInput.forceActiveFocus()
                    Keys.onEnterPressed: passwordInput.forceActiveFocus()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        visible: usernameInput.text.length === 0

                        text: "Enter your username"

                        color: root.mutedColor

                        font.pixelSize: 16
                    }
                }
            }


            // -----------------------------------------------------------------
            // Password
            // -----------------------------------------------------------------

            Text {
                text: "Password"

                color: root.textColor

                font.pixelSize: 15
                font.weight: Font.Medium
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58

                radius: 14

                color: "#33101827"

                border.width: 1
                border.color: root.panelBorderColor

                TextInput {
                    id: passwordInput

                    anchors {
                        fill: parent

                        leftMargin: 20
                        rightMargin: 20
                    }

                    verticalAlignment: TextInput.AlignVCenter

                    echoMode: TextInput.Password

                    color: root.textColor
                    selectionColor: root.primaryColor

                    font.pixelSize: 16

                    clip: true
                    activeFocusOnTab: true

                    Keys.onReturnPressed: root.submitLogin()
                    Keys.onEnterPressed: root.submitLogin()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        visible: passwordInput.text.length === 0

                        text: "Enter your password"

                        color: root.mutedColor

                        font.pixelSize: 16
                    }
                }
            }


            // -----------------------------------------------------------------
            // Session
            // -----------------------------------------------------------------

            Text {
                text: "Session"

                color: root.textColor

                font.pixelSize: 15
                font.weight: Font.Medium
            }

            Item {
                id: sessionArea

                Layout.fillWidth: true
                Layout.preferredHeight: 58

                // Hidden adapter: use SDDM's session model while keeping
                // Odyssey Glass' original custom field styling.
                ComboBox {
                    id: sessionAdapter

                    visible: false

                    model: root.sessionModelRef
                    textRole: "name"
                    currentIndex: root.sessionIndex
                }

                Rectangle {
                    anchors.fill: parent

                    radius: 14

                    color: "#33101827"

                    border.width: 1
                    border.color: sessionPopup.opened
                        ? root.secondaryColor
                        : root.panelBorderColor

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 20
                            right: sessionChevron.left
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }

                        text: sessionAdapter.displayText.length > 0
                            ? sessionAdapter.displayText
                            : "Hyprland"

                        color: root.textColor

                        elide: Text.ElideRight

                        font.pixelSize: 16
                    }

                    Text {
                        id: sessionChevron

                        anchors {
                            right: parent.right
                            rightMargin: 20
                            verticalCenter: parent.verticalCenter
                        }

                        text: sessionPopup.opened ? "⌃" : "⌄"

                        color: root.secondaryColor

                        font.pixelSize: 24
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (sessionPopup.opened) {
                                sessionPopup.close()
                            } else {
                                sessionPopup.open()
                            }
                        }
                    }
                }

                Popup {
                    id: sessionPopup

                    x: 0
                    y: sessionArea.height + 6

                    width: sessionArea.width
                    height: Math.min(sessionList.contentHeight + 12, 250)

                    padding: 6

                    closePolicy: Popup.CloseOnEscape
                        | Popup.CloseOnPressOutside

                    contentItem: ListView {
                        id: sessionList

                        clip: true

                        model: root.sessionModelRef
                        currentIndex: root.sessionIndex

                        delegate: Rectangle {
                            width: sessionList.width
                            height: 44

                            radius: 10

                            color: index === root.sessionIndex
                                ? "#33101827"
                                : "transparent"

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: 14
                                    right: parent.right
                                    rightMargin: 14
                                    verticalCenter: parent.verticalCenter
                                }

                                text: model.name

                                color: index === root.sessionIndex
                                    ? root.textColor
                                    : root.mutedColor

                                elide: Text.ElideRight

                                font.pixelSize: 15
                            }

                            MouseArea {
                                anchors.fill: parent

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.sessionIndex = index
                                    sessionPopup.close()
                                }
                            }
                        }

                        ScrollIndicator.vertical: ScrollIndicator {}
                    }

                    background: Rectangle {
                        radius: 14

                        color: "#ee151a2a"

                        border.width: 1
                        border.color: root.panelBorderColor
                    }
                }
            }


            Item {
                Layout.preferredHeight: 8
            }


            // -----------------------------------------------------------------
            // Login
            // -----------------------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58

                radius: 15

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0.0
                        color: root.secondaryColor
                    }

                    GradientStop {
                        position: 1.0
                        color: root.primaryColor
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: "LOGIN"

                    color: "#ffffff"

                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                }

                MouseArea {
                    anchors.fill: parent

                    cursorShape: Qt.PointingHandCursor

                    onClicked: root.submitLogin()
                }
            }


            Text {
                id: authenticationMessage

                Layout.fillWidth: true

                visible: text.length > 0
                text: ""

                color: "#ff6b81"

                horizontalAlignment: Text.AlignHCenter

                font.pixelSize: 13
            }


            Item {
                Layout.fillHeight: true
            }


            // -----------------------------------------------------------------
            // Session actions
            // -----------------------------------------------------------------

            RowLayout {
                Layout.fillWidth: true

                spacing: 26

                Repeater {
                    model: [
                        {
                            symbol: "◐",
                            label: "Sleep"
                        },
                        {
                            symbol: "↻",
                            label: "Restart"
                        },
                        {
                            symbol: "⏻",
                            label: "Shutdown"
                        }
                    ]

                    delegate: ColumnLayout {
                        Layout.fillWidth: true

                        spacing: 8

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter

                            width: 48
                            height: 48

                            radius: 24

                            color: "#44101827"

                            border.width: 1
                            border.color: root.panelBorderColor

                            Text {
                                anchors.centerIn: parent

                                text: modelData.symbol

                                color: root.textColor

                                font.pixelSize: 23
                            }

                            MouseArea {
                                anchors.fill: parent

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    if (modelData.label === "Sleep") {
                                        root.suspendRequested()
                                    } else if (modelData.label === "Restart") {
                                        root.rebootRequested()
                                    } else if (modelData.label === "Shutdown") {
                                        root.powerOffRequested()
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter

                            text: modelData.label

                            color: root.mutedColor

                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }


    // -------------------------------------------------------------------------
    // Initial user / focus
    // -------------------------------------------------------------------------

    Repeater {
        model: root.userModelRef

        delegate: Item {
            Component.onCompleted: {
                if (
                    root.userModelRef &&
                    index === root.userModelRef.lastIndex
                ) {
                    usernameInput.text = model.name

                    Qt.callLater(function() {
                        passwordInput.forceActiveFocus()
                    })
                }
            }
        }
    }

    Component.onCompleted: {
        // Fallback only if SDDM does not provide a selectable user.
        if (!root.userModelRef || root.userModelRef.count === 0) {
            Qt.callLater(function() {
                usernameInput.forceActiveFocus()
            })
        }
    }
}
