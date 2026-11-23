#!/usr/bin/env python3
"""Builds Jupiter2011Incident.rbxlx (a Roblox place file) from src/, without needing Rojo.

Same layout as default.project.json:
  src/shared -> ReplicatedStorage.Shared
  src/server -> ServerScriptService.Server
  src/client -> StarterPlayer.StarterPlayerScripts.Client
  *.server.luau = Script, *.client.luau = LocalScript, *.luau = ModuleScript

Usage:  python3 tools/build_place.py
"""
import itertools
import pathlib
from xml.sax.saxutils import escape

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Jupiter2011Incident.rbxlx"
_ids = itertools.count(1)


def ref():
    return f"RBX{next(_ids):08X}"


def item(cls, name, children="", source=None, extra=""):
    props = f'<string name="Name">{escape(name)}</string>' + extra
    if source is not None:
        if "]]>" in source:
            raise SystemExit(f"{name}: source contains ']]>' which can't go in CDATA")
        props += f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{props}</Properties>{children}</Item>\n'


def script_item(path: pathlib.Path):
    name = path.name
    source = path.read_text(encoding="utf-8")
    if name.endswith(".server.luau"):
        return item("Script", name[: -len(".server.luau")], source=source)
    if name.endswith(".client.luau"):
        return item("LocalScript", name[: -len(".client.luau")], source=source)
    return item("ModuleScript", name[: -len(".luau")], source=source)


def folder(name, directory):
    kids = "".join(script_item(p) for p in sorted((ROOT / directory).glob("*.luau")))
    return item("Folder", name, kids)


xml = (
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
    # streaming off: the ship, Io and Jupiter must always be loaded on every client
    + item("Workspace", "Workspace", extra='<bool name="StreamingEnabled">false</bool>')
    # Future lighting (Enum.Technology.Future = 4): real shadows from every light. Scripts can't set this.
    + item("Lighting", "Lighting", extra='<token name="Technology">4</token>')
    + item("ReplicatedStorage", "ReplicatedStorage", folder("Shared", "src/shared"))
    + item("ServerScriptService", "ServerScriptService", folder("Server", "src/server"))
    + item("StarterPlayer", "StarterPlayer", item("StarterPlayerScripts", "StarterPlayerScripts", folder("Client", "src/client")))
    + "</roblox>\n"
)
OUT.write_text(xml, encoding="utf-8")
print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")
