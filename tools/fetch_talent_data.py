#!/usr/bin/env python3
"""
Fetches 1.18.1 talent data from talent-builder.dev and regenerates
Modules/CalculatorData.lua without any manual data-collection steps.

How it works:
  1. Fetches /collections/1.18.1 (and per-class pages) to discover tree IDs.
  2. Fetches each /tree/{id} page and extracts the TalentForm from the
     Next.js RSC flight data embedded in <script>self.__next_f.push([1,"..."])</script>.
  3. Generates Modules/CalculatorData.lua in the same format as
     generate_calculator_module.py.

Usage:
  python3 tools/fetch_talent_data.py
"""

import re
import json
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:
    print("ERROR: 'requests' library not found. Run: pip3 install requests")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

COLLECTION = sys.argv[1] if len(sys.argv) > 1 else "1.18.1"
BASE_URL = "https://www.talent-builder.dev"

ROOT = Path(__file__).resolve().parents[1]
CLASS_DATA_DIR = ROOT / "ClassData"
BACKUP_LUA = ROOT / "tools" / "CalculatorData.lua"

# classMask from talent-builder src/utils/index.ts (keys are numeric class IDs)
CLASS_IDS_ORDERED = [1, 2, 4, 8, 16, 64, 128, 256, 1024]
CLASS_NAMES = {
    1: "Warrior",
    2: "Paladin",
    4: "Hunter",
    8: "Rogue",
    16: "Priest",
    64: "Shaman",
    128: "Mage",
    256: "Warlock",
    1024: "Druid",
}
# Lowercase slugs used in URL paths
CLASS_SLUGS = {
    1: "warrior",
    2: "paladin",
    4: "hunter",
    8: "rogue",
    16: "priest",
    64: "shaman",
    128: "mage",
    256: "warlock",
    1024: "druid",
}

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Cache-Control": "no-cache",
}

REQUEST_DELAY = 1.0  # seconds between requests, to be polite

# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

_session = None


def get_session():
    global _session
    if _session is None:
        _session = requests.Session()
        _session.headers.update(HEADERS)
    return _session


def fetch_html(url: str) -> str:
    print(f"  GET {url} ... ", end="", flush=True)
    resp = get_session().get(url, timeout=30, allow_redirects=True)
    resp.raise_for_status()
    print(f"{resp.status_code} ({len(resp.text):,} chars)")
    time.sleep(REQUEST_DELAY)
    return resp.text


# ---------------------------------------------------------------------------
# RSC flight data extraction
# ---------------------------------------------------------------------------

def extract_rsc_lines(html: str) -> list:
    """
    Extract RSC flight text lines from all
        self.__next_f.push([1, "..."])
    script tags embedded in a Next.js 15 HTML page.

    The string argument is a JSON-encoded string, so `\"` -> `"` and
    `\\n` -> newline, etc.

    IMPORTANT: Multiple consecutive push([1, "..."]) calls may split a
    single RSC line across chunks (Next.js uses ~4k byte chunks).  We
    concatenate ALL decoded text FIRST, then split on newlines.
    """
    pattern = re.compile(
        r'self\.__next_f\.push\(\[1,"((?:[^"\\]|\\.)*)"\]\)',
        re.DOTALL,
    )
    all_text = ""
    for m in pattern.finditer(html):
        # Wrap in quotes so json.loads decodes all JS string escapes
        raw_json_str = '"' + m.group(1) + '"'
        try:
            all_text += json.loads(raw_json_str)
        except Exception:
            pass
    return all_text.split("\n")


def parse_rsc_chunks(lines: list) -> dict:
    """
    Parse RSC flight lines into {chunk_id: value}.

    Each line has the format:  <hex_id>:<content>
    Content that is valid JSON is stored as the decoded Python object;
    everything else (module refs "I[...]", text chunks "T...", etc.)
    is stored as the raw string so we can ignore them without errors.
    """
    chunks = {}
    for line in lines:
        line = line.strip()
        if not line:
            continue
        colon = line.find(":")
        if colon < 0:
            continue
        chunk_id = line[:colon]
        rest = line[colon + 1 :]
        if not rest:
            continue
        try:
            chunks[chunk_id] = json.loads(rest)
        except Exception:
            chunks[chunk_id] = rest
    return chunks


def _is_talent_form(value) -> bool:
    """Return True if value looks like a TalentForm dict."""
    if not isinstance(value, dict):
        return False
    class_id = value.get("class")
    if not isinstance(class_id, int) or class_id not in CLASS_NAMES:
        return False
    return isinstance(value.get("talents"), dict)


def find_talent_forms(chunks: dict) -> list:
    """
    Return all TalentForm dicts found in the parsed RSC chunks.

    Two locations to check:
      1. Direct chunk value: {class, talents, ...}
      2. React element: ["$", "$L...", key, {"defaultValues": {class, talents, ...}}]
         This is the pattern used by the TalentBuilder 'use client' component.
    """
    forms = []
    for value in chunks.values():
        # Case 1: chunk IS the TalentForm dict
        if _is_talent_form(value):
            forms.append(value)
            continue

        # Case 2: chunk is a React element array carrying defaultValues prop
        if not isinstance(value, list) or len(value) < 4:
            continue
        if value[0] != "$":
            continue
        props = value[3]
        if not isinstance(props, dict):
            continue
        dv = props.get("defaultValues")
        if _is_talent_form(dv):
            forms.append(dv)

    return forms


# ---------------------------------------------------------------------------
# Tree ID discovery
# ---------------------------------------------------------------------------

def extract_tree_ids(html: str) -> list:
    """Extract unique /tree/{id} IDs from page HTML (from href links)."""
    ids = re.findall(r'/tree/([A-Za-z0-9_-]{10})', html)
    return list(dict.fromkeys(ids))  # deduplicate, preserve order


def discover_tree_ids(collection: str) -> list:
    """
    Try to collect all tree IDs for the collection.
    Strategy:
      1. Fetch the all-classes collection overview page.
      2. If we don't get 27 IDs (9 classes × 3 trees), also fetch each
         per-class page: /collections/{collection}/{classslug}.
    """
    print(f"\n--- Discovering tree IDs for collection {collection!r} ---")
    all_ids = []

    # Step 1: overview page
    try:
        html = fetch_html(f"{BASE_URL}/collections/{collection}")
        ids = extract_tree_ids(html)
        print(f"  Found {len(ids)} tree IDs on overview page")
        all_ids.extend(ids)
    except Exception as e:
        print(f"  WARNING: overview page failed: {e}")

    # Deduplicate what we have so far
    seen = set(all_ids)
    unique_ids = list(dict.fromkeys(all_ids))

    # Step 2: per-class pages if we didn't find all 27 trees
    if len(unique_ids) < 27:
        print(f"  Only {len(unique_ids)}/27 IDs found; fetching per-class pages...")
        for class_id, slug in CLASS_SLUGS.items():
            url = f"{BASE_URL}/collections/{collection}/{slug}"
            try:
                html = fetch_html(url)
                ids = extract_tree_ids(html)
                new_ids = [i for i in ids if i not in seen]
                if new_ids:
                    print(f"    {CLASS_NAMES[class_id]}: +{len(new_ids)} new IDs")
                    unique_ids.extend(new_ids)
                    seen.update(new_ids)
            except Exception as e:
                print(f"    WARNING: {CLASS_NAMES[class_id]} page failed: {e}")

    print(f"  Total tree IDs discovered: {len(unique_ids)}")
    return unique_ids


# ---------------------------------------------------------------------------
# Per-tree data extraction
# ---------------------------------------------------------------------------

def get_talent_form(tree_id: str) -> dict | None:
    """
    Fetch /tree/{id} and return the TalentForm dict if found in the RSC payload.
    Returns None if not found.
    """
    url = f"{BASE_URL}/tree/{tree_id}"
    try:
        html = fetch_html(url)
    except Exception as e:
        print(f"    ERROR fetching {url}: {e}")
        return None

    lines = extract_rsc_lines(html)
    if not lines:
        # Fallback: try direct JSON search in full HTML
        # (handles edge-cases like pre-rendered static HTML without push() calls)
        lines = _rsc_lines_from_inline_script(html)

    chunks = parse_rsc_chunks(lines)
    forms = find_talent_forms(chunks)

    if not forms:
        print(f"    WARNING: no TalentForm found for tree {tree_id}")
        return None

    # Pick the form with the most talents (skip any partial/empty ones)
    return max(forms, key=lambda f: len(f.get("talents", {})))


def _rsc_lines_from_inline_script(html: str) -> list:
    """
    Fallback: look for __NEXT_FLIGHT__ or similar inline JSON payloads.
    Also handles self.__next_f.push([0, [1, "..."]]) batch form.
    """
    lines = []
    # Batch form: push([0, [1, "..."]])
    pattern = re.compile(
        r'self\.__next_f\.push\(\[0,\s*\[1,"((?:[^"\\]|\\.)*)"\]\]\)',
        re.DOTALL,
    )
    for m in pattern.finditer(html):
        raw_json_str = '"' + m.group(1) + '"'
        try:
            text = json.loads(raw_json_str)
            lines.extend(text.split("\n"))
        except Exception:
            pass
    return lines


# ---------------------------------------------------------------------------
# Payload construction
# ---------------------------------------------------------------------------

def compact_talents(talent_form: dict) -> list:
    """
    Convert a TalentForm.talents dict (Record<string, Talent>) into a sorted
    list of compact dicts:
        { name, row, column, icon, desc, ranks: [spellId, ...], req? }
    row and column are 1-indexed and computed from the position key:
        position = row * 4 + col  (0-indexed both)
        -> row_1idx = position // 4 + 1
        -> col_1idx = position % 4 + 1
    Talents beyond the tree's `rows` count are discarded.
    `req` is the 1-based sorted index of the prerequisite talent (if any).
    """
    talents_map = talent_form.get("talents", {})
    rows = talent_form.get("rows", 7)
    entries = []

    for pos_key, talent in talents_map.items():
        if not talent or not talent.get("name"):
            continue
        try:
            pos = int(pos_key)
        except ValueError:
            continue

        row_0 = pos // 4
        col_0 = pos % 4
        if row_0 >= rows:
            continue

        spell_str = talent.get("spellIds") or ""
        spell_ids = []
        for part in spell_str.split(","):
            part = part.strip()
            if part.isdigit():
                spell_ids.append(int(part))
        # Fall back to sequential placeholders when spell IDs aren't in the
        # calculator yet (new patch talents). This preserves the correct rank
        # count so tooltips show "Rank 0/N" instead of "Rank 0/0".
        if not spell_ids:
            rank_count = talent.get("ranks") or 0
            if isinstance(rank_count, int) and rank_count > 0:
                spell_ids = list(range(1, rank_count + 1))

        raw_icon = talent.get("icon") or ""
        icon = ("Interface\\Icons\\" + raw_icon) if raw_icon and not raw_icon.startswith("Interface") else raw_icon

        entries.append(
            {
                "name": talent["name"],
                "row": row_0 + 1,
                "column": col_0 + 1,
                "icon": icon,
                "desc": talent.get("description") or "",
                "ranks": spell_ids,
                "_pos": pos,
                "_req_raw": talent.get("requires"),
            }
        )

    entries.sort(key=lambda e: (e["row"], e["column"]))

    # Build position -> 1-based sorted index so requires can be resolved to req
    pos_to_idx = {e["_pos"]: i + 1 for i, e in enumerate(entries)}

    for entry in entries:
        req_raw = entry.pop("_req_raw", None)
        entry.pop("_pos", None)
        if req_raw is not None:
            try:
                req_idx = pos_to_idx.get(int(req_raw))
                if req_idx:
                    entry["req"] = req_idx
            except (ValueError, TypeError):
                pass

    return entries


def build_payload(tree_ids: list) -> dict:
    """
    Fetch every tree, organise by class → [tree0, tree1, tree2], return payload.
    """
    print(f"\n--- Fetching talent data for {len(tree_ids)} trees ---")

    # class_id -> {index: compact_talents_list}
    class_trees: dict = {}

    for tree_id in tree_ids:
        form = get_talent_form(tree_id)
        if form is None:
            continue

        class_id = form.get("class")
        idx = form.get("index", 0)
        name = form.get("name", "?")
        n_talents = len(form.get("talents", {}))
        print(
            f"    -> {CLASS_NAMES.get(class_id, f'unknown({class_id})')} "
            f"tree {idx}: '{name}' ({n_talents} talent slots)"
        )

        if class_id not in class_trees:
            class_trees[class_id] = {}
        class_trees[class_id][idx] = compact_talents(form)

    # Assemble payload in the same class order as the old generator
    print(f"\n--- Building payload ---")
    payload = {}
    for class_id in CLASS_IDS_ORDERED:
        class_name = CLASS_NAMES[class_id]
        upper = class_name.upper()

        if class_id not in class_trees:
            print(f"  WARNING: no data found for {class_name}!")
            payload[upper] = [[], [], []]
            continue

        tree_dict = class_trees[class_id]
        trees = [tree_dict.get(i, []) for i in range(3)]
        counts = [len(t) for t in trees]
        total = sum(counts)
        print(f"  {upper}: trees {counts} = {total} talents total")

        for i, t in enumerate(trees):
            if not t:
                print(f"    WARNING: tree {i} is empty for {class_name}")

        payload[upper] = trees

    return payload


# ---------------------------------------------------------------------------
# Lua generation (identical to generate_calculator_module.py)
# ---------------------------------------------------------------------------

def lua_quote(text: str) -> str:
    text = text.replace("\\", "\\\\")
    text = text.replace('"', '\\"')
    text = text.replace("\r", "\\r")
    text = text.replace("\n", "\\n")
    return '"' + text + '"'


def render_table(value, indent: int = 0) -> str:
    pad = "  " * indent
    inner = "  " * (indent + 1)
    if isinstance(value, dict):
        lines = ["{"]
        for key, item in value.items():
            lines.append(
                f"{inner}[{lua_quote(str(key))}] = {render_table(item, indent + 1)},"
            )
        lines.append(f"{pad}" + "}")
        return "\n".join(lines)
    if isinstance(value, list):
        lines = ["{"]
        for item in value:
            lines.append(f"{inner}{render_table(item, indent + 1)},")
        lines.append(f"{pad}" + "}")
        return "\n".join(lines)
    if isinstance(value, str):
        return lua_quote(value)
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return str(value).lower()
    return str(value)


CLASS_RUNTIME = """\
  _G.TalentedTooltipData = _G.TalentedTooltipData or {}
  _G.TalentedTooltipData[class] = spelldata
  _G.TalentedDataOverride = _G.TalentedDataOverride or {spelldata = {}, tabdata = {}}
  _G.TalentedDataOverride.spelldata = _G.TalentedDataOverride.spelldata or {}
  _G.TalentedDataOverride.spelldata[class] = spelldata"""


def write_class_data(payload: dict) -> None:
    CLASS_DATA_DIR.mkdir(exist_ok=True)
    for class_name, tabs in payload.items():
        out_path = CLASS_DATA_DIR / f"{class_name}.lua"
        lua_lines = [
            "-- Generated by tools/fetch_talent_data.py. Do not edit by hand.",
            "do",
            f"  local class = {lua_quote(class_name)}",
            "  local spelldata = " + render_table(tabs, 1),
            "",
            CLASS_RUNTIME,
            "end",
        ]
        out_path.write_text("\n".join(lua_lines) + "\n")
        print(f"  Written: {out_path.name}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    print("=== Talented Turtle: fetch 1.18.1 talent data ===\n")

    # 1. Discover tree IDs
    tree_ids = discover_tree_ids(COLLECTION)
    if not tree_ids:
        print("ERROR: Could not discover any tree IDs. Check network connectivity.")
        sys.exit(1)

    # 2. Fetch every tree and build payload
    payload = build_payload(tree_ids)

    # 3. Write ClassData files
    print(f"\n--- Writing ClassData/*.lua ---")
    write_class_data(payload)

    print("\n=== Done! ===")
    print(f"Reload the addon in-game to use the updated talent data.\n")


if __name__ == "__main__":
    main()
