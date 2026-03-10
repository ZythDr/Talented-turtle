#!/usr/bin/env python3
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools" / "TalentCalc_Data.txt"
TARGET = ROOT / "Modules" / "CalculatorData.lua"


def load_sections(text):
    sections = {}
    current = None
    lines = []
    for raw_line in text.splitlines():
        line = raw_line.rstrip("\n")
        if line.endswith(":") and line[:-1] and line[:-1].strip() == line[:-1]:
            if current and lines:
                sections[current] = lines[:]
            current = line[:-1].strip()
            lines = []
        elif current:
            lines.append(line)
    if current and lines:
        sections[current] = lines[:]
    return sections


def parse_payload(lines):
    marker = '["$","$L4",null,'
    payload_line = None
    for line in lines:
        if marker in line:
            payload_line = line
            break
    if payload_line is None:
        raise ValueError("Missing calculator payload line")
    payload = payload_line.split(marker, 1)[1]
    if not payload.endswith("]"):
        raise ValueError("Unexpected payload suffix")
    return json.loads(payload[:-1])


def compact_tree(tree):
    talents = []
    for idx, talent in enumerate(tree.get("talents", [])):
        name = talent.get("name") or ""
        ranks = talent.get("ranks")
        if not name or not ranks:
            continue
        spell_ids = []
        for part in (talent.get("spellIds") or "").split(","):
            part = part.strip()
            if not part:
                continue
            spell_ids.append(int(part))
        talents.append(
            {
                "name": name,
                "row": idx // 4 + 1,
                "column": idx % 4 + 1,
                "desc": talent.get("description") or "",
                "ranks": spell_ids,
            }
        )
    return talents


def lua_quote(text):
    text = text.replace("\\", "\\\\")
    text = text.replace('"', '\\"')
    text = text.replace("\r", "\\r")
    text = text.replace("\n", "\\n")
    return '"' + text + '"'


def render_table(value, indent=0):
    pad = "  " * indent
    inner = "  " * (indent + 1)
    if isinstance(value, dict):
        lines = ["{"]
        for key, item in value.items():
            lines.append(f"{inner}[{lua_quote(str(key))}] = {render_table(item, indent + 1)},")
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
    return str(value)


def build_payload():
    sections = load_sections(SOURCE.read_text())
    payload = {}
    for class_name, lines in sections.items():
        data = parse_payload(lines)
        trees = data.get("trees") or []
        payload[class_name.upper()] = [compact_tree(tree) for tree in trees]
    return payload


def main():
    payload = build_payload()
    lua = []
    lua.append("-- Generated from tools/TalentCalc_Data.txt. Do not edit by hand.")
    lua.append("do")
    lua.append("  local payload = " + render_table(payload, 1))
    lua.append("")
    lua.append("  local function make_key(name, row, column)")
    lua.append('    return tostring(name or "") .. "\\031" .. tostring(row or 0) .. "\\031" .. tostring(column or 0)')
    lua.append("  end")
    lua.append("")
    lua.append("  _G.TalentedTooltipData = _G.TalentedTooltipData or {}")
    lua.append("  local tooltipData = _G.TalentedTooltipData")
    lua.append("  _G.TalentedDataOverride = _G.TalentedDataOverride or {spelldata = {}, tabdata = {}}")
    lua.append("  local overrideRoot = _G.TalentedDataOverride")
    lua.append("  overrideRoot.spelldata = overrideRoot.spelldata or {}")
    lua.append("")
    lua.append("  for class, tabs in pairs(payload) do")
    lua.append("    tooltipData[class] = tooltipData[class] or {}")
    lua.append("    for tab = 1, table.getn(tabs) do")
    lua.append("      local srcTalents = tabs[tab]")
    lua.append("      local compact = {}")
    lua.append("      local byKey = {}")
    lua.append("      for i = 1, table.getn(srcTalents) do")
    lua.append("        local src = srcTalents[i]")
    lua.append("        local entry = {")
    lua.append("          name = src.name,")
    lua.append("          row = src.row,")
    lua.append("          column = src.column,")
    lua.append("          desc = src.desc,")
    lua.append("          ranks = src.ranks,")
    lua.append("        }")
    lua.append("        compact[i] = entry")
    lua.append("        byKey[make_key(src.name, src.row, src.column)] = entry")
    lua.append("      end")
    lua.append("      tooltipData[class][tab] = compact")
    lua.append("      local overrideTabs = overrideRoot.spelldata[class]")
    lua.append("      local overrideTalents = overrideTabs and overrideTabs[tab]")
    lua.append("      if type(overrideTalents) == \"table\" then")
    lua.append("        for i = 1, table.getn(overrideTalents) do")
    lua.append("          local dst = overrideTalents[i]")
    lua.append("          local src = compact[i]")
    lua.append("          if type(dst) == \"table\" then")
    lua.append("            if type(src) ~= \"table\" or dst.name ~= src.name or dst.row ~= src.row or dst.column ~= src.column then")
    lua.append("              src = byKey[make_key(dst.name, dst.row, dst.column)]")
    lua.append("            end")
    lua.append("            if type(src) == \"table\" then")
    lua.append("              dst.desc = src.desc")
    lua.append("              if type(dst.ranks) == \"table\" and type(src.ranks) == \"table\" and table.getn(dst.ranks) == table.getn(src.ranks) then")
    lua.append("                dst.ranks = src.ranks")
    lua.append("              end")
    lua.append("              compact[i] = {")
    lua.append("                name = dst.name or src.name,")
    lua.append("                row = dst.row or src.row,")
    lua.append("                column = dst.column or src.column,")
    lua.append("                desc = src.desc,")
    lua.append("                ranks = src.ranks,")
    lua.append("              }")
    lua.append("            end")
    lua.append("          end")
    lua.append("        end")
    lua.append("        tooltipData[class][tab] = compact")
    lua.append("      end")
    lua.append("    end")
    lua.append("  end")
    lua.append("end")
    TARGET.write_text("\n".join(lua) + "\n")


if __name__ == "__main__":
    main()
