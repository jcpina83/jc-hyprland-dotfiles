import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    required property var theme
    property var mediaService
    property var actionService

    signal refreshRequested()
    signal playPauseRequested()
    signal nextRequested()
    signal previousRequested()
    signal seekRequested(real seconds)
    signal sinkVolumeRequested(real value)
    signal sinkMuteRequested(string mode)

    property real stagedSeekSeconds: 0
    property bool seekGestureDirty: false
    property real stagedSinkVolume: 0
    property bool sinkVolumeGestureDirty: false

    readonly property bool serviceReady:
        root.mediaService
        && Boolean(root.mediaService.ready)

    readonly property bool serviceLoading:
        root.mediaService
        && Boolean(root.mediaService.loading)

    readonly property bool playerAvailable:
        root.serviceReady
        && Boolean(root.mediaService.playerAvailable)

    readonly property bool actionBusy:
        root.actionService
        && Boolean(root.actionService.busy)

    readonly property string operationError: {
        if (root.actionService
                && root.actionService.errorMessage
                && String(root.actionService.errorMessage).length > 0) {
            return String(root.actionService.errorMessage);
        }

        return root.mediaService
            && root.mediaService.errorMessage
                ? String(root.mediaService.errorMessage)
                : "";
    }

    readonly property string operationStatus:
        root.actionService
        && root.actionService.statusMessage
            ? String(root.actionService.statusMessage)
            : ""

    readonly property real progressFraction: {
        if (!root.playerAvailable)
            return 0;

        const position = root.mediaService.positionSeconds;
        const duration = root.mediaService.trackLengthSeconds;

        if (!root.isNumeric(position)
                || !root.isNumeric(duration)
                || Number(duration) <= 0) {
            return 0;
        }

        return Math.max(
            0,
            Math.min(
                1,
                Number(position) / Number(duration)
            )
        );
    }

    readonly property string footerStatusText:
        "Interactive controls use the stable media action service · "
        + "Observed state refreshes every 1s while Media is visible."

    function isNumeric(value) {
        return typeof value === "number"
            && isFinite(value);
    }

    function textOrFallback(value, fallback) {
        const text = String(value || "").trim();

        return text.length > 0
            ? text
            : String(fallback || "Unavailable");
    }

    function formatDuration(value) {
        if (!root.isNumeric(value) || Number(value) < 0)
            return "--:--";

        let total = Math.floor(Number(value));
        const hours = Math.floor(total / 3600);

        total -= hours * 3600;

        const minutes = Math.floor(total / 60);
        const seconds = total - (minutes * 60);

        const minuteText = hours > 0 && minutes < 10
            ? "0" + minutes
            : String(minutes);
        const secondText = seconds < 10
            ? "0" + seconds
            : String(seconds);

        return hours > 0
            ? hours + ":" + minuteText + ":" + secondText
            : minuteText + ":" + secondText;
    }

    function formatVolume(value) {
        if (!root.isNumeric(value))
            return "Unavailable";

        return Math.round(
            Math.max(0, Number(value)) * 100
        ) + "%";
    }

    function capabilityLabel(index) {
        switch (index) {
        case 0:
            return "Previous";
        case 1:
            return "Play / Pause";
        case 2:
            return "Next";
        case 3:
            return "Seek";
        default:
            return "Control";
        }
    }

    function capabilityAvailable(index) {
        if (!root.actionService)
            return false;

        switch (index) {
        case 0:
            return root.actionService.canPrevious === true;
        case 1:
            return root.actionService.canPlayPause === true;
        case 2:
            return root.actionService.canNext === true;
        case 3:
            return root.actionService.canSeek === true;
        default:
            return false;
        }
    }

    function capabilityIcon(index) {
        switch (index) {
        case 0:
            return "previous";
        case 1:
            return root.mediaService
                && root.mediaService.playbackStatus === "Playing"
                    ? "pause"
                    : "play";
        case 2:
            return "next";
        case 3:
            return "media";
        default:
            return "media";
        }
    }

    function requestTransportAction(index): void {
        switch (index) {
        case 0:
            root.previousRequested();
            break;
        case 1:
            root.playPauseRequested();
            break;
        case 2:
            root.nextRequested();
            break;
        default:
            break;
        }
    }

    function audioDescription(isSink) {
        if (!root.mediaService)
            return "Unavailable";

        const available = isSink
            ? root.mediaService.sinkAvailable
            : root.mediaService.sourceAvailable;

        if (!available)
            return "Unavailable";

        const description = isSink
            ? root.mediaService.sinkDescription
            : root.mediaService.sourceDescription;

        const name = isSink
            ? root.mediaService.sinkName
            : root.mediaService.sourceName;

        return root.textOrFallback(
            description,
            root.textOrFallback(name, "Available")
        );
    }

    function audioVolume(isSink) {
        if (!root.mediaService)
            return "Unavailable";

        return root.formatVolume(
            isSink
                ? root.mediaService.sinkVolume
                : root.mediaService.sourceVolume
        );
    }

    function audioState(isSink) {
        if (!root.mediaService)
            return "Unavailable";

        const available = isSink
            ? root.mediaService.sinkAvailable
            : root.mediaService.sourceAvailable;

        if (!available)
            return "Unavailable";

        const muted = isSink
            ? root.mediaService.sinkMuted
            : root.mediaService.sourceMuted;

        if (muted === true)
            return "Muted";

        if (muted === false)
            return "Active";

        return "Observed";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.theme.spaceMd

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceMd

            Components.JcSectionHeader {
                Layout.fillWidth: true
                theme: root.theme
                title: "Media"
                subtitle:
                    root.playerAvailable
                        ? root.textOrFallback(
                            root.mediaService.playerIdentity,
                            "MPRIS player"
                        )
                        : "No active media player"
            }

            Components.JcButton {
                id: refreshButton

                theme: root.theme
                text: "Refresh"
                iconName: "refresh"
                compact: true
                controlEnabled:
                    Boolean(root.mediaService)
                    && !root.actionBusy

                // MediaService.refresh() already ignores concurrent refreshes.
                // Keep the control chrome stable while 1 s live polling runs.
                onClicked: root.refreshRequested()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.operationError.length > 0

            text: root.operationError
            color: root.theme.danger

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeBody
            font.weight: root.theme.fontWeightMedium

            wrapMode: Text.Wrap
        }

        Components.JcHudFrame {
            Layout.fillWidth: true
            Layout.minimumHeight:
                root.theme.controlHeightLarge * 5.5
            Layout.preferredHeight:
                root.theme.controlHeightLarge * 5.5

            theme: root.theme
            surfaceRole: "glass-raised"
            selected: root.playerAvailable
            primaryAccentColor: root.theme.primary
            secondaryAccentColor: root.theme.hudSecondaryAccent

            RowLayout {
                anchors.fill: parent
                spacing: root.theme.spaceLg

                Item {
                    Layout.preferredWidth:
                        Math.min(
                            parent.width * 0.34,
                            root.theme.controlHeightLarge * 5
                        )
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        radius: root.theme.radiusLg
                        color: root.theme.surfaceRaised
                        border.width: root.theme.borderWidthThin
                        border.color: root.theme.borderSubtle

                        Image {
                            id: artwork

                            anchors.fill: parent
                            anchors.margins: root.theme.space2Xs

                            source:
                                root.playerAvailable
                                && root.mediaService.trackArtUrl
                                    ? root.mediaService.trackArtUrl
                                    : ""

                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: width
                            sourceSize.height: height

                            visible:
                                status === Image.Ready
                                && source.toString().length > 0
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: root.theme.spaceSm

                            visible: !artwork.visible

                            Components.JcIcon {
                                anchors.horizontalCenter:
                                    parent.horizontalCenter

                                theme: root.theme
                                name: "media"
                                iconColor: root.theme.textMuted
                                iconSize:
                                    root.theme.iconSizeLg * 2
                            }

                            Text {
                                anchors.horizontalCenter:
                                    parent.horizontalCenter

                                text: root.playerAvailable
                                    ? "Artwork unavailable"
                                    : "No active player"

                                color: root.theme.textMuted
                                font.family: root.theme.fontFamilySans
                                font.pixelSize:
                                    root.theme.textSizeCaption
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: root.theme.spaceSm

                    Text {
                        Layout.fillWidth: true

                        text:
                            root.playerAvailable
                                ? root.textOrFallback(
                                    root.mediaService.trackTitle,
                                    "Untitled media"
                                )
                                : "Waiting for media"

                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeSection
                        font.weight: root.theme.fontWeightBold

                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true

                        text:
                            root.playerAvailable
                                ? root.textOrFallback(
                                    root.mediaService.trackArtist,
                                    "Unknown artist"
                                )
                                : "Start playback in an MPRIS-aware app"

                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeBodyLarge
                        font.weight: root.theme.fontWeightMedium

                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true

                        text:
                            root.playerAvailable
                                ? root.textOrFallback(
                                    root.mediaService.trackAlbum,
                                    "Album unavailable"
                                )
                                : "Metadata will appear here automatically"

                        color: root.theme.textMuted
                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeBody

                        elide: Text.ElideRight
                    }

                    Components.JcSlider {
                        id: seekSlider

                        Layout.fillWidth: true

                        theme: root.theme
                        from: 0
                        to:
                            root.mediaService
                            && root.isNumeric(
                                root.mediaService.trackLengthSeconds
                            )
                            && Number(
                                root.mediaService.trackLengthSeconds
                            ) > 0
                                ? Number(
                                    root.mediaService.trackLengthSeconds
                                )
                                : 1
                        stepSize: 1

                        // Keep the local control value synchronized with the
                        // pointer while dragging. Backend mutation still occurs
                        // only from onPressedChanged after release.
                        live: true

                        controlEnabled:
                            root.capabilityAvailable(3)
                            && to > 1

                        Binding {
                            target: seekSlider
                            property: "value"
                            value:
                                root.mediaService
                                && root.isNumeric(
                                    root.mediaService.positionSeconds
                                )
                                    ? Math.max(
                                        seekSlider.from,
                                        Math.min(
                                            seekSlider.to,
                                            Number(
                                                root.mediaService
                                                    .positionSeconds
                                            )
                                        )
                                    )
                                    : 0
                            // Do not let 1-second observed snapshots or
                            // post-action reconciliation overwrite the local
                            // gesture/committed target.
                            when:
                                !seekSlider.pressed
                                && !root.actionBusy
                        }

                        onMoved: {
                            root.stagedSeekSeconds = value;
                            root.seekGestureDirty = true;
                        }

                        onPressedChanged: {
                            if (pressed) {
                                root.stagedSeekSeconds = value;
                                root.seekGestureDirty = false;
                                return;
                            }

                            if (root.seekGestureDirty && controlEnabled)
                                root.seekRequested(root.stagedSeekSeconds);

                            root.seekGestureDirty = false;
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.theme.spaceSm

                        Text {
                            text: root.playerAvailable
                                ? root.formatDuration(
                                    root.mediaService.positionSeconds
                                )
                                : "--:--"

                            color: root.theme.textSecondary
                            font.family: root.theme.fontFamilyMono
                            font.pixelSize:
                                root.theme.textSizeCaption
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.playerAvailable
                                ? root.formatDuration(
                                    root.mediaService.trackLengthSeconds
                                )
                                : "--:--"

                            color: root.theme.textSecondary
                            font.family: root.theme.fontFamilyMono
                            font.pixelSize:
                                root.theme.textSizeCaption
                        }
                    }

                    Text {
                        Layout.fillWidth: true

                        text:
                            root.playerAvailable
                                ? root.textOrFallback(
                                    root.mediaService.playbackStatus,
                                    "Observed"
                                )
                                    + " · interactive controls"
                                : "Read-only observed state"

                        color: root.theme.info
                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeCaption

                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.theme.spaceSm

                        Repeater {
                            model: 3

                            delegate: Components.JcButton {
                                required property int index

                                Layout.fillWidth: true

                                theme: root.theme
                                text: root.capabilityLabel(index)
                                iconName: root.capabilityIcon(index)
                                compact: true
                                controlEnabled:
                                    root.capabilityAvailable(index)

                                onClicked:
                                    root.requestTransportAction(index)
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight:
                root.theme.controlHeightLarge * 2.75
            spacing: root.theme.spaceMd

            Components.JcHudFrame {
                Layout.fillWidth: true
                Layout.fillHeight: true

                theme: root.theme
                surfaceRole: "glass"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.theme.spaceXs

                    Text {
                        Layout.fillWidth: true

                        text: "Output"
                        color: root.theme.textPrimary

                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeBodyLarge
                        font.weight: root.theme.fontWeightSemibold
                    }

                    Text {
                        Layout.fillWidth: true

                        text: root.audioDescription(true)
                        color: root.theme.textSecondary

                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeBody

                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: root.audioVolume(true)
                            color: root.theme.accent

                            font.family: root.theme.fontFamilyMono
                            font.pixelSize:
                                root.theme.textSizeSection
                            font.weight:
                                root.theme.fontWeightBold
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.audioState(true)
                            color:
                                root.mediaService
                                && root.mediaService.sinkMuted === true
                                    ? root.theme.warning
                                    : root.theme.success

                            font.family: root.theme.fontFamilySans
                            font.pixelSize:
                                root.theme.textSizeCaption
                            font.weight:
                                root.theme.fontWeightMedium
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.theme.spaceSm

                        Components.JcSlider {
                            id: sinkVolumeSlider

                            Layout.fillWidth: true

                            theme: root.theme
                            from: 0
                            to: 1
                            stepSize: 0.01

                            // `live` here is local Slider state only; it does
                            // not execute backend mutations continuously. The mutation
                            // remains commit-on-release below.
                            live: true
                            controlEnabled:
                                root.actionService
                                && root.actionService
                                    .canSetSinkVolume === true

                            Binding {
                                target: sinkVolumeSlider
                                property: "value"
                                value:
                                    root.mediaService
                                    && root.isNumeric(
                                        root.mediaService.sinkVolume
                                    )
                                        ? Math.max(
                                            0,
                                            Math.min(
                                                1,
                                                Number(
                                                    root.mediaService
                                                        .sinkVolume
                                                )
                                            )
                                        )
                                        : 0
                                // Preserve the user's released target
                                // while MediaActionService is applying and
                                // reconciling the observed sink snapshot.
                                when:
                                    !sinkVolumeSlider.pressed
                                    && !root.actionBusy
                            }

                            onMoved: {
                                root.stagedSinkVolume = value;
                                root.sinkVolumeGestureDirty = true;
                            }

                            onPressedChanged: {
                                if (pressed) {
                                    root.stagedSinkVolume = value;
                                    root.sinkVolumeGestureDirty = false;
                                    return;
                                }

                                if (root.sinkVolumeGestureDirty
                                        && controlEnabled) {
                                    root.sinkVolumeRequested(
                                        root.stagedSinkVolume
                                    );
                                }

                                root.sinkVolumeGestureDirty = false;
                            }
                        }

                        Components.JcButton {
                            theme: root.theme
                            text:
                                root.mediaService
                                && root.mediaService.sinkMuted === true
                                    ? "Unmute"
                                    : "Mute"
                            iconName:
                                root.mediaService
                                && root.mediaService.sinkMuted === true
                                    ? "volume"
                                    : "volume-mute"
                            compact: true
                            controlEnabled:
                                root.actionService
                                && root.actionService
                                    .canSetSinkMute === true

                            onClicked:
                                root.sinkMuteRequested(
                                    root.mediaService
                                    && root.mediaService.sinkMuted === true
                                        ? "off"
                                        : "on"
                                )
                        }
                    }
                }
            }

            Components.JcHudFrame {
                Layout.fillWidth: true
                Layout.fillHeight: true

                theme: root.theme
                surfaceRole: "glass"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.theme.spaceXs

                    Text {
                        Layout.fillWidth: true

                        text: "Input"
                        color: root.theme.textPrimary

                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeBodyLarge
                        font.weight: root.theme.fontWeightSemibold
                    }

                    Text {
                        Layout.fillWidth: true

                        text: root.audioDescription(false)
                        color: root.theme.textSecondary

                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeBody

                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: root.audioVolume(false)
                            color: root.theme.hudSecondaryAccent

                            font.family: root.theme.fontFamilyMono
                            font.pixelSize:
                                root.theme.textSizeSection
                            font.weight:
                                root.theme.fontWeightBold
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.audioState(false)
                            color:
                                root.mediaService
                                && root.mediaService.sourceMuted === true
                                    ? root.theme.warning
                                    : root.theme.success

                            font.family: root.theme.fontFamilySans
                            font.pixelSize:
                                root.theme.textSizeCaption
                            font.weight:
                                root.theme.fontWeightMedium
                        }
                    }
                }
            }
        }

        Components.JcHudFrame {
            Layout.fillWidth: true
            Layout.preferredHeight:
                root.theme.controlHeightLarge * 1.25

            theme: root.theme
            surfaceRole: "glass"
            glowEnabled: false
            showSecondaryAccent: false

            RowLayout {
                anchors.fill: parent
                spacing: root.theme.spaceMd

                Text {
                    Layout.fillWidth: true

                    text:
                        root.operationStatus.length > 0
                            ? root.operationStatus
                            : root.footerStatusText
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption

                    elide: Text.ElideRight
                }

                Text {
                    text:
                        root.actionBusy
                            ? "Applying"
                            : root.serviceReady
                                ? "Interactive"
                                : root.serviceLoading
                                    ? "Refreshing"
                                    : "Unavailable"

                    color:
                        root.actionBusy
                            ? root.theme.info
                            : root.serviceReady
                                ? root.theme.success
                                : root.serviceLoading
                                    ? root.theme.info
                                    : root.theme.textMuted

                    font.family: root.theme.fontFamilyMono
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightSemibold
                }
            }
        }
    }
}
