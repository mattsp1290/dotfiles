# Installing Vita3K for this skill

Verified against `Vita3K v0.2.1 4111-ab71f829` (build 4111 of `Vita3K/Vita3K-builds`) on 2026-10-02 on the gate host: a headless aarch64 Ubuntu 24.04 machine where the Linux recipe was first proven with the real emulator. Steps that were not executed are marked `not run`, with the reason. Gate G2 is the acceptance run of the macOS steps on a Mac.

The skill installs nothing by itself. `doctor` reports what is missing and names the section of this file to follow. Follow the section for the host, then run `doctor` again.

Rules that apply to every host:

- Download Vita3K only from the official `Vita3K/Vita3K-builds` releases on GitHub, and verify the SHA-256 against the release asset `digest`.
- Ask the user before installing a host package. The agent does not run `sudo`.
- Never run the skill as root.

## Instance layout

The skill keeps everything under one instance root, `$VITA3K_AGENT_HOME` (default `$HOME/.vita3k-agent`). It never uses a personal Vita3K install or its data.

| Path under the instance root | Linux | macOS |
| --- | --- | --- |
| Emulator, first match wins | `emulator/squashfs-root/AppRun`, `emulator/Vita3K.AppImage`, `emulator/Vita3K-aarch64.AppImage`, `emulator/Vita3K-x86_64.AppImage`, then `Vita3K` on `PATH` | `emulator/Vita3K.app/Contents/MacOS/Vita3K` |
| `config.yml` | `xdg/config/Vita3K/config.yml` | `emulator/portable/config.yml` |
| `vita3k.log` | `xdg/cache/Vita3K/vita3k.log` | `emulator/portable/vita3k.log` |
| Emulated filesystem (`ux0/`, `vs0/`, ...) | `xdg/data/Vita3K/Vita3K/` | `emulator/portable/fs/` |
| Run directories | `runs/` | `runs/` |
| Lock, process state, version cache | `run.lock`, `run-state.json`, `emulator-version.json` | the same |

On Linux the script sets `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, and `XDG_DATA_HOME` for the emulator, so the instance is isolated wherever the binary lives, also for a `Vita3K` found on `PATH`. On macOS Vita3K uses a `portable/` directory beside its app bundle, so the script accepts only its own copy of `Vita3K.app` in `emulator/` with `emulator/portable/` beside it. It never falls back to `/Applications/Vita3K.app`.

A personal Vita3K keeps its data in `~/.config/Vita3K`, `~/.cache/Vita3K`, and `~/.local/share/Vita3K` on Linux, and in `~/Library/Application Support/Vita3K` on macOS. The script never writes there. After a run it checks that none of these paths appeared, disappeared, or changed its modification time.

Before every run the script sets these keys in `config.yml` and leaves every other line as it is: `show-welcome: false`, `warn-missing-firmware: false`, `check-for-updates: false`, `check-for-updates-mode: 0`, `log-level: 0`. They suppress the dialogs that would block an unattended start. With its own `Xvfb` display it also sets `backend-renderer: OpenGL`.

`VITA3K_BIN` overrides the emulator path. On macOS the override must still be an app bundle inside the instance's `emulator/` directory.

## Linux aarch64 and x86_64

Host packages are preconditions that need `sudo`. Ask the user to install a missing one. Ubuntu 24.04 names:

| Package | Needed for |
| --- | --- |
| `xvfb` | The display on a host without one. |
| `x11-apps` | `xwd`, for the screenshot. Without it a run still works and reports warning `screenshot_failed`. |
| `libgl1-mesa-dri` | Software OpenGL. |
| `libfuse2t64` | Running the AppImage directly. |

`sudo apt-get install xvfb x11-apps libgl1-mesa-dri libfuse2t64` installs them. `not run` by an agent: on the gate host the user installed `libfuse2t64`, and the other packages were already present. No other package was needed there. Whether the AppImage runs without `libfuse2t64` is untested.

Choose the build by the host's glibc. Check it with `ldd --version`.

- glibc older than 2.43 (Ubuntu 24.04 has 2.39): use build **4111**. Builds from 4112 on need `GLIBC_2.43` and do not start. The exact loader message was not recorded. `doctor` then reports `version_probe_failed`, and its `detail` holds the emulator's last output lines.
- glibc 2.43 or newer (Ubuntu 26.04 or newer): the newest build is expected to work. `not run`: no such host was available.

Install build 4111 into the instance (aarch64):

```sh
export VITA3K_AGENT_HOME="${VITA3K_AGENT_HOME:-$HOME/.vita3k-agent}"
BUILD=4111
ASSET=Vita3K-aarch64.AppImage
mkdir -p "$VITA3K_AGENT_HOME/emulator"
curl -fL -o "$VITA3K_AGENT_HOME/emulator/$ASSET" "https://github.com/Vita3K/Vita3K-builds/releases/download/$BUILD/$ASSET"
curl -fsSL "https://api.github.com/repos/Vita3K/Vita3K-builds/releases/tags/$BUILD" | python3 -c 'import json, sys; print(next(a["digest"] for a in json.load(sys.stdin)["assets"] if a["name"] == sys.argv[1]))' "$ASSET"
sha256sum "$VITA3K_AGENT_HOME/emulator/$ASSET"
chmod +x "$VITA3K_AGENT_HOME/emulator/$ASSET"
```

The API prints `sha256:<digest>`. It must equal the `sha256sum` output. Stop on a mismatch and delete the file. For build 4111 the aarch64 digest is `5803f1750d6b7737a5850944095f29327df0beaca6767cfc6104ef74b74087bd`.

Status of these commands: the gate host installed this same file at this same path and verified this digest. The commands in this exact form were run on 2026-10-02 in a throwaway Ubuntu 24.04 container, where the two digests were equal and the emulator was not started. On the gate host they are `not run` yet: the Linux acceptance run executes them from an empty instance.

x86_64: set `ASSET=Vita3K-x86_64.AppImage`. The whole x86_64 path is `unverified`: the asset name comes from the release listing, and no x86_64 host ran the emulator.

Fallback for a host without `libfuse2t64`, `not run`: extract the AppImage and let the script use the extracted form.

```sh
cd "$VITA3K_AGENT_HOME/emulator" && ./Vita3K-aarch64.AppImage --appimage-extract
```

The script prefers `emulator/squashfs-root/AppRun` when it exists.

## Headless Linux

On a host without `DISPLAY` and `WAYLAND_DISPLAY` the script starts its own `Xvfb` and seeds this renderer profile:

- `config.yml`: `backend-renderer: OpenGL`
- environment: `LIBGL_ALWAYS_SOFTWARE=1`, `__GLX_VENDOR_LIBRARY_NAME=mesa`

This is software OpenGL through Mesa (llvmpipe). It was chosen on the gate host because the screenshot shows the game frame. Software Vulkan (lavapipe) also boots the app, and it leaves the game window black in the screenshot. The NVIDIA renderer profiles were not tried.

`Vita3K --version` needs a display too: the AppImage ships only the `xcb` Qt platform plugin. `doctor` starts a short-lived `Xvfb` for its version probe.

## macOS

Vita3K opens a window, so the Mac needs a logged-in desktop session. An SSH-only shell is not enough.

Use build 4111 unless the user asks for another build. Pick the asset by `uname -m`: `arm64` uses `vita3k-4111-ab71f829-macos-arm64.dmg`, and `x86_64` uses `vita3k-4111-ab71f829-macos-intel.dmg`. For another build, print the asset names with the API call of step 3 (`a["name"]` for every asset) and take the name that ends in `macos-arm64.dmg` or `macos-intel.dmg`. The Intel asset is `not run`: no Intel Mac was available.

Run steps 1 to 6 in one shell session. They share the variables and the working directory of step 1.

1. Set the variables and create the emulator directory (unverified until gate G2):

   ```sh
   export VITA3K_AGENT_HOME="${VITA3K_AGENT_HOME:-$HOME/.vita3k-agent}"
   BUILD=4111
   ASSET=vita3k-4111-ab71f829-macos-arm64.dmg   # Intel Mac: vita3k-4111-ab71f829-macos-intel.dmg
   mkdir -p "$VITA3K_AGENT_HOME/emulator"
   cd "$VITA3K_AGENT_HOME/emulator"
   ```

2. Download the disk image (unverified until gate G2):

   ```sh
   curl -fL -o "$ASSET" "https://github.com/Vita3K/Vita3K-builds/releases/download/$BUILD/$ASSET"
   ```

3. Verify the SHA-256 against the release asset `digest`. The two values must be equal. Stop on a mismatch and delete the file (unverified until gate G2):

   ```sh
   curl -fsSL "https://api.github.com/repos/Vita3K/Vita3K-builds/releases/tags/$BUILD" | /usr/bin/python3 -c 'import json, sys; print(next(a["digest"] for a in json.load(sys.stdin)["assets"] if a["name"] == sys.argv[1]))' "$ASSET"
   shasum -a 256 "$ASSET"
   ```

4. Copy `Vita3K.app` out of the disk image into the instance (unverified until gate G2):

   ```sh
   hdiutil attach -nobrowse -readonly -mountpoint "$VITA3K_AGENT_HOME/emulator/dmg" "$ASSET"
   cp -R "$VITA3K_AGENT_HOME/emulator/dmg/Vita3K.app" "$VITA3K_AGENT_HOME/emulator/"
   hdiutil detach "$VITA3K_AGENT_HOME/emulator/dmg"
   ```

   When the copy fails, still run the `hdiutil detach` line, so the image does not stay mounted.

5. Create the portable directory beside the app. Vita3K then keeps its config, log, and emulated filesystem there (unverified until gate G2):

   ```sh
   mkdir -p "$VITA3K_AGENT_HOME/emulator/portable"
   ```

6. Remove the quarantine attribute, then delete the disk image. Use `/usr/bin/xattr`: another `xattr` on `PATH` may not know `-r` (unverified until gate G2):

   ```sh
   /usr/bin/xattr -dr com.apple.quarantine "$VITA3K_AGENT_HOME/emulator/Vita3K.app"
   rm "$ASSET"
   ```

7. Run `doctor`. It must print `"ready": true` (unverified until gate G2).

If macOS still blocks the app, for example with a dialog that says it cannot be opened, stop and ask the user. Do not change system security settings.

## Firmware (optional)

Most homebrew boots without firmware. Install it only when an app fails with missing system modules or fonts.

Every run without firmware logs these two error lines. They are harmless:

```text
|E| [load_module]: Missing file at kd/bootimage.skprx (target path: os0:kd/bootimage.skprx)
|E| [load_module]: Missing file at kd/sysmodule.skprx (target path: os0:kd/sysmodule.skprx)
```

`doctor` reports the firmware state: `firmware.main` is true when `vs0/` in the emulated filesystem has content, and `firmware.font` is true when `sa0/` has content.

- Source: Sony's system-software page for PS Vita, linked from Vita3K's quickstart page. The font package has no documented official URL.
- The agent asks the user for the firmware files. It does not search for them, and it never downloads them from an unofficial source.
- Command: the emulator's `--firmware <file.pup>` option, run with the same isolation as a run. `not run`: no firmware file was supplied.

  ```sh
  # Linux with a display
  XDG_CONFIG_HOME="$VITA3K_AGENT_HOME/xdg/config" XDG_CACHE_HOME="$VITA3K_AGENT_HOME/xdg/cache" XDG_DATA_HOME="$VITA3K_AGENT_HOME/xdg/data" "$VITA3K_AGENT_HOME/emulator/Vita3K-aarch64.AppImage" --firmware <file.pup>
  # Headless Linux: the same command under a temporary display, with the software renderer
  xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 __GLX_VENDOR_LIBRARY_NAME=mesa XDG_CONFIG_HOME="$VITA3K_AGENT_HOME/xdg/config" XDG_CACHE_HOME="$VITA3K_AGENT_HOME/xdg/cache" XDG_DATA_HOME="$VITA3K_AGENT_HOME/xdg/data" "$VITA3K_AGENT_HOME/emulator/Vita3K-aarch64.AppImage" --firmware <file.pup>
  # macOS
  "$VITA3K_AGENT_HOME/emulator/Vita3K.app/Contents/MacOS/Vita3K" --firmware <file.pup>
  ```

  Do not run it while a `run` is active on the instance.

## Updating and removing

- Update: replace the file or app bundle under `emulator/`. On macOS keep `emulator/portable/` and repeat the quarantine step. The next `doctor` probes the new version.
- Reset the emulated state without reinstalling: delete `$VITA3K_AGENT_HOME/xdg` on Linux, or the content of `$VITA3K_AGENT_HOME/emulator/portable/` on macOS. Keep the empty `portable/` directory.
- Remove everything: delete `$VITA3K_AGENT_HOME`.

## Verification

```sh
python3 <skill-dir>/scripts/vita3k_vpk.py doctor
```

It must exit 0 and print `"ready": true`. `emulator.version` names the build, and `emulator.sha256` is the SHA-256 of the emulator executable. On Linux that is the AppImage, so it equals the release digest. On macOS it is the executable inside the app bundle, which no release digest covers.

Each entry of `problems` has `code`, `detail`, and `fix`. `firmware_missing`, `xwd_missing`, and `instance_busy` do not clear `ready`. `instance_busy` means that a run holds the instance and the version probe was skipped. `emulator_missing`, `isolation_unavailable`, `version_probe_failed`, `xvfb_missing`, `privileged_user`, and `interrupted` clear it.
