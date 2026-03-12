# Show-ExecutiveProgressBar

> *Enterprise-grade progress visualization for the discerning systems administrator.*

A PowerShell script that displays an animated ASCII art progress bar with rotating status messages, dynamic color theming, and a suite of advanced features including sinusoidal image locomotion, venetian-blind transition effects, and rainbow mode. It was built during a server provisioning session. It is, objectively, the most important infrastructure tool in this repository.

---

## Origin

This project was conceived in the field under adverse conditions — specifically, a live server build during a team meeting where a colleague with opinions — Peter — expressed that he required entertainment. The script was written in response to that request. Peter has since been immortalized in the codebase. This was not optional for him.

What began as a two-minute distraction has since grown into a fully parameterized, multi-phase, color-cycling, image-flipping, rainbow-capable progress bar framework. This is what happens when senior engineers ask for things.

---

## Requirements

- PowerShell 5.1 or later
- Windows 10 / 11 / Server 2016–2025
- A terminal window of reasonable dimensions
- A sense of humor (optional but strongly recommended for `-FUMode`)

---

## Installation

1. Clone or download the repository
2. Place any ASCII art `.txt` files you want to display in an `image-txt\` folder in the same directory as the script
3. Ensure `da-finger.txt` is present in `image-txt\` if using `-FUMode`
4. Run the script

```powershell
git clone https://github.com/ActiveDirectoryKC/PetersVibeProgressBar
cd PetersVibeProgressBar
.\Show-ExecutiveProgressBar.ps1
```

No external modules required. No package manager. No feelings.

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Period` | `int` | `60` | Duration in seconds of the main progress bar |
| `-Loop` | `int` | `0` | Seconds to display the wait screen between passes. `0` runs once and exits. |
| `-ImageColor` | `string` | random | Starting accent color. Rotates each loop pass. Valid: `Cyan`, `Green`, `Yellow`, `Magenta`, `White`, `Red` |
| `-Interval` | `int` | `1` | Reserved for future use. Present for backward compatibility and the comfort it provides. |
| `-RainbowMode` | `switch` | — | Forces rainbow color cycling. Also activates automatically 1 in 5 runs whether you asked for it or not. |
| `-FUMode` | `switch` | — | See [FUMode](#fumode) |
| `-ExecTargetName` | `string` | `Peter` | See [FUMode](#fumode). Aliases: `-LeadTargetName`, `-ManagerTargetName` |

---

## Usage

**Basic — run once for 60 seconds:**
```powershell
.\Show-ExecutiveProgressBar.ps1
```

**Run for 2 minutes, loop every 30 seconds:**
```powershell
.\Show-ExecutiveProgressBar.ps1 -Period 120 -Loop 30
```

**Start with a specific color:**
```powershell
.\Show-ExecutiveProgressBar.ps1 -ImageColor Magenta
```

**Force rainbow mode:**
```powershell
.\Show-ExecutiveProgressBar.ps1 -RainbowMode
```

**Verbose output for debugging:**
```powershell
.\Show-ExecutiveProgressBar.ps1 -Verbose
```

---

## Workflow

The script follows a two-phase loop:

**Phase 1 — Dance:**
An ASCII art image is selected at random from the `image-txt\` folder and displayed with a progress bar. The image drifts left and right in a sinusoidal pattern. Periodically it flips horizontally via a venetian-blind wipe transition. Status messages rotate every few seconds. Colors vary per pass. Rainbow mode activates at its own discretion.

**Phase 2 — Wait** *(only when `-Loop` is set)*:
A second progress bar counts down the loop interval with no image — just a centered header and a status panel. Colors are independently randomized. Has its own 1-in-5 rainbow roll. Ends with `"Here we go again."` because someone has to say it.

Once Phase 2 completes, Phase 1 resumes with a new image and a new color. This continues indefinitely until `Ctrl+C` or someone resolves the ticket.

---

## FUMode

```powershell
.\Show-ExecutiveProgressBar.ps1 -FUMode
.\Show-ExecutiveProgressBar.ps1 -FUMode -ExecTargetName "Dave"
```

`-FUMode` is a targeted operational mode designed for use when a specific colleague has made a specific request and you want to make absolutely sure they understand the impact of that decision.

When active:
- The `da-finger.txt` ASCII art is loaded instead of a random image
- Status messages are replaced with a curated set of professionally worded observations about the target individual, including but not limited to: pinging them with no response, reverting their last commit, filing them under unsolved problems, and Cc-ing their manager
- The image does not flip. The gesture is directional and the direction is intentional.

`-ExecTargetName` (aliases: `-LeadTargetName`, `-ManagerTargetName`) sets the name of the target. Defaults to `Peter`. This default was not chosen arbitrarily.

> *This feature is work-appropriate. It's really more of a performance review tool.*

---

## Screenshots / Demo

*Screenshots and a demo GIF will be added here. The author was busy running a progress bar.*

---

## Notes

- Accent colors rotate through: Cyan → Green → Yellow → Magenta → White → Red, advancing each loop pass
- Rainbow color steps occur every 1–5 seconds (randomized per step)
- Image flips are scheduled every 15–35 seconds (randomized per flip)
- The script clears the terminal and restores the cursor on exit, including `Ctrl+C`
- `Invoke-ConsoleSetup` (window resizing + QuickEdit disable) is present but disabled — it conflicts with Windows Terminal's window management. It is available for future use in environments that behave themselves.
- `-Verbose` emits per-run diagnostics including image path, colors, and rainbow state

---

## Version History

| Version | Date | Notes |
|---|---|---|
| 2.1 | 2025-03-10 | Initial release |
| 2.2 | 2025-03-12 | Wait screen, content centering, per-pass color rotation, rainbow mode, slide-wipe flip, `FUMode` target naming, `Ctrl+C` cleanup |

---

*Built with PowerShell 5.1. Tested on Windows. Inspired by a reasonable request from a reasonable colleague.*