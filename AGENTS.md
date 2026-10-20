# Install

When asked to “make this work for me, please”:

1. Clone this repository to a permanent local directory on the user's Mac.
2. Ensure Raycast is installed, then run `./install.sh`.
3. Add the repository directory to Raycast Settings → Script Commands → Script Folders. Avoid duplicate entries.
4. Bind “Paste Image to Remote” to an unused hotkey; suggest Command–Option–Shift–V. Preserve an existing binding.
5. Help the user allow Raycast to control their terminal when macOS asks. Apple Terminal also needs Raycast enabled in System Settings → Privacy & Security → Accessibility.
6. Test with a clipboard image in the user's terminal. Confirm that the path is inserted without Return and that SSH uploads reach the correct host. `CLIP_DRY_RUN=1 ./paste-image-remote.sh` tests export/upload without inserting text; it still creates and potentially uploads a file.
7. Tell the user their hotkey and how to use it: copy an image, focus Ghostty/iTerm2/Terminal, press the hotkey.

Use existing SSH configuration and authentication. If a permission or UI step requires the user, explain the exact remaining step. Report anything you could not verify.
