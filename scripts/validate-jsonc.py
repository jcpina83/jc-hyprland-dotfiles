#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


PLACEHOLDERS = {
    "@MAIN_OUTPUT@": "DP-TEST",
    "@SECONDARY_OUTPUT@": "DP-TEST2",
    "@MAIN_WORKSPACES@": "1,2,3,4,5",
    "@SECONDARY_WORKSPACES@": "6,7,8,9,10",
}


def strip_comments(text: str) -> str:
    result = []

    i = 0
    in_string = False
    escaped = False

    while i < len(text):
        char = text[i]

        if in_string:
            result.append(char)

            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False

            i += 1
            continue

        if char == '"':
            in_string = True
            result.append(char)
            i += 1
            continue

        if char == "/" and i + 1 < len(text):
            next_char = text[i + 1]

            # // comment
            if next_char == "/":
                i += 2

                while i < len(text) and text[i] != "\n":
                    i += 1

                if i < len(text):
                    result.append("\n")
                    i += 1

                continue

            # /* comment */
            if next_char == "*":
                i += 2

                while i + 1 < len(text):
                    if text[i] == "\n":
                        result.append("\n")

                    if text[i] == "*" and text[i + 1] == "/":
                        i += 2
                        break

                    i += 1

                continue

        result.append(char)
        i += 1

    return "".join(result)


def remove_trailing_commas(text: str) -> str:
    result = []

    i = 0
    in_string = False
    escaped = False

    while i < len(text):
        char = text[i]

        if in_string:
            result.append(char)

            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False

            i += 1
            continue

        if char == '"':
            in_string = True
            result.append(char)
            i += 1
            continue

        if char == ",":
            j = i + 1

            while j < len(text) and text[j].isspace():
                j += 1

            if j < len(text) and text[j] in "}]":
                i += 1
                continue

        result.append(char)
        i += 1

    return "".join(result)


def prepare_template(text: str) -> str:
    for placeholder, replacement in PLACEHOLDERS.items():
        text = text.replace(placeholder, replacement)

    # Only placeholders owned by jc-hyprland-dotfiles are validated.
    #
    # Application tokens such as:
    #
    #   @DEFAULT_AUDIO_SINK@
    #
    # are deliberately ignored.
    unresolved = [
        placeholder
        for placeholder in PLACEHOLDERS
        if placeholder in text
    ]

    if unresolved:
        raise ValueError(
            "unresolved jc-hyprland-dotfiles placeholder(s): "
            + ", ".join(sorted(unresolved))
        )

    return text


def validate(path: Path) -> bool:
    try:
        text = path.read_text(encoding="utf-8")

        text = prepare_template(text)
        text = strip_comments(text)
        text = remove_trailing_commas(text)

        json.loads(text)

        print(f"  JSONC OK  {path}")
        return True

    except json.JSONDecodeError as error:
        print(
            f"  JSONC FAIL {path}: "
            f"line {error.lineno}, column {error.colno}: {error.msg}",
            file=sys.stderr,
        )

    except Exception as error:
        print(
            f"  JSONC FAIL {path}: {error}",
            file=sys.stderr,
        )

    return False


def main() -> int:
    if len(sys.argv) < 2:
        print(
            f"Usage: {sys.argv[0]} FILE [...]",
            file=sys.stderr,
        )
        return 2

    success = True

    for filename in sys.argv[1:]:
        if not validate(Path(filename)):
            success = False

    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())