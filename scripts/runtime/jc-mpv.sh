#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# jc-mpv
#
# Wrapper para mpv:
#
# - Detecta HDR mediante ffprobe
# - HDR:
#     DP-3 -> 5120x2160 @ 120Hz / 10-bit / HDR
# - SDR:
#     mantiene 5120x2160 @ 180Hz / 10-bit / sRGB
# - Al cerrar mpv restaura SIEMPRE SDR / 180Hz
#
# Pensado para:
#   Hyprland 0.56+
#   AMD Radeon / RADV
#   Samsung Odyssey G75F
# ============================================================


# ------------------------------------------------------------
# Monitor
# ------------------------------------------------------------

MONITOR="DP-3"

MODE_DESKTOP="5120x2160@179.985"
MODE_CINEMA="5120x2160@120"

POSITION="0x1440"
SCALE="1"


# ------------------------------------------------------------
# Estado
# ------------------------------------------------------------

HDR_ACTIVE=0


# ------------------------------------------------------------
# Dependencias
# ------------------------------------------------------------

for cmd in mpv ffprobe hyprctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: falta la dependencia '$cmd'." >&2
        exit 1
    fi
done


# ------------------------------------------------------------
# Funciones monitor
# ------------------------------------------------------------

set_hdr_mode() {

    echo
    echo "🎬 Activando modo Cinema HDR..."
    echo "   ${MODE_CINEMA}"
    echo "   10-bit"
    echo "   HDR / PQ"
    echo

    hyprctl eval "hl.monitor({
        output = \"${MONITOR}\",
        mode = \"${MODE_CINEMA}\",
        position = \"${POSITION}\",
        scale = ${SCALE},
        bitdepth = 10,
        cm = \"hdr\"
    })" >/dev/null

    HDR_ACTIVE=1

    # Darle un momento al monitor para renegociar el modo
    sleep 0.7
}


set_desktop_mode() {

    echo
    echo "🖥️  Restaurando modo Desktop..."
    echo "   ${MODE_DESKTOP}"
    echo "   10-bit"
    echo "   sRGB / SDR"
    echo

    hyprctl eval "hl.monitor({
        output = \"${MONITOR}\",
        mode = \"${MODE_DESKTOP}\",
        position = \"${POSITION}\",
        scale = ${SCALE},
        bitdepth = 10,
        cm = \"srgb\"
    })" >/dev/null

    HDR_ACTIVE=0
}


restore_monitor() {

    if (( HDR_ACTIVE )); then
        set_desktop_mode
    fi
}


# Restaurar incluso con Ctrl+C o errores.
trap restore_monitor EXIT

trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP


# ------------------------------------------------------------
# Argumentos
# ------------------------------------------------------------

if (( $# == 0 )); then
    echo "Uso:"
    echo "  jc-mpv <archivo> [opciones mpv]"
    echo
    echo "Ejemplo:"
    echo "  jc-mpv ~/Videos/ExodusSample.mp4"
    exit 1
fi


# ------------------------------------------------------------
# Buscar primer archivo local entre los argumentos
# ------------------------------------------------------------

MEDIA_FILE=""

for arg in "$@"; do
    if [[ -f "$arg" ]]; then
        MEDIA_FILE="$arg"
        break
    fi
done


# URLs / streams / etc.
# Si no hay archivo local, dejamos que mpv lo maneje normalmente.

if [[ -z "$MEDIA_FILE" ]]; then
    exec mpv "$@"
fi


# ------------------------------------------------------------
# Detectar color transfer
# ------------------------------------------------------------

COLOR_TRANSFER="$(
    ffprobe \
        -v error \
        -select_streams v:0 \
        -show_entries stream=color_transfer \
        -of default=noprint_wrappers=1:nokey=1 \
        "$MEDIA_FILE" \
        2>/dev/null \
        | head -n1
)"


COLOR_PRIMARIES="$(
    ffprobe \
        -v error \
        -select_streams v:0 \
        -show_entries stream=color_primaries \
        -of default=noprint_wrappers=1:nokey=1 \
        "$MEDIA_FILE" \
        2>/dev/null \
        | head -n1
)"


PIX_FMT="$(
    ffprobe \
        -v error \
        -select_streams v:0 \
        -show_entries stream=pix_fmt \
        -of default=noprint_wrappers=1:nokey=1 \
        "$MEDIA_FILE" \
        2>/dev/null \
        | head -n1
)"


# ------------------------------------------------------------
# Detectar HDR
#
# smpte2084   = HDR10 / HDR10+
# arib-std-b67 = HLG
# ------------------------------------------------------------

IS_HDR=0

case "$COLOR_TRANSFER" in

    smpte2084)
        IS_HDR=1
        HDR_TYPE="HDR10 / PQ"
        ;;

    arib-std-b67)
        IS_HDR=1
        HDR_TYPE="HLG"
        ;;

    *)
        IS_HDR=0
        HDR_TYPE="SDR"
        ;;
esac


# ------------------------------------------------------------
# Información
# ------------------------------------------------------------

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " jc-mpv"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Archivo:"
echo "  $MEDIA_FILE"
echo
echo "Transfer:"
echo "  ${COLOR_TRANSFER:-unknown}"
echo
echo "Primaries:"
echo "  ${COLOR_PRIMARIES:-unknown}"
echo
echo "Pixel format:"
echo "  ${PIX_FMT:-unknown}"
echo


# ------------------------------------------------------------
# HDR
# ------------------------------------------------------------

if (( IS_HDR )); then

    echo "Contenido:"
    echo "  ✅ ${HDR_TYPE}"
    echo

    set_hdr_mode

else

    echo "Contenido:"
    echo "  SDR"
    echo

fi


# ------------------------------------------------------------
# Ejecutar mpv
# ------------------------------------------------------------

mpv --fullscreen "$@"
