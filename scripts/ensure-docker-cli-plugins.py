#!/usr/bin/env python3
"""Ensure ~/.docker/config.json has cliPluginsExtraDirs and currentContext for Colima."""

import json
import os

PLUGINS_DIR = "/opt/homebrew/lib/docker/cli-plugins"

docker_dir = os.path.join(os.path.expanduser("~"), ".docker")
config_path = os.path.join(docker_dir, "config.json")

os.makedirs(docker_dir, exist_ok=True)

if os.path.exists(config_path):
    with open(config_path, "r") as f:
        cfg = json.load(f)
else:
    cfg = {}

dirty = False

if PLUGINS_DIR not in cfg.get("cliPluginsExtraDirs", []):
    cfg.setdefault("cliPluginsExtraDirs", []).append(PLUGINS_DIR)
    dirty = True

if cfg.get("currentContext") != "colima":
    cfg["currentContext"] = "colima"
    dirty = True

if dirty:
    with open(config_path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
