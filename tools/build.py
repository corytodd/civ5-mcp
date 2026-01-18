#!/usr/bin/env python3
"""
Civ5 Mod Build Script
Reads mod_config.json, calculates MD5s, generates .modinfo, and bundles to dist/
"""

import json
import hashlib
import io
import shutil
from pathlib import Path
from xml.etree import ElementTree as ET
from xml.dom import minidom


def find_rockspec(start_path):
    """Find the first .rockspec file in the given directory."""
    p = Path(start_path)
    for file in p.iterdir():
        if file.suffix == ".rockspec":
            return file
    return None


def format_version_from_rockspec(rockspec_path):
    """Extract version string from a .rockspec file."""
    version = "0"
    with open(rockspec_path, "r", encoding="utf-8") as f:
        for line in f:
            # Convert Lua version format to Civ version format
            # Chop off the revision and concat the version into one number
            line = line.replace('"', "").strip()
            if line.startswith("version"):
                lua_version = line.split("=")[-1].strip()
                version = "".join(lua_version.split("-")[0].split("."))
                break
    return version


def calculate_md5(file_path):
    """Calculate MD5 hash of a file."""
    md5_hash = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            md5_hash.update(chunk)
    return md5_hash.hexdigest()


def bool_to_xml(value):
    """Convert Python bool to XML 0/1."""
    return "1" if value else "0"


def generate_constants_file(config, output_path):
    """Generate a Lua constants file with the mod ID."""
    content = io.StringIO()
    content.write("-- This file is auto-generated during the build process.\n")
    content.write(f'\nCIV5MCP_MOD_ID = "{config["mod"]["id"]}";\n')
    content.write(f'\nCIV5MCP_MOD_NAME = "{config["properties"]["name"]}";\n')

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(content.getvalue())


def generate_modinfo(config, file_md5s):
    """Generate .modinfo XML from config and MD5 hashes."""
    mod = ET.Element("Mod")
    mod.set("id", config["mod"]["id"])
    mod.set("version", config["mod"]["version"])

    props = ET.SubElement(mod, "Properties")
    p = config["properties"]

    ET.SubElement(props, "Name").text = p["name"]
    ET.SubElement(props, "Teaser").text = p["teaser"]
    ET.SubElement(props, "Description").text = p["description"]
    ET.SubElement(props, "Authors").text = p["authors"]
    ET.SubElement(props, "HideSetupGame").text = bool_to_xml(p["hide_setup_game"])
    ET.SubElement(props, "AffectsSavedGames").text = bool_to_xml(
        p["affects_saved_games"]
    )
    ET.SubElement(props, "MinCompatibleSaveVersion").text = str(
        p["min_compatible_save_version"]
    )
    ET.SubElement(props, "SupportsSinglePlayer").text = bool_to_xml(
        p["supports_single_player"]
    )
    ET.SubElement(props, "SupportsMultiplayer").text = bool_to_xml(
        p["supports_multiplayer"]
    )
    ET.SubElement(props, "SupportsHotSeat").text = bool_to_xml(p["supports_hotseat"])
    ET.SubElement(props, "SupportsMac").text = bool_to_xml(p["supports_mac"])
    ET.SubElement(props, "ReloadAudioSystem").text = bool_to_xml(
        p["reload_audio_system"]
    )
    ET.SubElement(props, "ReloadLandmarkSystem").text = bool_to_xml(
        p["reload_landmark_system"]
    )
    ET.SubElement(props, "ReloadStrategicViewSystem").text = bool_to_xml(
        p["reload_strategic_view_system"]
    )
    ET.SubElement(props, "ReloadUnitSystem").text = bool_to_xml(p["reload_unit_system"])

    ET.SubElement(mod, "Dependencies")
    ET.SubElement(mod, "References")
    ET.SubElement(mod, "Blocks")

    files = ET.SubElement(mod, "Files")
    for file_info in config["files"]:
        file_elem = ET.SubElement(files, "File")
        file_elem.set("md5", file_md5s.get(file_info["path"], ""))
        file_elem.set("import", bool_to_xml(file_info["import"]))
        file_elem.text = file_info["path"]

    ET.SubElement(mod, "Actions")

    entrypoints = ET.SubElement(mod, "EntryPoints")
    for ep in config["entrypoints"]:
        entry = ET.SubElement(entrypoints, "EntryPoint")
        entry.set("type", ep["type"])
        entry.set("file", ep["file"])
        ET.SubElement(entry, "Name").text = ep["name"]
        ET.SubElement(entry, "Description").text = ep["description"]

    return mod


def generate_game_rules(config, game_rules_path):
    """Generate Civ5MCP_GameRules.lua from config."""
    files_to_include = []
    for rule in config.get("game_rules", []):
        if not rule.get("file"):
            raise Exception("Game rules entry missing 'file' field")
        file_path = Path("bridge/src") / rule["file"]
        if not file_path.exists():
            raise FileNotFoundError(f"Game rules file {file_path} not found")
        files_to_include.append(file_path)

    with open(Path(game_rules_path), "w", encoding="utf-8") as f:
        f.write("-- This file is auto-generated during the build process.\n")
        f.write("CIV5MCP_MOD_GAME_RULES = [[\n")
        for file_path in files_to_include:
            with open(file_path, "r", encoding="utf-8") as rule_file:
                for line in rule_file:
                    line = line.strip()
                    if not line or line.startswith("--"):
                        continue
                    f.write(line)
                    f.write("\n")
        f.write("]]\n")


def prettify_xml(elem):
    """Return a pretty-printed XML string."""
    rough_string = ET.tostring(elem, encoding="utf-8")
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ", encoding="utf-8").decode("utf-8")


def main():
    # Load config
    config_path = Path("bridge/mod_config.json")
    if not config_path.exists():
        print("Error: mod_config.json not found")
        return

    with open(config_path, "r") as f:
        config = json.load(f)

    rockspec_path = find_rockspec("bridge")
    if not rockspec_path:
        raise FileNotFoundError("No .rockspec file found in 'bridge' directory")

    version = format_version_from_rockspec(rockspec_path)
    config["mod"]["version"] = version

    src_dir = Path(config["build"]["src_dir"])
    dist_dir = Path(config["build"]["dist_dir"])
    mod_name = config["build"]["mod_folder_name"]
    mod_version = config["mod"]["version"]
    mod_dist_dir = dist_dir / f"{mod_name} (v {mod_version})"

    if mod_dist_dir.exists():
        shutil.rmtree(mod_dist_dir)
    mod_dist_dir.mkdir(parents=True)

    print(f"Building {mod_name}...")

    constants_path = src_dir / "Civ5MCP_Constants.lua"
    generate_constants_file(config, constants_path)

    game_rules_path = src_dir / "Civ5MCP_GameRules.lua"
    generate_game_rules(config, game_rules_path)

    file_md5s = {}
    for file_info in config["files"]:
        src_file = src_dir / file_info["path"]
        if not src_file.exists():
            raise FileNotFoundError(f"{src_file} not found")

        md5 = calculate_md5(src_file)
        file_md5s[file_info["path"]] = md5
        print(f"  {file_info['path']}: {md5}")

        dest_file = mod_dist_dir / file_info["path"]
        dest_file.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_file, dest_file)

    modinfo_xml = generate_modinfo(config, file_md5s)
    modinfo_content = prettify_xml(modinfo_xml)

    modinfo_content = '<?xml version="1.0" encoding="utf-8"?>\n' + "\n".join(
        modinfo_content.split("\n")[1:]
    )

    modinfo_path = mod_dist_dir / f"{mod_name}.modinfo"
    with open(modinfo_path, "w", encoding="utf-8") as f:
        f.write(modinfo_content)

    print(f"\nBuild complete!")
    print(f"Output: {mod_dist_dir}")
    print(f"\nTo install: Copy {mod_dist_dir} to your Civ5 MODS folder")


if __name__ == "__main__":
    main()
