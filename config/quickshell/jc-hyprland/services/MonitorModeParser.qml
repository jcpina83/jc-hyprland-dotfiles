import QtQuick

QtObject {
    id: root

    function parse(rawMode) {
        const raw = String(rawMode || "").trim();

        const match =
            /^([0-9]+)x([0-9]+)@([0-9]+(?:\.[0-9]+)?)Hz$/.exec(raw);

        if (!match)
            return null;

        const width = Number(match[1]);
        const height = Number(match[2]);
        const refreshRate = Number(match[3]);

        if (!Number.isFinite(width)
                || !Number.isFinite(height)
                || !Number.isFinite(refreshRate)) {
            return null;
        }

        return {
            raw: raw,
            width: width,
            height: height,
            refreshRate: refreshRate,
            resolutionKey: width + "x" + height
        };
    }

    function parseAll(rawModes) {
        if (!Array.isArray(rawModes))
            return [];

        const parsed = [];
        const seen = {};

        for (let i = 0; i < rawModes.length; ++i) {
            const raw = String(rawModes[i] || "").trim();

            // Hyprland/EDID may expose exact duplicate strings.
            if (raw.length === 0 || seen[raw])
                continue;

            seen[raw] = true;

            const mode = root.parse(raw);

            if (mode)
                parsed.push(mode);
        }

        return parsed;
    }

    function uniqueResolutions(parsedModes) {
        const result = [];
        const seen = {};

        for (let i = 0; i < parsedModes.length; ++i) {
            const key = parsedModes[i].resolutionKey;

            if (seen[key])
                continue;

            seen[key] = true;
            result.push(key);
        }

        return result;
    }

    function modesForResolution(parsedModes, resolutionKey) {
        const result = [];

        for (let i = 0; i < parsedModes.length; ++i) {
            if (parsedModes[i].resolutionKey === resolutionKey)
                result.push(parsedModes[i]);
        }

        return result;
    }

    function closestMode(parsedModes, width, height, refreshRate) {
        const resolutionKey = Number(width) + "x" + Number(height);

        return root.closestModeForResolution(
            parsedModes,
            resolutionKey,
            refreshRate
        );
    }

    function closestModeForResolution(
        parsedModes,
        resolutionKey,
        preferredRefreshRate
    ) {
        const candidates =
            root.modesForResolution(parsedModes, resolutionKey);

        if (candidates.length === 0)
            return null;

        const preferred = Number(preferredRefreshRate);

        if (!Number.isFinite(preferred))
            return candidates[0];

        let closest = candidates[0];
        let closestDistance =
            Math.abs(candidates[0].refreshRate - preferred);

        for (let i = 1; i < candidates.length; ++i) {
            const distance =
                Math.abs(candidates[i].refreshRate - preferred);

            if (distance < closestDistance) {
                closest = candidates[i];
                closestDistance = distance;
            }
        }

        return closest;
    }

    function modeByRaw(parsedModes, rawMode) {
        const raw = String(rawMode || "");

        for (let i = 0; i < parsedModes.length; ++i) {
            if (parsedModes[i].raw === raw)
                return parsedModes[i];
        }

        return null;
    }

    function resolutionLabel(resolutionKey) {
        return String(resolutionKey || "").replace("x", " × ");
    }

    function refreshLabel(mode) {
        if (!mode)
            return "—";

        return Number(mode.refreshRate).toFixed(2) + " Hz";
    }
}
