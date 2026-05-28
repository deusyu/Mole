#!/bin/bash
# Mole - shared JSON helpers for shell commands.

set -euo pipefail

if [[ -n "${MOLE_JSON_LOADED:-}" ]]; then
    return 0
fi
readonly MOLE_JSON_LOADED=1

mole_json_escape() {
    local value="${1:-}"
    local LC_ALL=C
    local char code idx

    idx=0
    while [[ "$idx" -lt "${#value}" ]]; do
        char="${value:$idx:1}"
        case "$char" in
            "\\") printf '%s' "\\\\" ;;
            "\"") printf '%s' "\\\"" ;;
            $'\b') printf '%s' "\\b" ;;
            $'\f') printf '%s' "\\f" ;;
            $'\n') printf '%s' "\\n" ;;
            $'\r') printf '%s' "\\r" ;;
            $'\t') printf '%s' "\\t" ;;
            *)
                printf -v code '%d' "'$char"
                if [[ "$code" -lt 0 ]]; then
                    code=$((code + 256))
                fi
                if [[ "$code" -lt 32 ]]; then
                    printf '\\u%04x' "$code"
                else
                    printf '%s' "$char"
                fi
                ;;
        esac
        idx=$((idx + 1))
    done
}

mole_json_string() {
    printf '"'
    mole_json_escape "${1:-}"
    printf '"'
}

mole_json_bool() {
    case "${1:-false}" in
        true | TRUE | True | 1 | yes | YES | Yes)
            printf 'true'
            ;;
        *)
            printf 'false'
            ;;
    esac
}

mole_json_number_or_null() {
    local value="${1:-}"
    if [[ "$value" =~ ^-?(0|[1-9][0-9]*)([.][0-9]+)?$ ]]; then
        printf '%s' "$value"
    else
        printf 'null'
    fi
}

mole_json_string_field() {
    local indent="$1"
    local key="$2"
    local value="${3:-}"
    local suffix="${4-,}"

    printf '%s' "$indent"
    mole_json_string "$key"
    printf ': '
    mole_json_string "$value"
    printf '%s\n' "$suffix"
}

mole_json_bool_field() {
    local indent="$1"
    local key="$2"
    local value="${3:-false}"
    local suffix="${4-,}"

    printf '%s' "$indent"
    mole_json_string "$key"
    printf ': '
    mole_json_bool "$value"
    printf '%s\n' "$suffix"
}

mole_json_number_field() {
    local indent="$1"
    local key="$2"
    local value="${3:-}"
    local suffix="${4-,}"

    printf '%s' "$indent"
    mole_json_string "$key"
    printf ': '
    mole_json_number_or_null "$value"
    printf '%s\n' "$suffix"
}

mole_json_null_field() {
    local indent="$1"
    local key="$2"
    local suffix="${3-,}"

    printf '%s' "$indent"
    mole_json_string "$key"
    printf ': null%s\n' "$suffix"
}
