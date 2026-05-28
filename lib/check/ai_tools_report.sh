#!/bin/bash
# Read-only AI tool data audit for mo report.

set -euo pipefail

if [[ -n "${MOLE_AI_TOOLS_REPORT_LOADED:-}" ]]; then
    return 0
fi
readonly MOLE_AI_TOOLS_REPORT_LOADED=1

AI_REPORT_PATHS=()
AI_REPORT_NAMES=()
AI_REPORT_CATEGORIES=()
AI_REPORT_ECOSYSTEMS=()
AI_REPORT_SIZES=()
AI_REPORT_RISK_LEVELS=()
AI_REPORT_RISK_REASONS=()
AI_REPORT_RECOVERABLE=()
AI_REPORT_PROTECTED=()
AI_REPORT_WHITELISTED=()
AI_REPORT_SELECTED_DEFAULT=()
AI_REPORT_RECOMMENDED_ACTIONS=()

ai_report_size_bytes() {
    local path="$1"
    local size=0

    if [[ -d "$path" ]]; then
        size=$(get_path_size_kb "$path" 2> /dev/null || echo 0)
        [[ "$size" =~ ^[0-9]+$ ]] || size=0
        echo "$((size * 1024))"
        return 0
    fi

    if [[ -f "$path" ]]; then
        size=$(get_file_size "$path" 2> /dev/null || echo 0)
        if [[ ! "$size" =~ ^[0-9]+$ || "$size" -eq 0 ]]; then
            size=$(stat -c %s "$path" 2> /dev/null || echo 0)
        fi
        [[ "$size" =~ ^[0-9]+$ ]] || size=0
        echo "$size"
        return 0
    fi

    echo 0
}

ai_report_add_item() {
    local path="$1"
    local name="$2"
    local category="$3"
    local ecosystem="$4"
    local risk_level="$5"
    local risk_reason="$6"
    local protected="$7"
    local recommended_action="$8"

    [[ -e "$path" || -L "$path" ]] || return 0

    local whitelisted=false
    if declare -f is_path_whitelisted > /dev/null 2>&1 && is_path_whitelisted "$path" 2> /dev/null; then
        whitelisted=true
    fi

    AI_REPORT_PATHS+=("$path")
    AI_REPORT_NAMES+=("$name")
    AI_REPORT_CATEGORIES+=("$category")
    AI_REPORT_ECOSYSTEMS+=("$ecosystem")
    AI_REPORT_SIZES+=("$(ai_report_size_bytes "$path")")
    AI_REPORT_RISK_LEVELS+=("$risk_level")
    AI_REPORT_RISK_REASONS+=("$risk_reason")
    AI_REPORT_RECOVERABLE+=("false")
    AI_REPORT_PROTECTED+=("$protected")
    AI_REPORT_WHITELISTED+=("$whitelisted")
    AI_REPORT_SELECTED_DEFAULT+=("false")
    AI_REPORT_RECOMMENDED_ACTIONS+=("$recommended_action")
}

ai_tools_report_collect() {
    AI_REPORT_PATHS=()
    AI_REPORT_NAMES=()
    AI_REPORT_CATEGORIES=()
    AI_REPORT_ECOSYSTEMS=()
    AI_REPORT_SIZES=()
    AI_REPORT_RISK_LEVELS=()
    AI_REPORT_RISK_REASONS=()
    AI_REPORT_RECOVERABLE=()
    AI_REPORT_PROTECTED=()
    AI_REPORT_WHITELISTED=()
    AI_REPORT_SELECTED_DEFAULT=()
    AI_REPORT_RECOMMENDED_ACTIONS=()

    # Codex CLI: caches are regenerable, state and auth are protected.
    ai_report_add_item "$HOME/.codex/cache" "Codex CLI cache" "ai_tool_cache" "codex" "low" "Regenerable Codex CLI cache" false "manual_review"
    ai_report_add_item "$HOME/.codex/.tmp" "Codex CLI temp files" "ai_tool_cache" "codex" "low" "Temporary Codex CLI files" false "manual_review"
    ai_report_add_item "$HOME/.codex/log" "Codex CLI logs" "ai_tool_cache" "codex" "medium" "Codex logs may help debugging, review before removal" false "manual_review"
    ai_report_add_item "$HOME/.codex/sessions" "Codex CLI sessions" "protected_data" "codex" "high" "Session history is protected and not auto-cleaned" true "manual_review"
    ai_report_add_item "$HOME/.codex/auth.json" "Codex CLI auth" "protected_data" "codex" "high" "Credential-adjacent auth data is protected" true "manual_review"
    ai_report_add_item "$HOME/.codex/history.jsonl" "Codex CLI history" "history" "codex" "high" "Command and conversation history is protected" true "manual_review"

    local codex_db
    for codex_db in "$HOME/.codex"/*.sqlite "$HOME/.codex"/*.db; do
        [[ -e "$codex_db" ]] || continue
        ai_report_add_item "$codex_db" "Codex CLI database" "protected_data" "codex" "high" "SQLite databases may contain session state" true "manual_review"
    done

    # Claude Code and Claude Desktop.
    ai_report_add_item "$HOME/.claude" "Claude Code state" "protected_data" "claude" "high" "Claude Code state can include memory, hooks, settings, and sessions" true "manual_review"
    ai_report_add_item "$HOME/Library/Application Support/Claude/Cache" "Claude cache" "ai_tool_cache" "claude" "low" "Regenerable Claude Desktop cache" false "manual_review"
    ai_report_add_item "$HOME/Library/Application Support/Claude/Code Cache" "Claude code cache" "ai_tool_cache" "claude" "low" "Regenerable Claude Desktop code cache" false "manual_review"
    ai_report_add_item "$HOME/Library/Application Support/Claude/GPUCache" "Claude GPU cache" "ai_tool_cache" "claude" "low" "Regenerable Claude Desktop GPU cache" false "manual_review"
    ai_report_add_item "$HOME/Library/Application Support/Claude/pending-uploads" "Claude pending uploads" "protected_data" "claude" "high" "Pending uploads require manual review" true "manual_review"

    # Cursor.
    ai_report_add_item "$HOME/Library/Application Support/Cursor/Cache" "Cursor cache" "ai_tool_cache" "cursor" "low" "Regenerable Cursor editor cache" false "manual_review"
    ai_report_add_item "$HOME/Library/Application Support/Cursor/Code Cache" "Cursor code cache" "ai_tool_cache" "cursor" "low" "Regenerable Cursor code cache" false "manual_review"
    ai_report_add_item "$HOME/Library/Application Support/Cursor/GPUCache" "Cursor GPU cache" "ai_tool_cache" "cursor" "low" "Regenerable Cursor GPU cache" false "manual_review"
    ai_report_add_item "$HOME/Library/Application Support/Cursor/User" "Cursor user data" "protected_data" "cursor" "high" "Editor settings, state, and credentials require manual review" true "manual_review"
    ai_report_add_item "$HOME/.cursor" "Cursor configuration" "protected_data" "cursor" "high" "Cursor configuration and agent state is protected" true "manual_review"
    ai_report_add_item "$HOME/.local/share/cursor-agent" "Cursor agent state" "protected_data" "cursor" "high" "Agent sessions and logs require manual review" true "manual_review"

    # OpenCode.
    ai_report_add_item "$HOME/.cache/opencode" "OpenCode cache" "ai_tool_cache" "opencode" "medium" "OpenCode cache, review because tool state may vary by version" false "manual_review"
    ai_report_add_item "$HOME/.local/share/opencode/snapshot" "OpenCode snapshots" "ai_tool_workspace" "opencode" "high" "Snapshots may contain generated work and require manual review" true "manual_review"
    ai_report_add_item "$HOME/.local/share/opencode/log" "OpenCode logs" "history" "opencode" "high" "OpenCode logs may contain prompts or project context" true "manual_review"
    ai_report_add_item "$HOME/.config/opencode" "OpenCode config" "protected_data" "opencode" "high" "Configuration is protected" true "manual_review"

    # Gemini CLI and Antigravity.
    ai_report_add_item "$HOME/.gemini/tmp" "Gemini CLI temp files" "ai_tool_cache" "gemini" "low" "Temporary Gemini CLI files" false "manual_review"
    ai_report_add_item "$HOME/.gemini/settings.json" "Gemini CLI settings" "protected_data" "gemini" "high" "Configuration is protected" true "manual_review"
    ai_report_add_item "$HOME/.gemini/oauth_creds.json" "Gemini CLI credentials" "protected_data" "gemini" "high" "Credential-adjacent data is protected" true "manual_review"
    ai_report_add_item "$HOME/.gemini/history" "Gemini CLI history" "history" "gemini" "high" "History requires manual review" true "manual_review"
    ai_report_add_item "$HOME/.gemini/antigravity-browser-profile/Default/Cache" "Antigravity browser cache" "ai_tool_cache" "gemini" "medium" "Browser profile cache, review before removal" false "manual_review"
    ai_report_add_item "$HOME/.gemini/antigravity-browser-profile/Default/Code Cache" "Antigravity code cache" "ai_tool_cache" "gemini" "medium" "Browser profile code cache, review before removal" false "manual_review"
}

ai_tools_report_render_json_array() {
    local group="$1"
    local idx emitted=0

    printf '['
    for ((idx = 0; idx < ${#AI_REPORT_PATHS[@]}; idx++)); do
        local category="${AI_REPORT_CATEGORIES[$idx]}"
        if [[ "$group" == "cache" ]]; then
            [[ "$category" == "ai_tool_cache" ]] || continue
        else
            [[ "$category" != "ai_tool_cache" ]] || continue
        fi

        [[ "$emitted" -gt 0 ]] && printf ','
        printf '\n    {\n'
        mole_json_string_field "      " "path" "${AI_REPORT_PATHS[$idx]}"
        mole_json_string_field "      " "name" "${AI_REPORT_NAMES[$idx]}"
        mole_json_string_field "      " "category" "$category"
        mole_json_string_field "      " "ecosystem" "${AI_REPORT_ECOSYSTEMS[$idx]}"
        mole_json_number_field "      " "size_bytes" "${AI_REPORT_SIZES[$idx]}"
        mole_json_string_field "      " "risk_level" "${AI_REPORT_RISK_LEVELS[$idx]}"
        mole_json_string_field "      " "risk_reason" "${AI_REPORT_RISK_REASONS[$idx]}"
        mole_json_bool_field "      " "recoverable" "${AI_REPORT_RECOVERABLE[$idx]}"
        mole_json_bool_field "      " "protected" "${AI_REPORT_PROTECTED[$idx]}"
        mole_json_bool_field "      " "whitelisted" "${AI_REPORT_WHITELISTED[$idx]}"
        mole_json_bool_field "      " "selected_by_default" "${AI_REPORT_SELECTED_DEFAULT[$idx]}"
        mole_json_string_field "      " "recommended_action" "${AI_REPORT_RECOMMENDED_ACTIONS[$idx]}" ""
        printf '    }'
        emitted=$((emitted + 1))
    done
    if [[ "$emitted" -gt 0 ]]; then
        printf '\n  ]'
    else
        printf ']'
    fi
}

ai_tools_report_risk_totals() {
    local low=0 medium=0 high=0 idx
    for ((idx = 0; idx < ${#AI_REPORT_PATHS[@]}; idx++)); do
        local size="${AI_REPORT_SIZES[$idx]:-0}"
        [[ "$size" =~ ^[0-9]+$ ]] || size=0
        case "${AI_REPORT_RISK_LEVELS[$idx]}" in
            low) low=$((low + size)) ;;
            medium) medium=$((medium + size)) ;;
            high) high=$((high + size)) ;;
        esac
    done
    printf '%s %s %s\n' "$low" "$medium" "$high"
}
