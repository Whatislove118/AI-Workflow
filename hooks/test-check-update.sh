#!/usr/bin/env bash
# ponytail: smallest runnable check for check-update.sh's branch logic.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/check-update.sh"

fail=0

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL: $label — expected to find [$needle] in: $haystack"
    fail=1
  else
    echo "PASS: $label"
  fi
}

assert_empty() {
  local value="$1" label="$2"
  if [[ -n "$value" ]]; then
    echo "FAIL: $label — expected empty output, got: $value"
    fail=1
  else
    echo "PASS: $label"
  fi
}

# up to date: no output
installed_version() { echo "abc123abc123"; }
remote_version() { echo "abc123abc123"; }
out="$(main)"
assert_empty "$out" "up to date produces no output"

# update available: names both SHAs and the update command
installed_version() { echo "abc123abc123"; }
remote_version() { echo "def456def456"; }
out="$(main)"
assert_contains "$out" "abc123abc123" "update message names installed SHA"
assert_contains "$out" "def456def456" "update message names remote SHA"
assert_contains "$out" "claude plugin update ai-workflow@whatislove118" "update message names the fix command"

# installed_version fails (e.g. no python3 / claude not found): warns, doesn't crash
installed_version() { return 1; }
remote_version() { echo "def456def456"; }
out="$(main)"
assert_contains "$out" "не удалось проверить" "installed_version failure warns instead of crashing"

# remote_version empty (network down): warns, doesn't crash
installed_version() { echo "abc123abc123"; }
remote_version() { echo ""; }
out="$(main)"
assert_contains "$out" "не удалось проверить" "empty remote_version warns instead of crashing"

# real parse_installed_version, exercised with fixture JSON (not a mock)
out="$(printf '[{"id":"ai-workflow@whatislove118","version":"abc123abc123"}]' | parse_installed_version)"
assert_contains "$out" "abc123abc123" "parse_installed_version extracts the version for a matching id"

out="$(printf '[{"id":"other@other-marketplace","version":"zzz"}]' | parse_installed_version)" && fail_unexpected=1 || fail_unexpected=0
[ "${fail_unexpected:-0}" = "0" ] && echo "PASS: parse_installed_version fails when id is absent" || { echo "FAIL: parse_installed_version fails when id is absent"; fail=1; }

out="$(printf '{"id":"ai-workflow@whatislove118","version":"abc"}' | parse_installed_version)" && fail_unexpected=1 || fail_unexpected=0
[ "${fail_unexpected:-0}" = "0" ] && echo "PASS: parse_installed_version rejects a non-list top level" || { echo "FAIL: parse_installed_version rejects a non-list top level"; fail=1; }

out="$(printf '[{"id":"ai-workflow@whatislove118","version":""}]' | parse_installed_version)" && fail_unexpected=1 || fail_unexpected=0
[ "${fail_unexpected:-0}" = "0" ] && echo "PASS: parse_installed_version rejects an empty version" || { echo "FAIL: parse_installed_version rejects an empty version"; fail=1; }

exit $fail
