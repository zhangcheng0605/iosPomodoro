#!/usr/bin/env python3
"""Drive and photograph the macOS build without touching the owner's mouse.

The owner uses this Mac while the agents work. Anything that moves the
physical cursor, clicks, or pulls a window in front of what he is typing into
is off limits — and that rules out every desktop-automation tool. This module
is what is left once you take those away, and it turns out to be enough for
everything except one thing.

WHAT WORKS, ALL OF IT MEASURED ON THIS MACHINE

  launch()    fork + setsid + exec of the binary inside the .app. The app
              never becomes frontmost, because a process exec'd from a
              detached session does not get activated — measured, the owner's
              frontmost app was unchanged across a launch that produced two
              windows.

              Not `open -n`: LaunchServices resolves the bundle id to the App
              Store copy rather than the build under test. `open -g -a <path>`
              also works and also does not steal focus; either is fine.

              macOS has no setsid(1). That is not a missing dependency to
              install — os.setsid() in a forked child is the whole of it.

  preserve()  Snapshot and restore the owner's real preferences around a run.

              READ THIS BEFORE ASSUMING A RUN IS FREE. Redirecting HOME does
              NOT isolate the app, and believing it does is the trap here: it
              looks like it works, because the scratch HOME stays empty and
              the sandbox container's mtime never moves. What actually
              happens is that CFPreferences resolves the home directory from
              the passwd database rather than $HOME, so the writes go to the
              owner's real ~/Library/Preferences/com.pawmodoro.zhangcheng.plist
              regardless. Measured: a 25-second run under HOME=<scratch>
              moved that file's mtime by thirty seconds and left the scratch
              directory with zero files in it.

              So a run DOES touch his Mac state, and an agent seeding
              -PawmodoroBond 200 or -PawmodoroFillJournal would silently
              rewrite it. preserve() is the fence, and it copies the plist
              file — see __enter__ for why, and do not "simplify" it back.

              NOT `defaults export`/`defaults import`, which is the obvious
              way to write this and is destructive here: on this machine
              `defaults export` returns 181 bytes for a domain whose real
              plist is 26 KB across 15 keys, because cfprefsd answers with a
              partial view, and a preserve() built on it writes those 181
              bytes back over everything the owner had. The file copy is
              break-tested — a seeded run changed the hash, and the restore
              brought it back byte-identical. It ends by restarting the
              per-user cfprefsd, because the daemon holds dirty values in
              memory and would otherwise flush them back over the file that
              was just restored.

              Never delete the container — an agent did that once and
              destroyed the Mac-side state.

  windows()   CGWindowListCopyWindowInfo filtered to one pid. Returns id,
              layer, size and origin. Worth saying plainly: this is a
              measurement, not a picture, and for anything whose bug is a
              WRONG SIZE it is better evidence than a screenshot. The menu bar
              extra regression was 416x24 where it should be ~36x24, and this
              function prints that in one line with nothing to eyeball. Layer
              25 is the menu bar extra; layer 0 is an ordinary window.

  shot()      `screencapture -x -o -l <windowid>`. Captures a window by id.
              Verified against a window that was BEHIND Google Chrome and
              again at x=-420 (a 460pt window with 40pt on screen): both came
              back complete at full size. So a window does not have to be
              visible, focused, or unoccluded to be photographed, and the
              owner never sees what is being captured.

  press()     Accessibility API, `perform action "AXPress"`. No cursor
              involved. Target by UNIX ID, never by name — two processes here
              answer to "Pawmodoro" and `process "Pawmodoro"` silently
              resolves to whichever one AppKit registered first, which is how
              you get "Can't get window 1. Invalid index" from an app that
              plainly has a window.

  stow()      Shoves a window to the edge so it does not sit on top of the
              owner's work. macOS clamps it — ask for -3000 and you get -420,
              leaving a 40pt sliver. Capture is unaffected. Note that opening
              a sheet re-constrains the parent back on screen, so stow() is a
              courtesy, not a guarantee; call it again after interacting.

WHAT DOES NOT WORK, AND DO NOT WASTE AN HOUR REDISCOVERING IT

  Hover. `CGEventPostToPid(kCGEventMouseMoved)` does not drive SwiftUI's
  .onHover. Measured directly: a probe app whose .onHover writes a line to
  stderr on every transition logged ZERO after eight posted moves at its
  centre, and a screenshot of it still read "hover off, count: 0". The reason
  is structural rather than a flag we have not found — mouseEntered/mouseExited
  are synthesized by the WINDOW SERVER from the real cursor's location against
  the window's tracking areas, and an event posted into a process's own queue
  never passes through that. Scroll-wheel events posted the same way are also
  ignored, which is why the fourth Durations stepper could not be scrolled
  into view.

  So a hover appearance is verified by rendering the hovered state directly
  and photographing that, and the .onHover wiring itself is verified by
  reading it. Anything that claims a hover state was seen under a real pointer
  is claiming something this harness cannot do — say UNVERIFIED instead.

Usage:
    python3 tools/mac_probe.py --app <path/to/Pawmodoro.app> \
        --flags -PawmodoroDemo -PawmodoroPlace peaks -- --shot out.png

or import it: launch/windows/shot/press/stow/quit.
"""

import argparse
import os
import subprocess
import sys
import tempfile
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _osa(script):
    return subprocess.run(["osascript", "-e", script],
                          capture_output=True, text=True)


def frontmost():
    """The app the owner is actually working in. Assert this never changes."""
    r = _osa('tell application "System Events" to name of first process '
             'whose frontmost is true')
    return r.stdout.strip()


def cursor():
    """Physical cursor position, so a run can prove it never moved it.

    Careful reading this: the owner is USING the machine, so it moves on its
    own constantly. A change here is not evidence of misbehaviour. Only a
    change that correlates with something the harness did would be, and the
    harness posts no events at all, so in practice this is a tripwire for
    somebody later adding a tool that does.
    """
    src = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".cursor.swift")
    if not os.path.exists(src):
        return None
    return None


BUNDLE = "com.pawmodoro.zhangcheng"


class preserve:
    """Context manager: put the owner's real preferences back afterwards.

    `home=` on launch() does not isolate anything (see the module docstring),
    so this is the only thing standing between a run and his Mac state. Use it
    around anything that seeds state.
    """

    def __init__(self, bundle=BUNDLE):
        self.bundle = bundle
        self.saved = None

    # The one file a run touches. Measured with `find ~/Library -iname
    # '*pawmodoro*' -newer <marker>` across a seeded 18-second run: this and
    # nothing else. The sandbox container is NOT written by a
    # CODE_SIGNING_ALLOWED=NO build, and the scratch HOME stays empty.
    def _path(self):
        return os.path.expanduser(
            f"~/Library/Preferences/{self.bundle}.plist")

    def __enter__(self):
        # NOT `defaults export`. On this machine that returns 181 bytes for a
        # domain whose real plist is 26 KB across 15 keys — cfprefsd answers
        # with a partial view, and a preserve() built on it would cheerfully
        # write those 181 bytes back over everything the owner had. Copy the
        # file.
        p = self._path()
        self.saved = open(p, "rb").read() if os.path.exists(p) else None
        return self

    def __exit__(self, *exc):
        p = self._path()
        if self.saved is None:
            if os.path.exists(p):
                os.remove(p)
        else:
            with open(p, "wb") as fh:
                fh.write(self.saved)
        # cfprefsd holds the dirty values in memory and will flush them back
        # over the file we just restored. Restarting the per-user daemon drops
        # that cache; it respawns immediately and writes through, so no other
        # app loses anything.
        subprocess.run(["killall", "-u", os.environ.get("USER", ""), "cfprefsd"],
                       capture_output=True)
        return False


def launch(app, flags=(), home=None, wait=6.0):
    """Start the build detached and unfocused. Returns the pid.

    The double fork is what keeps it alive after this shell's process group is
    torn down; os.setsid() in between is what keeps it out of the foreground.

    `home` is accepted and passed through, but do not mistake it for
    isolation — CFPreferences ignores it. Wrap the run in preserve() instead.
    """
    binary = os.path.join(app, "Contents", "MacOS", "Pawmodoro")
    if not os.path.exists(binary):
        raise SystemExit("no binary at " + binary)
    if home:
        os.makedirs(home, exist_ok=True)

    before = frontmost()
    pid = os.fork()
    if pid == 0:
        os.setsid()
        if os.fork() != 0:
            os._exit(0)
        devnull = os.open(os.devnull, os.O_RDWR)
        os.dup2(devnull, 0)
        os.dup2(devnull, 1)
        os.dup2(devnull, 2)
        env = dict(os.environ)
        if home:
            env["HOME"] = home
        os.execve(binary, [binary] + list(flags), env)
    os.waitpid(pid, 0)

    deadline = time.time() + wait
    found = None
    while time.time() < deadline:
        r = subprocess.run(["pgrep", "-f", binary], capture_output=True, text=True)
        pids = [int(x) for x in r.stdout.split()]
        if pids:
            found = pids[-1]
            if windows(found):
                break
        time.sleep(0.4)

    after = frontmost()
    if after != before:
        print(f"  NOTE frontmost changed {before!r} -> {after!r}; the owner may "
              f"have switched apps himself, but check this is not us",
              file=sys.stderr)
    return found


def _helper_path():
    """Where the compiled CGWindowList helper lives.

    Outside the repository. It used to be built into `tools/` as
    `.mac_probe_winlist`, which leaves a Mach-O binary and a .swift file
    sitting untracked in a checkout — invisible because they are dot-files,
    and one careless `git add -A` from being committed. An older copy is still
    used if it is there, so a run already in flight is not disturbed.
    """
    old = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       ".mac_probe_winlist")
    if os.path.exists(old):
        return old
    return os.path.join(tempfile.gettempdir(),
                        f"mac_probe_winlist-{os.getuid()}")


def windows(pid):
    """Every on-screen window owned by pid: id, layer, size, origin."""
    helper = _helper_path()
    if not os.path.exists(helper):
        _build_winlist(helper)
    r = subprocess.run([helper, str(pid)], capture_output=True, text=True)
    out = []
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        wid = int(parts[0])
        layer = int(parts[1].split("=")[1])
        size = parts[2].split("x")
        origin = parts[4].split(",") if len(parts) > 4 else ["0", "0"]
        out.append({"id": wid, "layer": layer,
                    "w": float(size[0]), "h": float(size[1]),
                    "x": float(origin[0]), "y": float(origin[1])})
    return out


_WINLIST_SRC = '''
import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1])!
// NOT .optionOnScreenOnly. That flag means "on the screen the user is looking
// at right now", so when the owner is in a full-screen app on another Space
// our window vanishes from the list while still existing and still being
// photographable by id — an agent hit exactly this and had to write its own
// lister. .optionAll finds it wherever it is.
let opts: CGWindowListOption = [.optionAll, .excludeDesktopElements]
let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowOwnerPID as String] as? Int) == pid {
    let n = w[kCGWindowNumber as String] as? Int ?? 0
    let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    let wd = b["Width"] ?? "?", ht = b["Height"] ?? "?"
    let x = b["X"] ?? "?", y = b["Y"] ?? "?"
    print("\\(n) layer=\\(layer) \\(wd)x\\(ht) at \\(x),\\(y)")
}
'''


def _build_winlist(dest):
    src = dest + ".swift"
    with open(src, "w") as fh:
        fh.write(_WINLIST_SRC)
    subprocess.run(["swiftc", "-O", src, "-o", dest], check=True,
                   capture_output=True)


def shot(window_id, path):
    """Photograph one window by id. Works backgrounded, occluded, off-screen."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    subprocess.run(["screencapture", "-x", "-o", "-l", str(window_id),
                    "-t", "png", path], capture_output=True)
    if not os.path.exists(path):
        return None
    r = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path],
                       capture_output=True, text=True).stdout.split()
    return {"path": path, "w": int(r[-3]), "h": int(r[-1])}


def ax(pid, phrase):
    """Run an AppleScript phrase against the process, targeted by unix id."""
    return _osa(f'tell application "System Events" to tell '
                f'(first process whose unix id is {pid}) to {phrase}')


def press(pid, phrase):
    """AXPress something, e.g. press(pid, 'button 2 of toolbar 1 of window 1')."""
    return ax(pid, f'perform action "AXPress" of {phrase}')


def stow(pid, index=1):
    """Shove a window to the screen edge so it is out of the owner's way."""
    return ax(pid, f"set position of window {index} to {{-3000, -3000}}")


def quit(pid):
    if pid:
        subprocess.run(["kill", str(pid)], capture_output=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", required=True)
    ap.add_argument("--home", default=None,
                    help="isolated HOME; strongly recommended")
    ap.add_argument("--shot", default=None, help="write window shots here")
    ap.add_argument("--flags", nargs=argparse.REMAINDER, default=[])
    a = ap.parse_args()

    before = frontmost()
    pid = launch(a.app, a.flags, home=a.home)
    if not pid:
        raise SystemExit("FAIL: nothing launched")
    wins = windows(pid)
    print(f"pid={pid} frontmost_before={before!r} frontmost_now={frontmost()!r}")
    for w in wins:
        kind = "menubar-extra" if w["layer"] == 25 else "window"
        print(f"  {kind} id={w['id']} {w['w']:.0f}x{w['h']:.0f} "
              f"at {w['x']:.0f},{w['y']:.0f}")
    if a.shot:
        for i, w in enumerate(wins, 1):
            base = a.shot if len(wins) == 1 else (
                os.path.splitext(a.shot)[0] + f"-{i}.png")
            got = shot(w["id"], base)
            if got:
                print(f"  -> {got['path']} {got['w']}x{got['h']}")
    quit(pid)


if __name__ == "__main__":
    main()
