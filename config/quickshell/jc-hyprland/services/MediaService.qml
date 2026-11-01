import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property int snapshotSchemaVersion: 0
    property string status: "unknown"
    property bool readOnly: true

    property bool loading: false
    property bool ready: false
    property string errorMessage: ""
    property string lastRefresh: ""

    property bool liveUpdatesEnabled: false
    property int refreshIntervalMs: 1000

    property var dependencies: ({})

    property bool playerAvailable: false
    property var players: []
    property string selectedPlayer: ""
    property string playbackStatus: ""
    property string playerIdentity: ""

    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string trackArtUrl: ""
    property string trackUrl: ""
    property string trackId: ""
    property var trackLengthSeconds: null
    property var positionSeconds: null

    property var canControl: null
    property var canPlay: null
    property var canPause: null
    property var canGoNext: null
    property var canGoPrevious: null
    property var canSeek: null

    property bool audioAvailable: false

    property bool sinkAvailable: false
    property string sinkSelector: ""
    property string sinkName: ""
    property string sinkDescription: ""
    property string sinkState: ""
    property var sinkMuted: null
    property var sinkVolume: null

    property bool sourceAvailable: false
    property string sourceSelector: ""
    property string sourceName: ""
    property string sourceDescription: ""
    property string sourceState: ""
    property var sourceMuted: null
    property var sourceVolume: null

    readonly property bool observedHealthy:
        root.ready
        && root.readOnly
        && (
            root.status === "ok"
            || root.status === "partial"
        )

    signal refreshed()
    signal refreshFailed(string message)

    function mediaCommandPath() {
        return Quickshell.env("HOME")
            + "/.config/jc-hyprland-dotfiles/bin/jc-media";
    }

    function isObject(value) {
        return value !== null
            && typeof value === "object"
            && !Array.isArray(value);
    }

    function optionalBoolean(value) {
        return typeof value === "boolean"
            ? value
            : null;
    }

    function optionalNumber(value) {
        return typeof value === "number"
            && isFinite(value)
            ? value
            : null;
    }

    function optionalString(value) {
        return typeof value === "string"
            ? value
            : "";
    }

    function validStatus(payload) {
        if (!root.isObject(payload))
            return false;

        if (payload.schemaVersion !== 1)
            return false;

        if (payload.readOnly !== true)
            return false;

        if (
            payload.status !== "ok"
            && payload.status !== "partial"
        )
            return false;

        if (!root.isObject(payload.dependencies))
            return false;

        if (!root.isObject(payload.player))
            return false;

        if (typeof payload.player.available !== "boolean")
            return false;

        if (!Array.isArray(payload.player.players))
            return false;

        if (!root.isObject(payload.player.metadata))
            return false;

        if (!root.isObject(payload.player.capabilities))
            return false;

        if (!root.isObject(payload.audio))
            return false;

        if (typeof payload.audio.available !== "boolean")
            return false;

        if (!root.isObject(payload.audio.sink))
            return false;

        if (!root.isObject(payload.audio.source))
            return false;

        if (typeof payload.audio.sink.available !== "boolean")
            return false;

        if (typeof payload.audio.source.available !== "boolean")
            return false;

        return true;
    }

    function commitSnapshot(payload) {
        const player = payload.player;
        const metadata = player.metadata;
        const capabilities = player.capabilities;
        const audio = payload.audio;
        const sink = audio.sink;
        const source = audio.source;

        root.snapshotSchemaVersion = payload.schemaVersion;
        root.status = payload.status;
        root.readOnly = payload.readOnly === true;
        root.dependencies = payload.dependencies;

        root.playerAvailable = player.available === true;
        root.players = player.players.slice(0);
        root.selectedPlayer = root.optionalString(player.selected);
        root.playbackStatus = root.optionalString(player.playbackStatus);
        root.playerIdentity = root.optionalString(player.identity);

        root.trackTitle = root.optionalString(metadata.title);
        root.trackArtist = root.optionalString(metadata.artist);
        root.trackAlbum = root.optionalString(metadata.album);
        root.trackArtUrl = root.optionalString(metadata.artUrl);
        root.trackUrl = root.optionalString(metadata.url);
        root.trackId = root.optionalString(metadata.trackId);
        root.trackLengthSeconds = root.optionalNumber(
            metadata.lengthSeconds
        );
        root.positionSeconds = root.optionalNumber(
            player.positionSeconds
        );

        root.canControl = root.optionalBoolean(
            capabilities.canControl
        );
        root.canPlay = root.optionalBoolean(
            capabilities.canPlay
        );
        root.canPause = root.optionalBoolean(
            capabilities.canPause
        );
        root.canGoNext = root.optionalBoolean(
            capabilities.canGoNext
        );
        root.canGoPrevious = root.optionalBoolean(
            capabilities.canGoPrevious
        );
        root.canSeek = root.optionalBoolean(
            capabilities.canSeek
        );

        root.audioAvailable = audio.available === true;

        root.sinkAvailable = sink.available === true;
        root.sinkSelector = root.optionalString(sink.selector);
        root.sinkName = root.optionalString(sink.name);
        root.sinkDescription = root.optionalString(
            sink.description
        );
        root.sinkState = root.optionalString(sink.state);
        root.sinkMuted = root.optionalBoolean(sink.muted);
        root.sinkVolume = root.optionalNumber(sink.volume);

        root.sourceAvailable = source.available === true;
        root.sourceSelector = root.optionalString(source.selector);
        root.sourceName = root.optionalString(source.name);
        root.sourceDescription = root.optionalString(
            source.description
        );
        root.sourceState = root.optionalString(source.state);
        root.sourceMuted = root.optionalBoolean(source.muted);
        root.sourceVolume = root.optionalNumber(source.volume);

        root.ready = true;
        root.errorMessage = "";
        root.lastRefresh = new Date().toISOString();
        root.refreshed();
    }

    function refresh(): void {
        if (statusProcess.running)
            return;

        root.loading = true;
        root.errorMessage = "";
        statusProcess.running = true;
    }

    Process {
        id: statusProcess

        command: [
            root.mediaCommandPath(),
            "status",
            "--json"
        ]

        stdout: StdioCollector {
            id: statusOutput
        }

        stderr: StdioCollector {
            id: statusError
        }

        onExited: exitCode => {
            root.loading = false;

            if (exitCode !== 0) {
                const backendError = String(statusError.text || "").trim();
                root.errorMessage = backendError.length > 0
                    ? backendError
                    : "jc-media status failed";
                root.refreshFailed(root.errorMessage);
                return;
            }

            try {
                const payload = JSON.parse(
                    String(statusOutput.text || "{}")
                );

                if (!root.validStatus(payload)) {
                    root.errorMessage =
                        "Invalid jc-media status payload";
                    root.refreshFailed(root.errorMessage);
                    return;
                }

                root.commitSnapshot(payload);
            } catch (error) {
                root.errorMessage =
                    "Unable to parse jc-media status: "
                    + String(error);
                root.refreshFailed(root.errorMessage);
            }
        }
    }

    onLiveUpdatesEnabledChanged: {
        if (root.liveUpdatesEnabled)
            root.refresh();
    }

    Timer {
        interval: root.refreshIntervalMs
        repeat: true
        running: root.liveUpdatesEnabled

        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
