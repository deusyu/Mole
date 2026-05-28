#!/bin/bash
# Mole - Developer space report command.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/core/common.sh"
source "$ROOT_DIR/lib/core/history.sh"

REPORT_JSON=false
REPORT_MARKDOWN=false

show_report_help() {
    echo "Usage: mo report (--json|--markdown)"
    echo ""
    echo "Generate a read-only developer space audit report."
    echo ""
    echo "Options:"
    echo "  --json           Output report as JSON"
    echo "  --markdown       Output report as Markdown"
    echo "  -h, --help       Show this help message"
}

report_run_json_source() {
    local command_name="$1"
    shift

    "$@" 2> /dev/null || {
        printf '{\n'
        mole_json_number_field "  " "schema_version" 1
        mole_json_string_field "  " "command" "$command_name"
        printf '  "items": [],\n'
        printf '  "summary": {"total_size_bytes": 0, "item_count": 0, "selected_size_bytes": 0, "selected_count": 0}\n'
        printf '}\n'
    }
}

report_json_extract_array() {
    local key="$1"
    awk -v key="$key" '
        BEGIN { found = 0 }
        found == 0 {
            needle = "\"" key "\": ["
            pos = index($0, needle)
            if (pos > 0) {
                line = substr($0, pos + length("\"" key "\": "))
                sub(/,$/, "", line)
                print line
                if (line ~ /\]/) {
                    exit
                }
                found = 1
            }
            next
        }
        found == 1 {
            line = $0
            if (line ~ /^  \],?$/) {
                sub(/,$/, "", line)
                print line
                exit
            }
            print line
        }
    '
}

report_json_summary_value() {
    local key="$1"
    awk -v key="$key" '
        index($0, "\"" key "\":") > 0 {
            line = $0
            gsub(/[^0-9]/, "", line)
            if (line == "") {
                print 0
            } else {
                print line
            }
            exit
        }
    '
}

report_json_risk_totals() {
    awk '
        BEGIN { low = 0; medium = 0; high = 0; size = 0; risk = "" }
        /"size_bytes":/ {
            if ($0 ~ /null/) {
                size = 0
            } else {
                line = $0
                gsub(/[^0-9]/, "", line)
                size = line + 0
            }
        }
        /"risk_level":/ {
            if ($0 ~ /"low"/) risk = "low"
            else if ($0 ~ /"medium"/) risk = "medium"
            else if ($0 ~ /"high"/) risk = "high"
        }
        /^[[:space:]]*}/ {
            if (risk == "low") low += size
            else if (risk == "medium") medium += size
            else if (risk == "high") high += size
            size = 0
            risk = ""
        }
        END { print low, medium, high }
    '
}

report_load_history_json() {
    history_load_operations "$(history_operations_log_file)"
    history_load_deletions "$(history_deletions_log_file)"
    history_render_json "$MOLE_HISTORY_DEFAULT_LIMIT"
}

report_recommended_commands_json() {
    local purge_selected_count="$1"
    local installer_count="$2"
    local first=true

    printf '['
    if [[ "$purge_selected_count" =~ ^[0-9]+$ && "$purge_selected_count" -gt 0 ]]; then
        printf '\n    '
        mole_json_string "mo purge --dry-run"
        first=false
    fi
    if [[ "$installer_count" =~ ^[0-9]+$ && "$installer_count" -gt 0 ]]; then
        if [[ "$first" == "true" ]]; then
            printf '\n    '
            first=false
        else
            printf ',\n    '
        fi
        mole_json_string "mo installer --dry-run"
    fi
    if [[ "$first" == "true" ]]; then
        printf '\n    '
        first=false
    else
        printf ',\n    '
    fi
    mole_json_string "mo analyze"
    printf ',\n    '
    mole_json_string "mo history --json"
    printf '\n  ]'
}

report_render_json() {
    local purge_json installer_json history_json
    purge_json=$(MOLE_PURGE_NO_CONFIG_WRITE=1 report_run_json_source "purge" "$ROOT_DIR/bin/purge.sh" --json)
    installer_json=$(report_run_json_source "installer" "$ROOT_DIR/bin/installer.sh" --json)
    history_json=$(report_load_history_json)

    local purge_total purge_selected_count installer_total installer_count
    purge_total=$(printf '%s\n' "$purge_json" | report_json_summary_value "total_size_bytes")
    purge_selected_count=$(printf '%s\n' "$purge_json" | report_json_summary_value "selected_count")
    installer_total=$(printf '%s\n' "$installer_json" | report_json_summary_value "total_size_bytes")
    installer_count=$(printf '%s\n' "$installer_json" | report_json_summary_value "item_count")

    local purge_low purge_medium purge_high installer_low installer_medium installer_high
    read -r purge_low purge_medium purge_high <<< "$(printf '%s\n' "$purge_json" | report_json_risk_totals)"
    read -r installer_low installer_medium installer_high <<< "$(printf '%s\n' "$installer_json" | report_json_risk_totals)"

    local low_risk_bytes=$((purge_low + installer_low))
    local medium_risk_bytes=$((purge_medium + installer_medium))
    local high_risk_bytes=$((purge_high + installer_high))
    local total_observed_bytes=$((low_risk_bytes + medium_risk_bytes + high_risk_bytes))
    if [[ "$total_observed_bytes" -eq 0 ]]; then
        total_observed_bytes=$((purge_total + installer_total))
    fi

    printf '{\n'
    mole_json_number_field "  " "schema_version" 1
    mole_json_string_field "  " "command" "report"
    mole_json_string_field "  " "generated_at" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf '  "summary": {\n'
    mole_json_number_field "    " "total_observed_bytes" "$total_observed_bytes"
    mole_json_number_field "    " "low_risk_bytes" "$low_risk_bytes"
    mole_json_number_field "    " "medium_risk_bytes" "$medium_risk_bytes"
    mole_json_number_field "    " "high_risk_bytes" "$high_risk_bytes" ""
    printf '  },\n'
    printf '  "developer_projects": '
    printf '%s\n' "$purge_json" | report_json_extract_array "items"
    printf ',\n'
    printf '  "dev_caches": [],\n'
    printf '  "installers": '
    printf '%s\n' "$installer_json" | report_json_extract_array "items"
    printf ',\n'
    printf '  "history": '
    printf '%s\n' "$history_json"
    printf ',\n'
    printf '  "recommended_commands": '
    report_recommended_commands_json "$purge_selected_count" "$installer_count"
    printf ',\n'
    printf '  "protected_or_skipped": []\n'
    printf '}\n'
}

report_render_markdown() {
    local purge_json installer_json history_json
    purge_json=$(MOLE_PURGE_NO_CONFIG_WRITE=1 report_run_json_source "purge" "$ROOT_DIR/bin/purge.sh" --json)
    installer_json=$(report_run_json_source "installer" "$ROOT_DIR/bin/installer.sh" --json)
    history_json=$(report_load_history_json)

    local purge_total purge_count purge_selected_count installer_total installer_count
    purge_total=$(printf '%s\n' "$purge_json" | report_json_summary_value "total_size_bytes")
    purge_count=$(printf '%s\n' "$purge_json" | report_json_summary_value "item_count")
    purge_selected_count=$(printf '%s\n' "$purge_json" | report_json_summary_value "selected_count")
    installer_total=$(printf '%s\n' "$installer_json" | report_json_summary_value "total_size_bytes")
    installer_count=$(printf '%s\n' "$installer_json" | report_json_summary_value "item_count")

    echo "# Mole Developer Space Report"
    echo ""
    echo "Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "## Summary"
    echo ""
    echo "- Project artifacts observed: ${purge_count:-0}"
    echo "- Project artifact bytes: ${purge_total:-0}"
    echo "- Installer files observed: ${installer_count:-0}"
    echo "- Installer bytes: ${installer_total:-0}"
    echo ""
    echo "## Developer Projects"
    echo ""
    if [[ "${purge_count:-0}" -gt 0 ]]; then
        echo "Mole found project artifacts. Review with \`mo purge --dry-run\` before removing anything."
    else
        echo "No project artifacts were found in the configured purge paths."
    fi
    echo ""
    echo "## Dev Caches"
    echo ""
    echo "Developer cache details are reported when conservative source data is available."
    echo ""
    echo "## Installers"
    echo ""
    if [[ "${installer_count:-0}" -gt 0 ]]; then
        echo "Mole found installer files. Review with \`mo installer --dry-run\`."
    else
        echo "No installer files were found in the standard scan paths."
    fi
    echo ""
    echo "## Cleanup History"
    echo ""
    local history_sessions
    history_sessions=$(printf '%s\n' "$history_json" | report_json_summary_value "limit")
    echo "Recent cleanup history is available with \`mo history --json\`."
    echo ""
    echo "## Recommended Commands"
    echo ""
    if [[ "${purge_selected_count:-0}" -gt 0 ]]; then
        echo "- \`mo purge --dry-run\`"
    fi
    if [[ "${installer_count:-0}" -gt 0 ]]; then
        echo "- \`mo installer --dry-run\`"
    fi
    echo "- \`mo analyze\`"
    echo "- \`mo history --json\`"
    echo ""
    echo "## Protected Or Manual Review"
    echo ""
    echo "Protected, session, config, credential-adjacent, history, and database items are not auto-cleaned by this report."
    echo "Use the recommended commands above to review safe existing Mole cleanup paths."
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--json")
                REPORT_JSON=true
                ;;
            "--markdown")
                REPORT_MARKDOWN=true
                ;;
            "--help" | "-h")
                show_report_help
                exit 0
                ;;
            *)
                echo "Unknown option for mo report: $1" >&2
                echo "Run 'mo report --help' for usage." >&2
                exit 1
                ;;
        esac
        shift
    done

    if [[ "$REPORT_JSON" == "true" && "$REPORT_MARKDOWN" == "true" ]]; then
        echo "Choose only one report output format: --json or --markdown" >&2
        exit 1
    fi
    if [[ "$REPORT_JSON" != "true" && "$REPORT_MARKDOWN" != "true" ]]; then
        echo "Choose a report output format: --json or --markdown" >&2
        echo "Run 'mo report --help' for usage." >&2
        exit 1
    fi

    if [[ "$REPORT_JSON" == "true" ]]; then
        report_render_json
    else
        report_render_markdown
    fi
}

main "$@"
