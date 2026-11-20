"""Build release/BahayBuhay.rbxlx (a Roblox Studio place file) from src/.

Mirrors default.project.json: shared -> ReplicatedStorage.Shared,
server -> ServerScriptService.Server, client -> StarterPlayer.StarterPlayerScripts.Client.
Usage: python3 tools/build_place.py
"""
import itertools
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ref = itertools.count(1)


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, children="", source=None):
    props = f'<string name="Name">{name}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    return f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties>{props}</Properties>{children}</Item>\n'


def script_item(path):
    base = os.path.basename(path)
    with open(path, encoding="utf-8") as f:
        src = f.read()
    for suffix, cls in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if base.endswith(suffix):
            return item(cls, base[: -len(suffix)], source=src)
    return ""


def folder(path, name, cls="Folder"):
    children = ""
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            children += folder(full, entry)
        elif entry.endswith(".luau"):
            children += script_item(full)
    return item(cls, name, children)


def main():
    src = os.path.join(ROOT, "src")
    body = item("ReplicatedStorage", "ReplicatedStorage", folder(os.path.join(src, "shared"), "Shared"))
    body += item("ServerScriptService", "ServerScriptService", folder(os.path.join(src, "server"), "Server"))
    body += item(
        "StarterPlayer",
        "StarterPlayer",
        item("StarterPlayerScripts", "StarterPlayerScripts", folder(os.path.join(src, "client"), "Client")),
    )
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        + body
        + "</roblox>\n"
    )
    out_dir = os.path.join(ROOT, "release")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "BahayBuhay.rbxlx")
    with open(out, "w", encoding="utf-8") as f:
        f.write(xml)
    print("Wrote", out)


if __name__ == "__main__":
    sys.exit(main())
