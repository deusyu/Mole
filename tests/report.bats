#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-report-home.XXXXXX")"
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
    rm -r "$HOME/www" "$HOME/Downloads" "$HOME/Library" "$HOME/.config" 2> /dev/null || true
    mkdir -p "$HOME/www" "$HOME/Downloads" "$HOME/Library/Logs/mole"
}

create_report_fixtures() {
    mkdir -p "$HOME/www/test-project/node_modules"
    echo "{}" > "$HOME/www/test-project/package.json"
    echo "module" > "$HOME/www/test-project/node_modules/file.js"
    touch -t 202001010101 "$HOME/www/test-project/node_modules" "$HOME/www/test-project/package.json" "$HOME/www/test-project"
    printf 'installer' > "$HOME/Downloads/Test.dmg"
}

@test "mo report --json emits top-level report fields" {
    run env HOME="$HOME" MOLE_TEST_NO_AUTH=1 "$PROJECT_ROOT/mole" report --json

    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | python3 -c '
import json
import sys
data = json.load(sys.stdin)
assert data["schema_version"] == 1
assert data["command"] == "report"
assert "generated_at" in data
assert data["summary"]["total_observed_bytes"] >= 0
assert isinstance(data["developer_projects"], list)
assert isinstance(data["dev_caches"], list)
assert isinstance(data["installers"], list)
assert isinstance(data["history"], dict)
assert isinstance(data["recommended_commands"], list)
assert isinstance(data["protected_or_skipped"], list)
'
}

@test "mo report --json includes project and installer sources" {
    create_report_fixtures

    run env HOME="$HOME" MOLE_TEST_NO_AUTH=1 "$PROJECT_ROOT/mole" report --json

    [ "$status" -eq 0 ]
    [ -d "$HOME/www/test-project/node_modules" ]
    [ -f "$HOME/Downloads/Test.dmg" ]
    printf '%s\n' "$output" | python3 -c '
import json
import sys
data = json.load(sys.stdin)
assert any(item["name"] == "node_modules" for item in data["developer_projects"])
assert any(item["name"] == "Test.dmg" for item in data["installers"])
commands = data["recommended_commands"]
assert "mo purge --dry-run" in commands
assert "mo installer --dry-run" in commands
assert "mo analyze" in commands
'
}

@test "mo report --json does not write purge config" {
    run env HOME="$HOME" MOLE_TEST_NO_AUTH=1 "$PROJECT_ROOT/mole" report --json

    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.config/mole/purge_paths" ]
}

@test "mo report --markdown renders required sections" {
    create_report_fixtures

    run env HOME="$HOME" MOLE_TEST_NO_AUTH=1 "$PROJECT_ROOT/mole" report --markdown

    [ "$status" -eq 0 ]
    [[ "$output" == \#\ Mole\ Developer\ Space\ Report* ]]
    [[ "$output" == *"## Summary"* ]]
    [[ "$output" == *"## Developer Projects"* ]]
    [[ "$output" == *"## Dev Caches"* ]]
    [[ "$output" == *"## Installers"* ]]
    [[ "$output" == *"## Cleanup History"* ]]
    [[ "$output" == *"## Recommended Commands"* ]]
    [[ "$output" == *"## Protected Or Manual Review"* ]]
    [[ "$output" == *"mo purge --dry-run"* ]]
    [[ "$output" == *"mo installer --dry-run"* ]]
    [[ "$output" == *"credential-adjacent"* ]]
}

@test "mo report rejects ambiguous or missing output format" {
    run env HOME="$HOME" MOLE_TEST_NO_AUTH=1 "$PROJECT_ROOT/mole" report
    [ "$status" -eq 1 ]
    [[ "$output" == *"Choose a report output format"* ]]

    run env HOME="$HOME" MOLE_TEST_NO_AUTH=1 "$PROJECT_ROOT/mole" report --json --markdown
    [ "$status" -eq 1 ]
    [[ "$output" == *"Choose only one report output format"* ]]
}
