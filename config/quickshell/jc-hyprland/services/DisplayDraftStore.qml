import QtQuick
import Quickshell

Scope {
    id: root

    property var monitorService
    property var modeParser

    property var drafts: []

    readonly property bool hasDirty:
        drafts.some(function(draft) {
            return Boolean(draft.dirty);
        })

    readonly property int dirtyCount:
        drafts.filter(function(draft) {
            return Boolean(draft.dirty);
        }).length

    property bool observedChangedWhileDirty: false

    signal draftChanged(string output)
    signal resetCompleted()

    function buildDraft(monitor) {
        const parsedModes = root.modeParser
            ? root.modeParser.parseAll(monitor.availableModes)
            : [];

        const observedMode = root.modeParser
            ? root.modeParser.closestMode(
                parsedModes,
                monitor.width,
                monitor.height,
                monitor.refreshRate
            )
            : null;

        const resolutionKey = observedMode
            ? observedMode.resolutionKey
            : monitor.width + "x" + monitor.height;

        const modeRaw = observedMode ? observedMode.raw : "";

        return {
            output: monitor.output,
            description: monitor.description,

            modes: parsedModes,

            observed: {
                modeRaw: modeRaw,
                resolutionKey: resolutionKey,
                width: monitor.width,
                height: monitor.height,
                refreshRate: monitor.refreshRate,
                scale: monitor.scale,
                transform: monitor.transform,
                x: monitor.x,
                y: monitor.y
            },

            modeRaw: modeRaw,
            resolutionKey: resolutionKey,
            width: observedMode ? observedMode.width : monitor.width,
            height: observedMode ? observedMode.height : monitor.height,
            refreshRate:
                observedMode
                    ? observedMode.refreshRate
                    : monitor.refreshRate,

            scale: monitor.scale,
            transform: monitor.transform,
            x: monitor.x,
            y: monitor.y,

            dirty: false
        };
    }

    function rebuildFromMonitors(monitors) {
        const next = [];

        if (Array.isArray(monitors)) {
            for (let i = 0; i < monitors.length; ++i)
                next.push(root.buildDraft(monitors[i]));
        }

        root.drafts = next;
        root.observedChangedWhileDirty = false;
        root.resetCompleted();
    }

    function syncFromMonitors(monitors) {
        // Never silently replace an edit that the user has not reset/applied.
        if (root.hasDirty) {
            root.observedChangedWhileDirty = true;
            return;
        }

        root.rebuildFromMonitors(monitors);
    }

    function reset() {
        const monitors = root.monitorService
            ? root.monitorService.monitors
            : [];

        root.rebuildFromMonitors(monitors);
    }

    function draftIndex(output) {
        for (let i = 0; i < root.drafts.length; ++i) {
            if (root.drafts[i].output === output)
                return i;
        }

        return -1;
    }

    function draftFor(output) {
        const index = root.draftIndex(output);

        return index >= 0 ? root.drafts[index] : null;
    }

    function isDirty(draft) {
        if (!draft)
            return false;

        return draft.modeRaw !== draft.observed.modeRaw
            || Number(draft.scale) !== Number(draft.observed.scale)
            || Number(draft.transform) !== Number(draft.observed.transform)
            || Number(draft.x) !== Number(draft.observed.x)
            || Number(draft.y) !== Number(draft.observed.y);
    }

    function copyDraft(current) {
        return {
            output: current.output,
            description: current.description,

            modes: current.modes,
            observed: current.observed,

            modeRaw: current.modeRaw,
            resolutionKey: current.resolutionKey,
            width: current.width,
            height: current.height,
            refreshRate: current.refreshRate,

            scale: current.scale,
            transform: current.transform,
            x: current.x,
            y: current.y,

            dirty: current.dirty
        };
    }

    function replaceDraft(index, draft) {
        const next = root.drafts.slice();

        draft.dirty = root.isDirty(draft);
        next[index] = draft;

        root.drafts = next;
        root.draftChanged(draft.output);
    }

    function setResolution(output, resolutionKey) {
        const index = root.draftIndex(output);

        if (index < 0 || !root.modeParser)
            return;

        const current = root.drafts[index];

        const mode = root.modeParser.closestModeForResolution(
            current.modes,
            resolutionKey,
            current.refreshRate
        );

        if (!mode)
            return;

        const updated = root.copyDraft(current);

        updated.modeRaw = mode.raw;
        updated.resolutionKey = mode.resolutionKey;
        updated.width = mode.width;
        updated.height = mode.height;
        updated.refreshRate = mode.refreshRate;

        root.replaceDraft(index, updated);
    }

    function setRefreshMode(output, rawMode) {
        const index = root.draftIndex(output);

        if (index < 0 || !root.modeParser)
            return;

        const current = root.drafts[index];
        const mode = root.modeParser.modeByRaw(current.modes, rawMode);

        if (!mode || mode.resolutionKey !== current.resolutionKey)
            return;

        const updated = root.copyDraft(current);

        updated.modeRaw = mode.raw;
        updated.width = mode.width;
        updated.height = mode.height;
        updated.refreshRate = mode.refreshRate;

        root.replaceDraft(index, updated);
    }

    function resolutionOptionsFor(output) {
        const draft = root.draftFor(output);

        if (!draft || !root.modeParser)
            return [];

        const resolutions =
            root.modeParser.uniqueResolutions(draft.modes);

        const options = [];

        for (let i = 0; i < resolutions.length; ++i) {
            options.push({
                value: resolutions[i],
                label: root.modeParser.resolutionLabel(resolutions[i])
            });
        }

        return options;
    }

    function refreshOptionsFor(output) {
        const draft = root.draftFor(output);

        if (!draft || !root.modeParser)
            return [];

        const modes = root.modeParser.modesForResolution(
            draft.modes,
            draft.resolutionKey
        );

        const options = [];

        for (let i = 0; i < modes.length; ++i) {
            options.push({
                value: modes[i].raw,
                label: root.modeParser.refreshLabel(modes[i])
            });
        }

        return options;
    }

    Connections {
        target: root.monitorService

        function onRefreshed() {
            root.syncFromMonitors(root.monitorService.monitors);
        }
    }

    Component.onCompleted: {
        if (root.monitorService)
            root.syncFromMonitors(root.monitorService.monitors);
    }
}
