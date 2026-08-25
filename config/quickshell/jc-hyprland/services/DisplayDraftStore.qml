import QtQuick
import Quickshell

Scope {
    id: root

    property var monitorService
    property var modeParser

    property var drafts: []

    readonly property var commonScaleCandidates: [
        1.0,
        1.25,
        1.5,
        1.75,
        2.0
    ]

    readonly property bool hasDirty:
        drafts.some(function(draft) {
            return Boolean(draft.dirty);
        })

    readonly property int dirtyCount:
        drafts.filter(function(draft) {
            return Boolean(draft.dirty);
        }).length

    readonly property string topologyError:
        root.topologyValidationError()

    readonly property bool topologyValid:
        root.topologyError.length === 0

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

    function dirtyDrafts() {
        const result = [];

        for (let i = 0; i < root.drafts.length; ++i) {
            if (root.drafts[i].dirty)
                result.push(root.drafts[i]);
        }

        return result;
    }

    function prepareForRefreshAfterApply() {
        const next = [];

        for (let i = 0; i < root.drafts.length; ++i) {
            const current = root.copyDraft(root.drafts[i]);
            current.dirty = false;
            next.push(current);
        }

        root.drafts = next;
        root.observedChangedWhileDirty = false;
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

    function nearlyInteger(value) {
        return Math.abs(value - Math.round(value)) < 0.0001;
    }

    function scaleIsValidForDimensions(width, height, scale) {
        const numericScale = Number(scale);

        if (!Number.isFinite(numericScale) || numericScale <= 0)
            return false;

        return root.nearlyInteger(Number(width) / numericScale)
            && root.nearlyInteger(Number(height) / numericScale);
    }

    function logicalSize(width, height, scale, transform) {
        const numericScale = Number(scale);
        const numericTransform = Number(transform);

        if (!Number.isFinite(numericScale) || numericScale <= 0) {
            return {
                width: 0,
                height: 0
            };
        }

        let logicalWidth = Number(width) / numericScale;
        let logicalHeight = Number(height) / numericScale;

        if (numericTransform === 1
                || numericTransform === 3
                || numericTransform === 5
                || numericTransform === 7) {
            const swap = logicalWidth;
            logicalWidth = logicalHeight;
            logicalHeight = swap;
        }

        return {
            width: logicalWidth,
            height: logicalHeight
        };
    }

    function rectanglesOverlap(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw
            && ax + aw > bx
            && ay < by + bh
            && ay + ah > by;
    }

    function projectedMonitor(draft) {
        if (!draft)
            return null;

        const logical = root.logicalSize(
            draft.width,
            draft.height,
            draft.scale,
            draft.transform
        );

        const observedMonitor = root.monitorService
            ? root.monitorService.monitors.find(function(monitor) {
                return monitor.output === draft.output;
            })
            : null;

        return {
            output: draft.output,
            description: draft.description,
            x: Number(draft.x),
            y: Number(draft.y),
            width: Number(draft.width),
            height: Number(draft.height),
            logicalWidth: logical.width,
            logicalHeight: logical.height,
            refreshRate: Number(draft.refreshRate),
            scale: Number(draft.scale),
            transform: Number(draft.transform),
            dirty: Boolean(draft.dirty),
            focused: observedMonitor ? Boolean(observedMonitor.focused) : false,
            disabled: observedMonitor ? Boolean(observedMonitor.disabled) : false
        };
    }

    function projectedMonitors() {
        const result = [];

        for (let i = 0; i < root.drafts.length; ++i) {
            const projected = root.projectedMonitor(root.drafts[i]);

            if (projected)
                result.push(projected);
        }

        return result;
    }

    function projectedMonitorFor(output) {
        const draft = root.draftFor(output);

        return root.projectedMonitor(draft);
    }

    function outputHasOverlap(output) {
        const projected = root.projectedMonitorFor(output);

        if (!projected || projected.disabled)
            return false;

        const all = root.projectedMonitors();

        for (let i = 0; i < all.length; ++i) {
            const other = all[i];

            if (!other
                    || other.output === output
                    || other.disabled) {
                continue;
            }

            if (root.rectanglesOverlap(
                    projected.x,
                    projected.y,
                    projected.logicalWidth,
                    projected.logicalHeight,
                    other.x,
                    other.y,
                    other.logicalWidth,
                    other.logicalHeight)) {
                return true;
            }
        }

        return false;
    }

    function topologyValidationError() {
        const all = root.projectedMonitors();

        for (let i = 0; i < all.length; ++i) {
            const current = all[i];

            if (!current || current.disabled)
                continue;

            if (!Number.isInteger(current.x)
                    || !Number.isInteger(current.y)) {
                return current.output
                    + " has a non-integer layout position.";
            }

            if (current.logicalWidth <= 0 || current.logicalHeight <= 0) {
                return current.output
                    + " has invalid logical geometry.";
            }

            for (let j = i + 1; j < all.length; ++j) {
                const other = all[j];

                if (!other || other.disabled)
                    continue;

                if (root.rectanglesOverlap(
                        current.x,
                        current.y,
                        current.logicalWidth,
                        current.logicalHeight,
                        other.x,
                        other.y,
                        other.logicalWidth,
                        other.logicalHeight)) {
                    return current.output
                        + " overlaps "
                        + other.output
                        + ". Move one display before Safe Apply.";
                }
            }
        }

        return "";
    }

    function wouldOverlap(
        output,
        width,
        height,
        scale,
        transform,
        x,
        y
    ) {
        const projected = root.logicalSize(
            width,
            height,
            scale,
            transform
        );

        const all = root.projectedMonitors();

        for (let i = 0; i < all.length; ++i) {
            const other = all[i];

            if (!other
                    || other.output === output
                    || other.disabled) {
                continue;
            }

            if (root.rectanglesOverlap(
                    Number(x),
                    Number(y),
                    projected.width,
                    projected.height,
                    Number(other.x),
                    Number(other.y),
                    Number(other.logicalWidth),
                    Number(other.logicalHeight))) {
                return true;
            }
        }

        return false;
    }

    function closestScaleForDimensions(width, height, preferredScale) {
        const candidates = root.commonScaleCandidates;
        let best = 1.0;
        let bestDistance = Number.MAX_VALUE;

        for (let i = 0; i < candidates.length; ++i) {
            const candidate = Number(candidates[i]);

            if (!root.scaleIsValidForDimensions(width, height, candidate))
                continue;

            const distance =
                Math.abs(candidate - Number(preferredScale));

            if (distance < bestDistance) {
                best = candidate;
                bestDistance = distance;
            }
        }

        return best;
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

        if (!root.scaleIsValidForDimensions(
                updated.width,
                updated.height,
                updated.scale)) {
            updated.scale = root.closestScaleForDimensions(
                updated.width,
                updated.height,
                updated.scale
            );
        }

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

    function setScale(output, scaleValue) {
        const index = root.draftIndex(output);

        if (index < 0)
            return;

        const current = root.drafts[index];
        const numericScale = Number(scaleValue);

        if (!root.scaleIsValidForDimensions(
                current.width,
                current.height,
                numericScale)) {
            return;
        }

        const updated = root.copyDraft(current);
        updated.scale = numericScale;

        // Phase 1B.5 permits a temporarily invalid topology draft. The visual
        // editor can then reposition the monitor before Safe Apply.
        root.replaceDraft(index, updated);
    }

    function setTransform(output, transformValue) {
        const index = root.draftIndex(output);

        if (index < 0)
            return;

        const current = root.drafts[index];
        const numericTransform = Number(transformValue);

        if (!Number.isInteger(numericTransform)
                || numericTransform < 0
                || numericTransform > 7) {
            return;
        }

        const updated = root.copyDraft(current);
        updated.transform = numericTransform;

        // A rotation may require a layout change. Keep it as draft state and
        // block Safe Apply until topologyValidationError() is empty.
        root.replaceDraft(index, updated);
    }

    function setPosition(output, xValue, yValue) {
        const index = root.draftIndex(output);

        if (index < 0)
            return;

        const x = Math.round(Number(xValue));
        const y = Math.round(Number(yValue));

        if (!Number.isFinite(x) || !Number.isFinite(y))
            return;

        const updated = root.copyDraft(root.drafts[index]);

        updated.x = x;
        updated.y = y;

        root.replaceDraft(index, updated);
    }

    function snapPosition(output, xValue, yValue, threshold) {
        const target = root.projectedMonitorFor(output);

        if (!target) {
            return {
                x: Math.round(Number(xValue)),
                y: Math.round(Number(yValue))
            };
        }

        const proposedX = Number(xValue);
        const proposedY = Number(yValue);
        const snapThreshold = Math.max(1, Number(threshold || 32));

        let snappedX = proposedX;
        let snappedY = proposedY;
        let bestXDistance = snapThreshold + 1;
        let bestYDistance = snapThreshold + 1;

        const all = root.projectedMonitors();

        for (let i = 0; i < all.length; ++i) {
            const other = all[i];

            if (!other
                    || other.output === output
                    || other.disabled) {
                continue;
            }

            const xCandidates = [
                other.x - target.logicalWidth,
                other.x + other.logicalWidth,
                other.x,
                other.x + other.logicalWidth - target.logicalWidth,
                other.x
                    + (other.logicalWidth - target.logicalWidth) / 2
            ];

            const yCandidates = [
                other.y - target.logicalHeight,
                other.y + other.logicalHeight,
                other.y,
                other.y + other.logicalHeight - target.logicalHeight,
                other.y
                    + (other.logicalHeight - target.logicalHeight) / 2
            ];

            for (let xIndex = 0; xIndex < xCandidates.length; ++xIndex) {
                const distance =
                    Math.abs(proposedX - xCandidates[xIndex]);

                if (distance <= snapThreshold
                        && distance < bestXDistance) {
                    snappedX = xCandidates[xIndex];
                    bestXDistance = distance;
                }
            }

            for (let yIndex = 0; yIndex < yCandidates.length; ++yIndex) {
                const distance =
                    Math.abs(proposedY - yCandidates[yIndex]);

                if (distance <= snapThreshold
                        && distance < bestYDistance) {
                    snappedY = yCandidates[yIndex];
                    bestYDistance = distance;
                }
            }
        }

        return {
            x: Math.round(snappedX),
            y: Math.round(snappedY)
        };
    }

    function snapRelative(output, anchorOutput, relation) {
        const target = root.projectedMonitorFor(output);
        const anchor = root.projectedMonitorFor(anchorOutput);

        if (!target || !anchor || output === anchorOutput)
            return;

        let x = target.x;
        let y = target.y;

        switch (String(relation)) {
        case "left":
            x = anchor.x - target.logicalWidth;
            y = anchor.y
                + (anchor.logicalHeight - target.logicalHeight) / 2;
            break;

        case "right":
            x = anchor.x + anchor.logicalWidth;
            y = anchor.y
                + (anchor.logicalHeight - target.logicalHeight) / 2;
            break;

        case "above":
            x = anchor.x
                + (anchor.logicalWidth - target.logicalWidth) / 2;
            y = anchor.y - target.logicalHeight;
            break;

        case "below":
            x = anchor.x
                + (anchor.logicalWidth - target.logicalWidth) / 2;
            y = anchor.y + anchor.logicalHeight;
            break;

        default:
            return;
        }

        root.setPosition(output, x, y);
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

    function scaleOptionsFor(output) {
        const draft = root.draftFor(output);

        if (!draft)
            return [];

        const values = [];

        function addScale(candidate) {
            const numeric = Number(candidate);

            if (!root.scaleIsValidForDimensions(
                    draft.width,
                    draft.height,
                    numeric)) {
                return;
            }

            for (let i = 0; i < values.length; ++i) {
                if (Math.abs(values[i] - numeric) < 0.0001)
                    return;
            }

            values.push(numeric);
        }

        addScale(draft.observed.scale);

        for (let i = 0; i < root.commonScaleCandidates.length; ++i)
            addScale(root.commonScaleCandidates[i]);

        values.sort(function(left, right) {
            return left - right;
        });

        const options = [];

        for (let i = 0; i < values.length; ++i) {
            const scale = values[i];
            const requiresLayout = root.wouldOverlap(
                draft.output,
                draft.width,
                draft.height,
                scale,
                draft.transform,
                draft.x,
                draft.y
            );

            options.push({
                value: String(scale),
                label: String(scale) + "×"
                    + (requiresLayout ? " · move required" : ""),
                enabled: true
            });
        }

        return options;
    }

    function transformLabel(transformValue) {
        const transform = Number(transformValue);

        switch (transform) {
        case 0:
            return "Normal";
        case 1:
            return "90°";
        case 2:
            return "180°";
        case 3:
            return "270°";
        case 4:
            return "Flipped";
        case 5:
            return "Flipped + 90°";
        case 6:
            return "Flipped + 180°";
        case 7:
            return "Flipped + 270°";
        default:
            return "Unknown";
        }
    }

    function transformOptionsFor(output) {
        const draft = root.draftFor(output);

        if (!draft)
            return [];

        const options = [];

        for (let transform = 0; transform <= 7; ++transform) {
            const requiresLayout = root.wouldOverlap(
                draft.output,
                draft.width,
                draft.height,
                draft.scale,
                transform,
                draft.x,
                draft.y
            );

            options.push({
                value: String(transform),
                label: root.transformLabel(transform)
                    + (requiresLayout ? " · move required" : ""),
                enabled: true
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
