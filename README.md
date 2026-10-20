# Raycast Remote Terminal Paste

Copy a screenshot, press a hotkey, and get an image path in your terminal—even when you're SSH'd into another machine.

Useful for giving a terminal coding agent a screenshot without saving it by hand, figuring out which server needs it, or running a separate upload command.

Tested by Kyle Wild in **Apple's Terminal, iTerm2, and Ghostty**. Requires macOS and Raycast.

## Prerequisites

- A Mac running macOS.
- [Raycast](https://www.raycast.com/) installed and running.
  - If you don't have this already, I recommend it. It replaces Spotlight / ⌘Space with something 1000x better.
- Apple's Terminal, iTerm2, or Ghostty.
- For remote use, an SSH connection that can authenticate without a password or other interactive prompt.

## Install

Paste this repo URL into your Codex/Claude/OpenCode/pi/whatever and say **“make this work for me, please”**:

https://github.com/dorkitude/raycast-remote-terminal-paste

The agent should register the script with Raycast, set a hotkey, and help with any macOS permissions. Suggested hotkey: **⌘⌥⇧V** (Command–Option–Shift–V).

## Use

1. Copy an image. **⌘⌃⇧4** captures a screenshot directly to the clipboard.
2. Focus the terminal tab or pane where you want the image.
3. Press your hotkey. A path such as `/tmp/clip-20261020-133242.png` appears at the cursor.
4. Add your prompt or command and submit it.

The shortcut doesn't press Return. It works with local sessions and direct SSH connections. Copy image data, rather than a filename or text; otherwise you'll get “No image on the clipboard.”

## How it Works

The script exports the clipboard image as a PNG, then identifies the focused terminal session and its TTY—the device associated with that session.

- **Local session:** saves the image in your Mac's `/tmp` and inserts that path.
- **SSH session:** finds the SSH process on that TTY, opens a separate connection using its destination and options, uploads the PNG to the remote host's `/tmp`, and removes the local copy. The inserted path points to the remote file.

Apple's Terminal and iTerm2 expose the active TTY directly. Ghostty needs a brief terminal-title probe to match its focused pane to a TTY; the result is cached for future uses.

Before inserting the path, the script checks that the same terminal session is still focused. Ghostty and iTerm2 use their scripting APIs to insert text. Apple's Terminal uses Accessibility to type the path without executing it or replacing your clipboard.

## Permissions and Limits

Allow Raycast to control your terminal when macOS asks. Apple's Terminal also requires Raycast in **System Settings → Privacy & Security → Accessibility**.

SSH authentication must work without a prompt, typically through your SSH agent or an existing multiplexed connection. Nested SSH, tmux sessions, and complex quoted SSH arguments aren't reliably detected.

Image files are created with permissions restricted to your user. Local images and remote uploads remain in `/tmp` until removed or cleaned up by the operating system.

MIT licensed. See [LICENSE](LICENSE).
