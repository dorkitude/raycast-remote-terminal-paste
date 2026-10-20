# Raycast Remote Terminal Paste

Paste clipboard image paths into your terminal, locally or over SSH. Remote images upload automatically.

Tested by Kyle Wild in Apple's Terminal, iTerm2, and Ghostty.

Paste this repo URL into your Codex/Claude/OpenCode/pi/whatever and say “make this work for me, please”:

https://github.com/dorkitude/raycast-remote-terminal-paste

## How it Works

Copy an image, focus your terminal, and press the Raycast hotkey. The script saves the clipboard image as a PNG and inserts its file path without pressing Return.

For a local session, the image stays in your Mac's `/tmp`. For an SSH session, the script detects the connection on that terminal's TTY, uploads the image to the remote host's `/tmp` using your SSH configuration, and removes the local copy.

Apple's Terminal and iTerm2 expose the active TTY directly. Ghostty uses a brief terminal-title probe and caches the match. The script checks that the same terminal is still focused before inserting the path.

SSH authentication must work without a prompt. Nested SSH and tmux sessions aren't reliably detected. Images remain in `/tmp` until removed or cleaned up by the operating system.
