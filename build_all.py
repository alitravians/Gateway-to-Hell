#!/usr/bin/env python3
"""
Build the Gateway to Hell place file (GatewayToHell.rbxlx) from src/.

Unlike a "baked" place that is edited in-place, this project GENERATES the
whole .rbxlx fresh on every build by assembling a template and embedding each
Luau source under the correct Roblox service. This keeps src/ as the single
source of truth (no fragile marker matching) and is friendlier to git diffs.

Manifest = list of (source_file, roblox_class, script_name, service).
  roblox_class : "Script" | "LocalScript" | "ModuleScript"
  service      : "ServerScriptService" | "StarterPlayerScripts"
                 | "StarterGui" | "ReplicatedStorage"

Output: GatewayToHell.rbxlx (well-formed XML, ready for publish.py).
"""
import os
import sys
import html

OUT = "GatewayToHell.rbxlx"
SRC_DIR = "src"

# (source file, class, instance name, service)
MANIFEST = [
    # --- Server ---
    ("src/LobbyBuilder.server.lua",       "Script",      "LobbyBuilder",       "ServerScriptService"),
    ("src/LeaderboardService.server.lua", "Script",      "LeaderboardService", "ServerScriptService"),
    ("src/AchievementsService.server.lua","Script",      "AchievementsService","ServerScriptService"),
    ("src/MatchmakingService.server.lua", "Script",      "MatchmakingService", "ServerScriptService"),
    ("src/RoundService.server.lua",       "Script",      "RoundService",       "ServerScriptService"),
    ("src/MonsterService.server.lua",     "Script",      "MonsterService",     "ServerScriptService"),
    ("src/StoryMapBuilder.server.lua",    "Script",      "StoryMapBuilder",    "ServerScriptService"),

    # --- Shared ---
    ("src/GameConfig.module.lua",         "ModuleScript", "GameConfig",        "ReplicatedStorage"),
    ("src/StoryPuzzles.module.lua",       "ModuleScript", "StoryPuzzles",      "ReplicatedStorage"),

    # --- Client ---
    ("src/LoadingScreen.client.lua",      "LocalScript", "LoadingScreen",      "StarterGui"),
    ("src/MainMenu.client.lua",           "LocalScript", "MainMenu",           "StarterGui"),
    ("src/RoundHUD.client.lua",           "LocalScript", "RoundHUD",           "StarterGui"),
    ("src/LobbyAmbience.client.lua",      "LocalScript", "LobbyAmbience",      "StarterPlayerScripts"),
    ("src/MatchmakingClient.client.lua",  "LocalScript", "MatchmakingClient",  "StarterPlayerScripts"),
    ("src/PlayerEffects.client.lua",      "LocalScript", "PlayerEffects",      "StarterPlayerScripts"),
    ("src/AchievementsToast.client.lua",  "LocalScript", "AchievementsToast",  "StarterPlayerScripts"),
    ("src/VoiceChatScaffold.client.lua",  "LocalScript", "VoiceChatScaffold",  "StarterPlayerScripts"),
]

REF_ATTR = 'referent="RBX{idx:08d}"'


def script_block(cls, name, source, idx):
    if "]]>" in source:
        sys.exit(f"ERROR: {name} source contains ]]> which breaks CDATA")
    ref = f"RBX{idx:08d}"
    return (
        f'<Item class="{cls}" referent="{ref}">\n'
        f'  <Properties>\n'
        f'    <string name="Name">{html.escape(name)}</string>\n'
        f'    <ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>\n'
        f'  </Properties>\n'
        f'</Item>\n'
    )


def service_block(class_name, ref, children):
    inner = "".join(children)
    return (
        f'<Item class="{class_name}" referent="{ref}">\n'
        f'  <Properties>\n'
        f'    <string name="Name">{class_name}</string>\n'
        f'  </Properties>\n'
        f'{inner}'
        f'</Item>\n'
    )


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    # group scripts by service
    buckets = {}
    idx = 100
    for path, cls, name, service in MANIFEST:
        if not os.path.exists(path):
            sys.exit(f"ERROR: missing source file {path}")
        src = read(path)
        buckets.setdefault(service, []).append(script_block(cls, name, src, idx))
        idx += 1

    # StarterPlayerScripts lives inside StarterPlayer
    starter_player_children = ""
    if "StarterPlayerScripts" in buckets:
        sps = service_block("StarterPlayerScripts", "RBX00000010", buckets["StarterPlayerScripts"])
        starter_player_children = sps

    services = []
    services.append(service_block("ServerScriptService", "RBX00000001", buckets.get("ServerScriptService", [])))
    services.append(service_block("ReplicatedStorage", "RBX00000002", buckets.get("ReplicatedStorage", [])))
    services.append(service_block("StarterGui", "RBX00000003", buckets.get("StarterGui", [])))
    services.append(
        f'<Item class="StarterPlayer" referent="RBX00000004">\n'
        f'  <Properties>\n'
        f'    <string name="Name">StarterPlayer</string>\n'
        f'  </Properties>\n'
        f'{starter_player_children}'
        f'</Item>\n'
    )
    # Workspace (spawn baseplate so the place is playable before Blender meshes land)
    services.append(read("templates/workspace.xml"))
    services.append(read("templates/lighting.xml"))

    body = "".join(services)
    doc = f'<roblox version="4">\n{body}</roblox>\n'

    with open(OUT, "w", encoding="utf-8") as f:
        f.write(doc)
    print(f"Build complete: {OUT} ({len(doc):,} bytes, {len(MANIFEST)} scripts)")


if __name__ == "__main__":
    main()
