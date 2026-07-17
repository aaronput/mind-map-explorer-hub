#!/usr/bin/env bash
# Refresh every mind-map explorer, then regenerate the hub manifest and push.
# Safe to run manually or from cron.
#
# Usage: ./sync_all.sh
#
# Each refresh.sh is independent — one map failing does NOT stop the others.
# The hub is only pushed if the manifest actually changed.

set -uo pipefail   # no -e: we want to continue past a failing refresh

# Cron runs with a stripped PATH. Re-add the locations our tools live in.
export PATH="/opt/homebrew/bin:/opt/anaconda3/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

MAPS=(
  "$HOME/Desktop/MindMapExplorer_NavnoorBawa"
  "$HOME/Desktop/MindMapExplorer_AdamTooze"
  "$HOME/Desktop/MindMapExplorer_Moontower"
)
# Knowledge bases: static HTML, no refresh.sh — updated only when their
# repos change. Their refreshed_at is still pulled from git in regen_manifest.py.
KB_ONLY=(
  "$HOME/Desktop/MindMapExplorer_TaxArb"
  "$HOME/Desktop/MindMapExplorer_QuantML"
)

HUB="$HOME/Desktop/MindMapsHub"

banner(){ printf '\n%s\n' "═════════════════════════════════════════════════"; printf '  %s\n' "$1"; printf '%s\n' "═════════════════════════════════════════════════"; }

banner "Mind Map Sync — $(date '+%Y-%m-%d %H:%M:%S')"

# 1. Refresh each mind map (independent — failures don't cascade)
declare -a FAILED=()
for MAP in "${MAPS[@]}"; do
  name="$(basename "$MAP")"
  printf '\n▶ %s\n──────────────────────────────────────────────────\n' "$name"
  if [[ ! -x "$MAP/refresh.sh" ]]; then
    echo "  ⚠ no executable refresh.sh — skipping"
    FAILED+=("$name (no refresh.sh)")
    continue
  fi
  if ( "$MAP/refresh.sh" ); then
    echo "  ✓ $name done"
  else
    rc=$?
    echo "  ✗ $name FAILED (exit $rc)"
    FAILED+=("$name (exit $rc)")
  fi
done

# 2. Regenerate hub manifest from each map's fresh data.json + git log
banner "Regenerating hub manifest"
python3 "$HUB/regen_manifest.py"

# 3. Push hub only if the manifest or inlined index actually changed
cd "$HUB"
git add manifest.json index.html
if git diff --cached --quiet; then
  echo ""
  echo "  hub: no manifest changes — nothing to push"
else
  git commit -m "sync: refresh manifest $(date +%Y-%m-%d)"
  git push
  echo "  hub: pushed → Vercel will redeploy in ~30s"
fi

# 4. Summary
banner "Summary"
if (( ${#FAILED[@]} == 0 )); then
  echo "  ✓ all mind maps refreshed cleanly"
else
  echo "  ✗ failures:"
  for f in "${FAILED[@]}"; do echo "    - $f"; done
  exit 1
fi
