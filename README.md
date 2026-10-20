# Remote Terminal Paste for Raycast

Copy an image, focus a terminal, and press a Raycast hotkey to insert its file path. When the terminal is connected over SSH, the image is uploaded to that host first.

Supports **Ghostty**, **iTerm2**, and **Apple Terminal** on macOS.

## Setup

1. Clone this repository and run `./install.sh`.
2. In Raycast Settings → Script Commands, add the repository folder as a script folder. Older Raycast versions put this under Extensions → Script Commands.
3. Assign **Paste Image to Remote** a hotkey, such as **⌘⌥⇧V**.
4. Allow Raycast to control your terminal when macOS asks. Apple Terminal also requires Raycast in System Settings → Privacy & Security → Accessibility.

Requires Raycast, macOS AppleScript, and the system SSH client. No Python or package installation is needed to use the command.

## Use

1. Copy image data to the clipboard. **⌘⌃⇧4** captures a screenshot directly to the clipboard.
2. Focus the desired terminal tab or pane.
3. Press the hotkey. A path such as `/tmp/clip-20261020-100421.png` is inserted without pressing Return.
4. Add a prompt or command and submit it yourself.

Use the hotkey while the terminal is frontmost. The command rejects other applications and checks focus again after uploading. Copying a filename or text instead of image data produces “No image on the clipboard.”

## How it works

- Exports the clipboard as PNG, with files restricted to the current user.
- Reads iTerm2's active session TTY or Terminal's selected tab TTY directly.
- For Ghostty, associates the focused terminal ID with an SSH TTY by briefly setting terminal title markers, restoring visible Ghostty titles, and caching the result under `~/.cache/a/clip-terminals`.
- Finds an SSH process on that TTY and opens a separate noninteractive connection using its destination and options to upload the image to `/tmp`.
- Removes the local copy after a successful upload. Local images and remote uploads remain in `/tmp` until removed or cleaned by the operating system.
- Ghostty inserts via its paste API; iTerm2 writes text with `newline false`; Terminal types the generated ASCII path using Accessibility, preserving the clipboard.

## Limits

SSH authentication must work without a prompt, typically using an agent or an existing multiplexed connection. Standard direct SSH sessions are the intended use case. Nested SSH, tmux remote sessions, and complex or quoted SSH arguments are not reliably detected. The current SSH argument parser splits the process command line on whitespace. Ghostty title probing may also interact poorly with terminal multiplexers or custom title handling.

## Development

```sh
bash -n paste-image-remote.sh
shellcheck paste-image-remote.sh
uv run --no-project python -m unittest discover -s tests -v
```

The tests mock application scripting, process discovery, and SSH. They do not access the clipboard, send terminal input, or make network connections. Live clipboard extraction and upload have been verified in Ghostty; iTerm2 and Terminal still need live end-to-end verification.

For a live upload test that stops before inserting text:

```sh
CLIP_DRY_RUN=1 ./paste-image-remote.sh
```

This **does write a file and upload it** when an SSH session is detected. `CLIP_IMAGE=/path/to/image.png` substitutes a file for the clipboard. `CLIP_APP=<bundle-id>` and `CLIP_TERMINAL=<terminal-id-or-tty>` override target selection for tests.
