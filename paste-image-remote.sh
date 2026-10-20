#!/bin/bash
# Raycast script command: insert a clipboard image path into the focused
# Ghostty, iTerm2, or Apple Terminal session. If it is running ssh, the image is first
# uploaded to /tmp on that server only; otherwise it is saved to the local /tmp.
# Bind a hotkey to it in Raycast (Settings > Extensions > Script Commands).

# @raycast.schemaVersion 1
# @raycast.title Paste Image to Remote
# @raycast.mode silent
# @raycast.packageName Clipboard
# @raycast.icon 📋

set -uo pipefail
umask 077

CACHE="$HOME/.cache/a/clip-terminals"   # "<ghostty terminal id>\t<tty>" per line
mkdir -p "$(dirname "$CACHE")"
touch "$CACHE"

fail() { echo "$1"; exit 1; }

ghostty() { osascript -e "tell application \"Ghostty\"" -e "$1" -e "end tell"; }

front_app() {
    osascript -l JavaScript -e 'ObjC.import("AppKit"); ObjC.unwrap($.NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier)'
}

# Raycast's silent hotkey leaves the originating app in front. Refuse other
# apps instead of sending a path to an unrelated terminal in the background.
# CLIP_APP and CLIP_TERMINAL override selection for isolated tests.
app=${CLIP_APP:-$(front_app)} || fail "Couldn't identify the active application"
case "$app" in
    com.mitchellh.ghostty) label=Ghostty ;;
    com.googlecode.iterm2) label=iTerm2 ;;
    com.apple.Terminal) label=Terminal ;;
    *) fail "Focus Ghostty, iTerm2, or Apple Terminal first" ;;
esac

focused_target() {
    case "$app" in
        com.mitchellh.ghostty)
            ghostty 'return id of focused terminal of selected tab of front window' ;;
        com.googlecode.iterm2)
            osascript -e 'tell application id "com.googlecode.iterm2" to return tty of current session of current window' ;;
        com.apple.Terminal)
            osascript -e 'tell application "Terminal" to return tty of selected tab of front window' ;;
    esac
}

terminal_names() {
    ghostty 'set out to ""
repeat with t in every terminal
set out to out & (id of t) & (character id 9) & (name of t) & linefeed
end repeat
return out'
}

# "<tty> <pid> <args...>" for each interactive ssh client, newest last.
ssh_procs() {
    ps -axo tty=,pid=,args= | awk '$1 != "??" { n = split($3, p, "/"); if (p[n] == "ssh") { $1 = $1; print } }' | sort -k2,2n
}

# Find the tty of Ghostty terminal $1: briefly title every ssh tty with a
# marker, see which marker the terminal shows, then restore all titles.
probe_tty() {
    local id="$1" before after tty name orig ttys n tries=0
    before=$(terminal_names)
    ttys=$(ssh_procs | awk '{print $1}' | sort -u)
    n=$(printf '%s\n' "$ttys" | grep -c .)
    for tty in $ttys; do
        printf '\033]2;clipprobe-%s\007' "$tty" > "/dev/$tty"
    done
    # Ghostty applies titles asynchronously: wait until every marker shows up
    # (an ssh tty outside Ghostty, e.g. in a local tmux pane, never will).
    while :; do
        after=$(terminal_names)
        [ "$(printf '%s\n' "$after" | grep -cF $'\tclipprobe-')" -ge "$n" ] && break
        tries=$((tries + 1))
        [ $tries -ge 15 ] && break
        sleep 0.1
    done
    printf '%s\n' "$after" | grep -F $'\tclipprobe-' | while IFS=$'\t' read -r tid name; do
        tty=${name#clipprobe-}
        orig=$(printf '%s\n' "$before" | awk -F'\t' -v id="$tid" '$1 == id { print $2 }')
        printf '\033]2;%s\007' "$orig" > "/dev/$tty"
    done
    printf '%s\n' "$after" | awk -F'\t' -v id="$id" '$1 == id && $2 ~ /^clipprobe-/ { sub(/^clipprobe-/, "", $2); print $2 }'
}

# 1. Capture the target before reading or uploading the image.
term=${CLIP_TERMINAL:-$(focused_target)} || fail "No focused $label terminal"
[ -n "$term" ] || fail "No focused $label terminal"

# 2. Clipboard image -> PNG file (CLIP_IMAGE=<png> uses that file instead, for testing).
stamp=$(date +%Y%m%d-%H%M%S)
png="/tmp/clip-$stamp.png"
if [ -n "${CLIP_IMAGE:-}" ]; then
    cp "$CLIP_IMAGE" "$png" || fail "Can't read $CLIP_IMAGE"
elif ! osascript -e "set f to open for access POSIX file \"$png\" with write permission" \
        -e 'try' -e 'write (the clipboard as «class PNGf») to f' \
        -e 'on error' -e 'close access f' -e 'error number -1' -e 'end try' \
        -e 'close access f' >/dev/null 2>&1; then
    rm -f "$png"
    fail "No image on the clipboard"
fi

# 3. iTerm2 and Terminal expose the tty directly; Ghostty needs a cached probe.
procs=$(ssh_procs)
if [ "$app" != com.mitchellh.ghostty ]; then
    tty=${term#/dev/}
else
    tty=$(awk -F'\t' -v id="$term" '$1 == id { print $2 }' "$CACHE" | tail -1)
    if [ -z "$tty" ] || ! printf '%s\n' "$procs" | awk -v t="$tty" '$1 == t { f = 1 } END { exit !f }'; then
        tty=""
        [ -n "$procs" ] && tty=$(probe_tty "$term")
        if [ -n "$tty" ]; then
            { grep -vF "$term" "$CACHE"; printf '%s\t%s\n' "$term" "$tty"; } > "$CACHE.new" && mv "$CACHE.new" "$CACHE"
        fi
    fi
fi

# 4. Upload to that ssh destination, reusing the session's ssh options.
path="$png"
if [ -n "$tty" ] && printf '%s\n' "$procs" | awk -v t="$tty" '$1 == t { f = 1 } END { exit !f }'; then
    read -r -a argv <<< "$(printf '%s\n' "$procs" | awk -v t="$tty" '$1 == t' | tail -1 | cut -d' ' -f3-)"
    opts=() dest=""
    i=1
    while [ $i -lt ${#argv[@]} ]; do
        a=${argv[$i]}
        case "$a" in
            -[BbcDEeFIiJLlmOoPpQRSWw]) opts+=("$a" "${argv[$((i + 1))]}"); i=$((i + 2)); continue ;;
            -*) opts+=("$a") ;;
            *) dest="$a"; break ;;
        esac
        i=$((i + 1))
    done
    [ -n "$dest" ] || fail "Couldn't read the ssh destination for $tty"
    remote="/tmp/clip-$stamp.png"
    ssh ${opts[@]+"${opts[@]}"} -o BatchMode=yes -o ConnectTimeout=5 "$dest" "umask 077; cat > $remote" < "$png" ||
        fail "Upload to $dest failed"
    rm -f "$png"
    path="$remote"
fi

# CLIP_DRY_RUN=1: stop before pasting (for testing).
[ -z "${CLIP_DRY_RUN:-}" ] || { echo "would paste ${dest:-local}:$path"; exit 0; }

# 5. Recheck focus after the upload so switching apps/tabs cannot misdirect input.
[ "$(front_app)" = "$app" ] && [ "$(focused_target)" = "$term" ] ||
    fail "Terminal focus changed; image saved at ${dest:-local}:$path"
case "$app" in
    com.mitchellh.ghostty)
        ghostty "input text \"$path\" to focused terminal of selected tab of front window" >/dev/null ||
            fail "Couldn't paste into Ghostty" ;;
    com.googlecode.iterm2)
        osascript -e "tell application id \"com.googlecode.iterm2\" to tell current session of current window to write text \"$path\" newline false" >/dev/null ||
            fail "Couldn't insert into iTerm2" ;;
    com.apple.Terminal)
        # Terminal's `do script` executes input. Type this generated, ASCII-only
        # path instead, preserving the clipboard and never sending Return.
        osascript -e "tell application \"System Events\" to tell process \"Terminal\"
if not frontmost then error \"Terminal lost focus\"
keystroke \"$path\"
end tell" >/dev/null ||
            fail "Couldn't insert into Terminal; allow Raycast in System Settings > Privacy & Security > Accessibility" ;;
esac
echo "📋 ${dest:-local}:$path"
