# Steam Invasive Stopper

[![macOS only](https://img.shields.io/badge/platform-macOS%20only-343a40)](https://github.com/esig626/Steam_Invasive_Stopper) [![macOS validation](https://github.com/esig626/Steam_Invasive_Stopper/actions/workflows/validate.yml/badge.svg)](https://github.com/esig626/Steam_Invasive_Stopper/actions/workflows/validate.yml) [![MIT licence](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

**macOS only** · Event driven · No administrator privileges · Fully reversible

Steam can leave its `ipcserver` helper running after you quit the Mac application. **Steam Invasive Stopper**, also called *SteamOff*, watches for Steam's termination event and removes that leftover service automatically. It does not interfere while Steam is open.

This is a narrowly focused workaround, **not** a general privacy tool or network firewall.

## How it works

```text
Open Steam                     Steam works normally
       ↓
Quit Steam                     macOS sends a termination notification
       ↓
Wait 10 seconds                Allow normal shutdown to finish
       ↓
Is Steam running again?        Yes → do nothing
       ↓ No
Is ipctool still registered?   No → do nothing
       ↓ Yes
Remove leftover ipctool       launchctl remove com.valvesoftware.steam.ipctool
```

The small listener runs in your login session and waits for an event. **There is no periodic checking every 30 or 120 seconds.** Because it waits for events, it does occupy a little memory while signed in.

## Compatibility

| | Support |
| --- | --- |
| Operating system | **macOS only** (not Windows or Linux) |
| Computers | Intel and Apple silicon Macs, compiled locally |
| Steam | macOS desktop client using `com.valvesoftware.steam.ipctool` |
| Permissions | Normal user account; no `sudo` |
| Prerequisite | Xcode or Apple Command Line Tools (Swift compiler) |

The approach was confirmed on one Mac in November 2026, including a real Steam launch, quit and automatic cleanup. It has not been tested on every macOS version or Steam release.

## Install

Open **Terminal** on your Mac and run:

```bash
git clone https://github.com/esig626/Steam_Invasive_Stopper.git
cd Steam_Invasive_Stopper
bash ./steamoff-setup.sh install
```

If the compiler is missing, run `xcode-select --install`, finish the installation and repeat the install command. You may also download the repository as a ZIP from GitHub, extract it, open Terminal in the extracted folder and run `bash ./steamoff-setup.sh install`.

The installer creates a compiled listener, a LaunchAgent and a log **in your user account**. It does not change the Steam application, games, saves or system components. Repeating the install command updates SteamOff.

## Test it

1. Start Steam with `open -a Steam` and let it finish loading.
2. While Steam is open, run `bash ./steamoff-setup.sh status`. Steam's main process and `ipctool` should normally appear.
3. Quit Steam using **Steam → Quit Steam**. Do not run `launchctl remove` manually during the test.
4. After roughly 15 to 20 seconds, run `bash ./steamoff-setup.sh status` again.

When Steam leaves `ipctool` behind, the log should contain:

```text
Steam terminated
Removed leftover ipctool service
```

The status should then show no Steam processes and no Steam IPC service. If Steam already closed its own IPC service, the log will instead say `No leftover ipctool service`. That is also a successful outcome.

To see the log without the installer:

```bash
tail -n 20 "$HOME/Library/Logs/steamoff-event.log"
```

**Important:** The listener reacts to Steam terminating *after the listener has started*. If Steam was already closed before installation, open and quit it once to test.

## Check status or uninstall

From the repository folder:

```bash
bash ./steamoff-setup.sh status
bash ./steamoff-setup.sh uninstall
```

Uninstall removes SteamOff's LaunchAgent, programme, source copy and logs. It leaves Steam untouched. If you move or delete the repository after installing, download it again to run the uninstaller.

## What it does not do

* Does not block network traffic, telemetry, adverts or data collection while Steam is open.
* Does not disable Steam's separate `steamclean` agent or macOS background permission settings.
* Does not prevent Steam from starting or reinstalling its IPC service when you choose to open it.
* Does not run on Windows or Linux.

There is a small unavoidable delay after quitting, and a restart during that delay causes cleanup to be skipped intentionally. If Valve changes Steam's app identifier or service name, this workaround may need updating.

## Files

| File | Purpose |
| --- | --- |
| `steamoff-setup.sh` | Installer, status check and removal |
| `Sources/SteamQuit.swift` | Readable source code for the event listener |
| `.github/workflows/validate.yml` | Compiles the listener on a macOS GitHub runner |
| `LICENSE` | MIT licence |

The Swift programme makes no network requests. You can inspect all source code before installation. Issues and improvements are welcome through [GitHub Issues](https://github.com/esig626/Steam_Invasive_Stopper/issues).

*Independent utility. Not affiliated with or endorsed by Valve or Apple.*