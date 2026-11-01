#!/usr/bin/env bash
set -euo pipefail

schema_version=1

usage() {
    cat <<'USAGE'
Usage:
  jc-media status [--json]
  jc-media player play-pause [--json]
  jc-media player next [--json]
  jc-media player previous [--json]
  jc-media player seek <seconds> [--json]
  jc-media audio sink-volume <0..1> [--json]
  jc-media audio sink-mute <on|off|toggle> [--json]
  jc-media --help

Stable Media contract:
  status               Observe MPRIS player state and default PipeWire audio.
  player play-pause    Toggle selected player using observed capabilities.
  player next          Advance only when CanGoNext is true.
  player previous      Go back only when CanGoPrevious is true.
  player seek          Set absolute position in seconds when CanSeek is true.
  audio sink-volume    Set default sink volume in the inclusive 0..1 range.
  audio sink-mute      Set/toggle mute on the default sink.

Selection:
  1. Enumerate playerctl players dynamically.
  2. Exclude playerctld as a concrete player.
  3. Prefer Playing, then Paused, then the first remaining real player.
  4. Resolve the selected player again for every action.
  5. Never persist MPRIS instance suffixes.

Audio:
  Mutations target @DEFAULT_AUDIO_SINK@ only. Observation may also use
  @DEFAULT_AUDIO_SOURCE@. Numeric PipeWire node IDs, ALSA card numbers and
  hardware identifiers are never persisted by this API.

The status snapshot remains observational and reports readOnly=true.
Mutation subcommands are explicit, capability-aware and return structured
results when --json is requested.

Exit codes:
  0  request applied successfully
  2  invalid usage
  3  required dependency unavailable
  4  dynamic target unavailable
  5  requested capability unavailable
  6  backend action failed
USAGE
}

die_usage() {
    printf 'ERROR: %s\n\n' "$*" >&2
    usage >&2
    exit 2
}

command_available() {
    command -v "$1" >/dev/null 2>&1
}

require_jq() {
    command_available jq || {
        printf 'ERROR: jq is required by jc-media\n' >&2
        exit 3
    }
}

json_number() {
    local value="${1:-}"

    if [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        printf '%s' "$value"
    else
        printf 'null'
    fi
}

json_bool() {
    case "${1:-}" in
        true|false)
            printf '%s' "$1"
            ;;
        *)
            printf 'null'
            ;;
    esac
}

list_real_players() {
    command_available playerctl || return 0

    playerctl -l 2>/dev/null |
        grep -v '^playerctld$' \
        || true
}

players_json() {
    if ! command_available playerctl; then
        printf '[]'
        return 0
    fi

    list_real_players |
        jq -Rsc '
            split("\n")
            | map(select(length > 0))
        '
}

select_player() {
    command_available playerctl || return 1

    local -a real_players=()
    local player=""
    local wanted=""
    local observed=""

    mapfile -t real_players < <(list_real_players)

    [[ ${#real_players[@]} -gt 0 ]] || return 1

    for wanted in Playing Paused; do
        for player in "${real_players[@]}"; do
            observed="$(
                playerctl --player="$player" status 2>/dev/null \
                    || true
            )"

            if [[ "$observed" == "$wanted" ]]; then
                printf '%s\n' "$player"
                return 0
            fi
        done
    done

    printf '%s\n' "${real_players[0]}"
}

player_metadata_value() {
    local player="$1"
    local format="$2"

    playerctl \
        --player="$player" \
        metadata \
        --format "$format" \
        2>/dev/null \
        || true
}

mpris_service_for_player() {
    local player="$1"
    local service="org.mpris.MediaPlayer2.$player"

    command_available busctl || return 1

    if busctl --user --no-pager --no-legend list 2>/dev/null |
        awk -v wanted="$service" '
            $1 == wanted {
                found = 1
            }

            END {
                exit(found ? 0 : 1)
            }
        '
    then
        printf '%s\n' "$service"
        return 0
    fi

    return 1
}

mpris_bool_property() {
    local service="$1"
    local property="$2"
    local raw=""

    raw="$(
        busctl --user get-property \
            "$service" \
            /org/mpris/MediaPlayer2 \
            org.mpris.MediaPlayer2.Player \
            "$property" \
            2>/dev/null \
            || true
    )"

    case "$raw" in
        "b true")
            printf 'true'
            ;;
        "b false")
            printf 'false'
            ;;
        *)
            return 1
            ;;
    esac
}

player_status_json() {
    require_jq

    local players_json_payload=""
    local selected=""
    local service=""
    local playback_status=""
    local identity=""
    local title=""
    local artist=""
    local album=""
    local art_url=""
    local media_url=""
    local track_id=""
    local position=""
    local length_us=""
    local length_seconds=""

    local can_control=""
    local can_play=""
    local can_pause=""
    local can_next=""
    local can_previous=""
    local can_seek=""

    players_json_payload="$(players_json)"

    if ! selected="$(select_player 2>/dev/null)"; then
        jq -n \
            --argjson players "$players_json_payload" \
            '{
                available: false,
                selectionStrategy: "playing-paused-first",
                players: $players,
                selected: null,
                playbackStatus: null,
                identity: null,
                metadata: {
                    title: null,
                    artist: null,
                    album: null,
                    artUrl: null,
                    url: null,
                    trackId: null,
                    lengthSeconds: null
                },
                positionSeconds: null,
                capabilities: {
                    canControl: null,
                    canPlay: null,
                    canPause: null,
                    canGoNext: null,
                    canGoPrevious: null,
                    canSeek: null
                },
                backend: "MPRIS/playerctl"
            }'
        return 0
    fi

    playback_status="$(
        playerctl --player="$selected" status 2>/dev/null \
            || true
    )"

    identity="$(
        player_metadata_value "$selected" '{{playerName}}'
    )"
    title="$(
        player_metadata_value "$selected" '{{title}}'
    )"
    artist="$(
        player_metadata_value "$selected" '{{artist}}'
    )"
    album="$(
        player_metadata_value "$selected" '{{album}}'
    )"
    art_url="$(
        player_metadata_value "$selected" '{{mpris:artUrl}}'
    )"
    media_url="$(
        player_metadata_value "$selected" '{{xesam:url}}'
    )"
    track_id="$(
        player_metadata_value "$selected" '{{mpris:trackid}}'
    )"
    length_us="$(
        player_metadata_value "$selected" '{{mpris:length}}'
    )"
    position="$(
        playerctl --player="$selected" position 2>/dev/null \
            || true
    )"

    if [[ "$length_us" =~ ^[0-9]+$ ]]; then
        length_seconds="$(
            awk -v value="$length_us" \
                'BEGIN { printf "%.3f", value / 1000000.0 }'
        )"
    fi

    if service="$(mpris_service_for_player "$selected" 2>/dev/null)"; then
        can_control="$(
            mpris_bool_property "$service" CanControl 2>/dev/null \
                || true
        )"
        can_play="$(
            mpris_bool_property "$service" CanPlay 2>/dev/null \
                || true
        )"
        can_pause="$(
            mpris_bool_property "$service" CanPause 2>/dev/null \
                || true
        )"
        can_next="$(
            mpris_bool_property "$service" CanGoNext 2>/dev/null \
                || true
        )"
        can_previous="$(
            mpris_bool_property "$service" CanGoPrevious 2>/dev/null \
                || true
        )"
        can_seek="$(
            mpris_bool_property "$service" CanSeek 2>/dev/null \
                || true
        )"
    fi

    jq -n \
        --argjson players "$players_json_payload" \
        --arg selected "$selected" \
        --arg service "$service" \
        --arg playbackStatus "$playback_status" \
        --arg identity "$identity" \
        --arg title "$title" \
        --arg artist "$artist" \
        --arg album "$album" \
        --arg artUrl "$art_url" \
        --arg url "$media_url" \
        --arg trackId "$track_id" \
        --argjson lengthSeconds "$(json_number "$length_seconds")" \
        --argjson positionSeconds "$(json_number "$position")" \
        --argjson canControl "$(json_bool "$can_control")" \
        --argjson canPlay "$(json_bool "$can_play")" \
        --argjson canPause "$(json_bool "$can_pause")" \
        --argjson canGoNext "$(json_bool "$can_next")" \
        --argjson canGoPrevious "$(json_bool "$can_previous")" \
        --argjson canSeek "$(json_bool "$can_seek")" \
        '{
            available: true,
            selectionStrategy: "playing-paused-first",
            players: $players,
            selected: $selected,
            mprisService: (
                if $service == ""
                then null
                else $service
                end
            ),
            playbackStatus: (
                if $playbackStatus == ""
                then null
                else $playbackStatus
                end
            ),
            identity: (
                if $identity == ""
                then null
                else $identity
                end
            ),
            metadata: {
                title: (
                    if $title == ""
                    then null
                    else $title
                    end
                ),
                artist: (
                    if $artist == ""
                    then null
                    else $artist
                    end
                ),
                album: (
                    if $album == ""
                    then null
                    else $album
                    end
                ),
                artUrl: (
                    if $artUrl == ""
                    then null
                    else $artUrl
                    end
                ),
                url: (
                    if $url == ""
                    then null
                    else $url
                    end
                ),
                trackId: (
                    if $trackId == ""
                    then null
                    else $trackId
                    end
                ),
                lengthSeconds: $lengthSeconds
            },
            positionSeconds: $positionSeconds,
            capabilities: {
                canControl: $canControl,
                canPlay: $canPlay,
                canPause: $canPause,
                canGoNext: $canGoNext,
                canGoPrevious: $canGoPrevious,
                canSeek: $canSeek
            },
            backend: "MPRIS/playerctl"
        }'
}

audio_endpoint_json() {
    require_jq

    local kind="$1"
    local selector=""
    local default_name=""
    local list_kind=""
    local raw=""
    local volume=""
    local muted=false
    local description=""
    local state=""

    case "$kind" in
        sink)
            selector="@DEFAULT_AUDIO_SINK@"
            list_kind="sinks"

            if command_available pactl; then
                default_name="$(
                    pactl get-default-sink 2>/dev/null \
                        || true
                )"
            fi
            ;;
        source)
            selector="@DEFAULT_AUDIO_SOURCE@"
            list_kind="sources"

            if command_available pactl; then
                default_name="$(
                    pactl get-default-source 2>/dev/null \
                        || true
                )"
            fi
            ;;
        *)
            return 1
            ;;
    esac

    if ! command_available wpctl; then
        jq -n \
            --arg selector "$selector" \
            '{
                available: false,
                selector: $selector,
                name: null,
                description: null,
                state: null,
                muted: null,
                volume: null
            }'
        return 0
    fi

    raw="$(
        wpctl get-volume "$selector" 2>/dev/null \
            || true
    )"

    if [[ -z "$raw" ]]; then
        jq -n \
            --arg selector "$selector" \
            '{
                available: false,
                selector: $selector,
                name: null,
                description: null,
                state: null,
                muted: null,
                volume: null
            }'
        return 0
    fi

    volume="$(
        awk '{ print $2 }' <<< "$raw"
    )"

    if [[ "$raw" == *"[MUTED]"* ]]; then
        muted=true
    fi

    if command_available pactl && [[ -n "$default_name" ]]; then
        description="$(
            pactl -f json list "$list_kind" 2>/dev/null |
                jq -r \
                    --arg name "$default_name" \
                    '
                    map(select(.name == $name))
                    | first
                    | .description // ""
                    ' \
                    2>/dev/null \
                    || true
        )"

        state="$(
            pactl -f json list "$list_kind" 2>/dev/null |
                jq -r \
                    --arg name "$default_name" \
                    '
                    map(select(.name == $name))
                    | first
                    | .state // ""
                    ' \
                    2>/dev/null \
                    || true
        )"
    fi

    jq -n \
        --arg selector "$selector" \
        --arg name "$default_name" \
        --arg description "$description" \
        --arg state "$state" \
        --argjson muted "$muted" \
        --argjson volume "$(json_number "$volume")" \
        '{
            available: true,
            selector: $selector,
            name: (
                if $name == ""
                then null
                else $name
                end
            ),
            description: (
                if $description == ""
                then null
                else $description
                end
            ),
            state: (
                if $state == ""
                then null
                else $state
                end
            ),
            muted: $muted,
            volume: $volume
        }'
}

audio_status_json() {
    local sink=""
    local source=""

    sink="$(audio_endpoint_json sink)"
    source="$(audio_endpoint_json source)"

    jq -n \
        --argjson sink "$sink" \
        --argjson source "$source" \
        '{
            available: (
                $sink.available
                or $source.available
            ),
            sink: $sink,
            source: $source,
            backend: "PipeWire/WirePlumber"
        }'
}

status_json() {
    require_jq

    local playerctl_available=false
    local wpctl_available=false
    local pactl_available=false
    local busctl_available=false
    local overall_status="partial"
    local player=""
    local audio=""

    command_available playerctl && playerctl_available=true
    command_available wpctl && wpctl_available=true
    command_available pactl && pactl_available=true
    command_available busctl && busctl_available=true

    if [[ "$playerctl_available" == true \
        && "$wpctl_available" == true \
        && "$pactl_available" == true \
        && "$busctl_available" == true ]]
    then
        overall_status="ok"
    fi

    player="$(player_status_json)"
    audio="$(audio_status_json)"

    jq -n \
        --argjson schemaVersion "$schema_version" \
        --arg status "$overall_status" \
        --argjson playerctlAvailable "$playerctl_available" \
        --argjson wpctlAvailable "$wpctl_available" \
        --argjson pactlAvailable "$pactl_available" \
        --argjson busctlAvailable "$busctl_available" \
        --argjson player "$player" \
        --argjson audio "$audio" \
        '{
            schemaVersion: $schemaVersion,
            status: $status,
            readOnly: true,
            dependencies: {
                playerctl: $playerctlAvailable,
                wpctl: $wpctlAvailable,
                pactl: $pactlAvailable,
                busctl: $busctlAvailable
            },
            player: $player,
            audio: $audio
        }'
}

status_human() {
    local payload=""

    payload="$(status_json)"

    printf 'Media\n'
    printf '  Status: %s\n' \
        "$(jq -r '.status' <<< "$payload")"

    printf '  Player: %s\n' \
        "$(jq -r '
            if .player.available
            then (
                (.player.identity // .player.selected // "unknown")
                + " · "
                + (.player.playbackStatus // "unknown")
            )
            else "none"
            end
        ' <<< "$payload")"

    printf '  Track:  %s\n' \
        "$(jq -r '
            if .player.available
            then (
                .player.metadata.title
                // "metadata unavailable"
            )
            else "n/a"
            end
        ' <<< "$payload")"

    printf '  Sink:   %s\n' \
        "$(jq -r '
            if .audio.sink.available
            then (
                (.audio.sink.description // .audio.sink.name // "unknown")
                + " · "
                + (
                    (.audio.sink.volume * 100)
                    | round
                    | tostring
                )
                + "%"
                + (
                    if .audio.sink.muted
                    then " · muted"
                    else ""
                    end
                )
            )
            else "unavailable"
            end
        ' <<< "$payload")"
}


action_result_json() {
    require_jq

    local status="$1"
    local action="$2"
    local applied="$3"
    local target_kind="$4"
    local target_selector="$5"
    local capability="$6"
    local message="$7"

    jq -n \
        --argjson schemaVersion "$schema_version" \
        --arg status "$status" \
        --arg action "$action" \
        --argjson applied "$applied" \
        --arg targetKind "$target_kind" \
        --arg targetSelector "$target_selector" \
        --arg capability "$capability" \
        --arg message "$message" \
        '{
            schemaVersion: $schemaVersion,
            status: $status,
            action: $action,
            applied: $applied,
            target: {
                kind: $targetKind,
                selector: (
                    if $targetSelector == ""
                    then null
                    else $targetSelector
                    end
                )
            },
            capability: (
                if $capability == ""
                then null
                else $capability
                end
            ),
            message: $message
        }'
}

emit_action_result() {
    local json_output="$1"
    local status="$2"
    local action="$3"
    local applied="$4"
    local target_kind="$5"
    local target_selector="$6"
    local capability="$7"
    local message="$8"
    local payload=""

    payload="$(
        action_result_json \
            "$status" \
            "$action" \
            "$applied" \
            "$target_kind" \
            "$target_selector" \
            "$capability" \
            "$message"
    )"

    if [[ "$json_output" == true ]]; then
        printf '%s\n' "$payload"
        return 0
    fi

    jq -r '
        (.action + ": " + .status + " · " + .message)
    ' <<< "$payload"
}

fail_action() {
    local rc="$1"
    shift
    emit_action_result "$@"
    return "$rc"
}

parse_json_suffix() {
    local -n args_ref="$1"

    if [[ ${#args_ref[@]} -gt 0 \
        && "${args_ref[-1]}" == "--json" ]]
    then
        unset 'args_ref[-1]'
        args_ref=("${args_ref[@]}")
        return 0
    fi

    return 1
}

selected_player_capability() {
    local selected="$1"
    local capability="$2"
    local service=""

    if ! service="$(mpris_service_for_player "$selected" 2>/dev/null)"; then
        return 1
    fi

    mpris_bool_property "$service" "$capability"
}

player_track_key() {
    local selected="$1"
    local track_id=""
    local url=""
    local title=""
    local artist=""

    track_id="$(
        playerctl --player="$selected" metadata mpris:trackid \
            2>/dev/null || true
    )"
    url="$(
        playerctl --player="$selected" metadata xesam:url \
            2>/dev/null || true
    )"
    title="$(
        playerctl --player="$selected" metadata xesam:title \
            2>/dev/null || true
    )"
    artist="$(
        playerctl --player="$selected" metadata xesam:artist \
            2>/dev/null || true
    )"

    printf '%s|%s|%s|%s\n' \
        "$track_id" "$url" "$title" "$artist"
}

smart_previous_track() {
    local selected="$1"
    local before_key=""
    local after_key=""
    local observed_position=""

    before_key="$(player_track_key "$selected")"

    if ! playerctl --player="$selected" previous; then
        return 1
    fi

    for _ in {1..12}; do
        sleep 0.05

        after_key="$(player_track_key "$selected")"

        if [[ -n "$before_key" && -n "$after_key" \
                && "$after_key" != "$before_key" ]]
        then
            return 0
        fi

        observed_position="$(
            playerctl --player="$selected" position 2>/dev/null || true
        )"

        if [[ -n "$observed_position" ]] && awk \
            -v value="$observed_position" \
            'BEGIN { exit !(value >= 0 && value <= 1.50) }'
        then
            if ! playerctl --player="$selected" previous; then
                return 1
            fi

            return 0
        fi
    done

    return 0
}

player_action() {
    local operation="$1"
    local argument="$2"
    local json_output="$3"
    local selected=""
    local playback_status=""
    local capability=""
    local capability_value=""
    local action_name="player.$operation"

    if ! command_available playerctl; then
        fail_action \
            3 "$json_output" "dependency-unavailable" "$action_name" false \
            "player" "" "" "playerctl is unavailable"
        return $?
    fi

    if ! selected="$(select_player 2>/dev/null)"; then
        fail_action \
            4 "$json_output" "target-unavailable" "$action_name" false \
            "player" "" "" "No active MPRIS player is available"
        return $?
    fi

    case "$operation" in
        play-pause)
            playback_status="$(
                playerctl --player="$selected" status 2>/dev/null || true
            )"

            case "$playback_status" in
                Playing)
                    capability="CanPause"
                    ;;
                Paused|Stopped)
                    capability="CanPlay"
                    ;;
                *)
                    fail_action \
                        5 "$json_output" "capability-unavailable" \
                        "$action_name" false "player" "$selected" \
                        "" "Playback state does not support play/pause safely"
                    return $?
                    ;;
            esac
            ;;
        next)
            capability="CanGoNext"
            ;;
        previous)
            capability="CanGoPrevious"
            ;;
        seek)
            capability="CanSeek"

            if ! awk -v value="$argument" '
                BEGIN {
                    if (value !~ /^[0-9]+([.][0-9]+)?$/) exit 1
                    exit(value >= 0 ? 0 : 1)
                }
            '
            then
                die_usage "seek seconds must be a non-negative number"
            fi
            ;;
        *)
            die_usage "unsupported player action: $operation"
            ;;
    esac

    capability_value="$(
        selected_player_capability \
            "$selected" "$capability" 2>/dev/null || true
    )"

    if [[ "$capability_value" != true ]]; then
        fail_action \
            5 "$json_output" "capability-unavailable" "$action_name" false \
            "player" "$selected" "$capability" \
            "$capability is not available for the selected player"
        return $?
    fi

    case "$operation" in
        play-pause)
            if ! playerctl --player="$selected" play-pause; then
                fail_action \
                    6 "$json_output" "backend-failed" "$action_name" false \
                    "player" "$selected" "$capability" \
                    "playerctl play-pause failed"
                return $?
            fi
            ;;
        next)
            if ! playerctl --player="$selected" next; then
                fail_action \
                    6 "$json_output" "backend-failed" "$action_name" false \
                    "player" "$selected" "$capability" \
                    "playerctl next failed"
                return $?
            fi
            ;;
        previous)
            if ! smart_previous_track "$selected"; then
                fail_action \
                    6 "$json_output" "backend-failed" "$action_name" false \
                    "player" "$selected" "$capability" \
                    "semantic previous-track action failed"
                return $?
            fi
            ;;

        seek)
            if ! playerctl --player="$selected" position "$argument"; then
                fail_action \
                    6 "$json_output" "backend-failed" "$action_name" false \
                    "player" "$selected" "$capability" \
                    "playerctl absolute seek failed"
                return $?
            fi
            ;;
    esac

    emit_action_result \
        "$json_output" "applied" "$action_name" true \
        "player" "$selected" "$capability" \
        "Media action applied successfully"
}

audio_sink_action() {
    local operation="$1"
    local argument="$2"
    local json_output="$3"
    local action_name="audio.$operation"
    local selector="@DEFAULT_AUDIO_SINK@"
    local backend_value=""

    if ! command_available wpctl; then
        fail_action \
            3 "$json_output" "dependency-unavailable" "$action_name" false \
            "audio-sink" "$selector" "" "wpctl is unavailable"
        return $?
    fi

    if ! wpctl get-volume "$selector" >/dev/null 2>&1; then
        fail_action \
            4 "$json_output" "target-unavailable" "$action_name" false \
            "audio-sink" "$selector" "" "Default audio sink is unavailable"
        return $?
    fi

    case "$operation" in
        sink-volume)
            if ! awk -v value="$argument" '
                BEGIN {
                    if (value !~ /^[0-9]+([.][0-9]+)?$/) exit 1
                    exit(value >= 0 && value <= 1 ? 0 : 1)
                }
            '
            then
                die_usage "sink volume must be a number in the 0..1 range"
            fi

            if ! wpctl set-volume "$selector" "$argument"; then
                fail_action \
                    6 "$json_output" "backend-failed" "$action_name" false \
                    "audio-sink" "$selector" "" \
                    "wpctl set-volume failed"
                return $?
            fi
            ;;
        sink-mute)
            case "$argument" in
                on)
                    backend_value=1
                    ;;
                off)
                    backend_value=0
                    ;;
                toggle)
                    backend_value=toggle
                    ;;
                *)
                    die_usage "sink mute must be on, off or toggle"
                    ;;
            esac

            if ! wpctl set-mute "$selector" "$backend_value"; then
                fail_action \
                    6 "$json_output" "backend-failed" "$action_name" false \
                    "audio-sink" "$selector" "" \
                    "wpctl set-mute failed"
                return $?
            fi
            ;;
        *)
            die_usage "unsupported audio action: $operation"
            ;;
    esac

    emit_action_result \
        "$json_output" "applied" "$action_name" true \
        "audio-sink" "$selector" "" \
        "Audio action applied successfully"
}

case "${1:-}" in
    status)
        shift

        if [[ "$#" -eq 0 ]]; then
            status_human
            exit 0
        fi

        if [[ "$#" -eq 1 && "$1" == "--json" ]]; then
            status_json
            exit 0
        fi

        die_usage "unsupported status argument"
        ;;
    player)
        shift

        player_args=("$@")
        player_json=false

        if parse_json_suffix player_args; then
            player_json=true
        fi

        [[ ${#player_args[@]} -ge 1 ]] \
            || die_usage "missing player action"

        case "${player_args[0]}" in
            play-pause|next|previous)
                [[ ${#player_args[@]} -eq 1 ]] \
                    || die_usage "${player_args[0]} accepts no value"

                player_action \
                    "${player_args[0]}" "" "$player_json"
                ;;
            seek)
                [[ ${#player_args[@]} -eq 2 ]] \
                    || die_usage "seek requires absolute seconds"

                player_action \
                    "seek" "${player_args[1]}" "$player_json"
                ;;
            *)
                die_usage "unsupported player action: ${player_args[0]}"
                ;;
        esac
        ;;
    audio)
        shift

        audio_args=("$@")
        audio_json=false

        if parse_json_suffix audio_args; then
            audio_json=true
        fi

        [[ ${#audio_args[@]} -ge 1 ]] \
            || die_usage "missing audio action"

        case "${audio_args[0]}" in
            sink-volume|sink-mute)
                [[ ${#audio_args[@]} -eq 2 ]] \
                    || die_usage "${audio_args[0]} requires one value"

                audio_sink_action \
                    "${audio_args[0]}" "${audio_args[1]}" "$audio_json"
                ;;
            *)
                die_usage "unsupported audio action: ${audio_args[0]}"
                ;;
        esac
        ;;
    --help|-h|help)
        [[ "$#" -eq 1 ]] \
            || die_usage "help accepts no additional arguments"

        usage
        ;;
    "")
        die_usage "missing command"
        ;;
    *)
        die_usage "unsupported command: $1"
        ;;
esac
