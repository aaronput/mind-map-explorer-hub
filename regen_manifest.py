"""
Regenerate manifest.json (and the inlined copy in index.html) from each
mind-map's data.json + git log.

Preserves editorial fields (name, tagline, author, beat, accent, url,
source, repo). Only refreshes the volatile ones: post_count, concept_count,
refreshed_at (from `git log -1`), and top-level `updated`.
"""

import json, re, subprocess, time
from pathlib import Path

HUB       = Path(__file__).parent
MANIFEST  = HUB / "manifest.json"
INDEX     = HUB / "index.html"

# Map manifest entry name → local repo path (where data.json + git live)
LOCAL_PATHS = {
    "Chartbook":    Path.home() / "Desktop" / "MindMapExplorer_AdamTooze",
    "Navnoor Bawa": Path.home() / "Desktop" / "MindMapExplorer_NavnoorBawa",
}

def last_commit_date(repo_path):
    """Returns yyyy-mm-dd of last commit (i.e. last real data change)."""
    try:
        out = subprocess.check_output(
            ["git", "-C", str(repo_path), "log", "-1", "--format=%cs"],
            stderr=subprocess.DEVNULL, text=True,
        ).strip()
        return out or "—"
    except Exception:
        return "—"

def load_data_json(repo_path):
    p = repo_path / "data.json"
    if not p.exists():
        return None
    return json.loads(p.read_text())

manifest = json.loads(MANIFEST.read_text())
manifest["updated"] = time.strftime("%Y-%m-%d")

for entry in manifest["mindmaps"]:
    local = LOCAL_PATHS.get(entry["name"])
    if not local:
        print(f"  ⚠ no local path mapping for '{entry['name']}' — leaving stats untouched")
        continue
    data = load_data_json(local)
    if not data:
        print(f"  ⚠ no data.json at {local} — leaving stats untouched")
        continue
    entry["post_count"]    = data["publication"]["post_count"]
    entry["concept_count"] = len(data["concepts"])
    entry["refreshed_at"]  = last_commit_date(local)
    print(f"  ✓ {entry['name']}: {entry['post_count']} posts, {entry['concept_count']} concepts, refreshed {entry['refreshed_at']}")

# Write standalone manifest.json
new_manifest_text = json.dumps(manifest, indent=2, ensure_ascii=False)
MANIFEST.write_text(new_manifest_text + "\n")

# Re-inline into index.html
html = INDEX.read_text()
inlined = new_manifest_text.replace("</", "<\\/")
new_html, n = re.subn(
    r'(<script id="manifest"[^>]*>).*?(</script>)',
    lambda m: m.group(1) + inlined + m.group(2),
    html, count=1, flags=re.S,
)
if n != 1:
    raise SystemExit("ERROR: could not find <script id=\"manifest\"> block in index.html")
INDEX.write_text(new_html)
print(f"  ✓ index.html re-inlined ({len(new_html):,} chars)")
