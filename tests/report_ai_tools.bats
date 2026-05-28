#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-report-ai-home.XXXXXX")"
    export HOME
}

teardown_file() {
    if [[ "$HOME" == "${BATS_TEST_DIRNAME}/tmp-"* ]]; then
        rm -r "$HOME"
    fi
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

setup() {
    if [[ "$HOME" != "${BATS_TEST_DIRNAME}/tmp-"* ]]; then
        printf 'FATAL: HOME is not a test temp dir: %s\n' "$HOME" >&2
        return 1
    fi
    rm -r "$HOME/.codex" "$HOME/.claude" "$HOME/.gemini" "$HOME/.cache" "$HOME/Library" 2> /dev/null || true
    mkdir -p "$HOME/Library/Logs/mole"
}

@test "mo report --json classifies Codex caches and protected state" {
    mkdir -p "$HOME/.codex/cache" "$HOME/.codex/sessions"
    printf 'cache' > "$HOME/.codex/cache/blob"
    printf 'session' > "$HOME/.codex/sessions/session.jsonl"
    printf 'token' > "$HOME/.codex/auth.json"
    printf 'history' > "$HOME/.codex/history.jsonl"
    printf 'sqlite' > "$HOME/.codex/state.sqlite"

    run env HOME="$HOME" MOLE_TEST_NO_AUTH=1 "$PROJECT_ROOT/mole" report --json

    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | python3 -c '
import json
import sys
data = json.load(sys.stdin)
dev = data["dev_caches"]
protected = data["protected_or_skipped"]
assert any(item["name"] == "Codex CLI cache" and item["category"] == "ai_tool_cache" for item in dev)
for name in ["Codex CLI sessions", "Codex CLI auth", "Codex CLI history", "Codex CLI database"]:
    item = next(item for item in protected if item["name"] == name)
    assert item["risk_level"] == "high"
    assert item["protected"] is True
    assert item["selected_by_default"] is False
'
}

@test "mo report --markdown states AI protected data is manual review" {
    mkdir -p "$HOME/.claude"
    printf 'memory' > "$HOME/.claude/memory.json"

    run env HOME="$HOME" MOLE_TEST_NO_AUTH=1 "$PROJECT_ROOT/mole" report --markdown

    [ "$status" -eq 0 ]
    [[ "$output" == *"AI tool"* ]]
    [[ "$output" == *"manual review"* ]]
    [[ "$output" == *"credential-adjacent"* ]]
}
