#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT
}

@test "mole_json_string escapes quotes and backslashes" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/json.sh"
mole_json_string 'quote"slash\end'
EOF

    [ "$status" -eq 0 ]
    [ "$output" = '"quote\"slash\\end"' ]
}

@test "mole_json_string escapes tab CR LF and empty strings" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/json.sh"
value=$'tab\tcr\rlf\nend'
mole_json_string "$value"
printf '\n'
mole_json_string ""
EOF

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = '"tab\tcr\rlf\nend"' ]
    [ "${lines[1]}" = '""' ]
}

@test "mole_json_bool emits JSON booleans" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/json.sh"
mole_json_bool true
printf ' '
mole_json_bool 1
printf ' '
mole_json_bool false
printf ' '
mole_json_bool nope
EOF

    [ "$status" -eq 0 ]
    [ "$output" = "true true false false" ]
}

@test "mole_json_number_or_null validates numeric values" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/json.sh"
mole_json_number_or_null 123
printf ' '
mole_json_number_or_null -4.5
printf ' '
mole_json_number_or_null 001
printf ' '
mole_json_number_or_null nope
printf ' '
mole_json_number_or_null ""
EOF

    [ "$status" -eq 0 ]
    [ "$output" = "123 -4.5 null null null" ]
}

@test "field helpers render strings booleans numbers and null suffixes" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/json.sh"
mole_json_string_field "  " "name" "Mole"
mole_json_bool_field "  " "safe" true
mole_json_number_field "  " "size_bytes" 42
mole_json_null_field "  " "ecosystem" ""
EOF

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = '  "name": "Mole",' ]
    [ "${lines[1]}" = '  "safe": true,' ]
    [ "${lines[2]}" = '  "size_bytes": 42,' ]
    [ "${lines[3]}" = '  "ecosystem": null' ]
}
