#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="ai-workflow@whatislove118"
REPO_URL="https://github.com/Whatislove118/AI-Workflow.git"

# ponytail: 12-char SHA prefix mirrors what `claude plugin list --json`
# reports as `version` when plugin.json has no version field. If this repo
# ever adopts semver, swap this whole comparison for the version field.

# Parses `claude plugin list --json` output from stdin, isolated so tests can
# feed it fixture JSON without invoking the real `claude` binary.
parse_installed_version() {
  python3 -c '
import json, sys
try:
    plugins = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not isinstance(plugins, list):
    sys.exit(1)
for p in plugins:
    if isinstance(p, dict) and p.get("id") == "'"$PLUGIN_ID"'":
        version = p.get("version") or ""
        if not version:
            sys.exit(1)
        print(version)
        sys.exit(0)
sys.exit(1)
'
}

installed_version() {
  command -v python3 >/dev/null 2>&1 || return 1
  claude plugin list --json 2>/dev/null | parse_installed_version
}

remote_version() {
  git ls-remote "$REPO_URL" refs/heads/master 2>/dev/null | cut -f1 | cut -c1-12
}

emit_check_failed() {
  printf '{"systemMessage": "⚠️ ai-workflow: не удалось проверить обновления плагина (нет сети или git недоступен)."}\n'
}

emit_update_available() {
  printf '{"systemMessage": "🔔 ai-workflow: доступно обновление плагина (%s → %s). Обновить: claude plugin update %s"}\n' \
    "$1" "$2" "$PLUGIN_ID"
}

main() {
  local installed remote
  installed="$(installed_version)" || { emit_check_failed; return 0; }
  remote="$(remote_version)" || remote=""
  [ -n "$remote" ] || { emit_check_failed; return 0; }
  [ "$installed" = "$remote" ] || emit_update_available "$installed" "$remote"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
