# Privacy Policy for Pawmodoro

_Last updated: 30 July 2026_

Pawmodoro does not collect, transmit, or share any personal data.

The app has no account system, no analytics, no advertising, and no third-party
SDKs. It makes no network requests of any kind.

## What the app stores

Your timer settings, your chosen buddy, and your completed-session history are
saved **only on your device**, using the operating system's standard local
storage. This data never leaves your phone, and the developer has no access to
it.

Deleting the app removes this data. You can also erase your session history at
any time from the stats screen ("Clear").

## Notifications

If you allow notifications, Pawmodoro schedules them locally on your device so it
can tell you when a focus session or break has ended. No notification data is
sent to any server.

## Children

Pawmodoro is suitable for all ages and does not collect data from anyone,
including children.

## Changes

If this policy ever changes, the updated version will be posted at this address
with a new "last updated" date.

## Contact

Questions about this policy: zhangcheng1997@gmail.com

---

**Note for the developer:** App Store Connect requires a publicly reachable
privacy policy **URL**. To publish this file for free, enable GitHub Pages on
this repo (Settings → Pages → Source: `main` branch, `/docs` folder). The page
will then be served at
`https://zhangcheng0605.github.io/iosPomodoro/PRIVACY` — use that as your
privacy policy URL. Delete this note before publishing if you'd rather it not
appear on the page.


## The Scrapbook (added with the Hearth era)

Pawmodoro can keep photographs you choose, of wherever you happen to be
sitting. Three things are true of them and are enforced in code rather than by
policy:

- **They never leave your device.** The app makes no network calls at all.
  There is no account, no sync, no upload, and no code path that could send an
  image anywhere.
- **Location data is removed on import.** Every photograph is re-encoded
  through `SnapshotImport.prepare` before it is written, which drops all EXIF
  metadata including GPS. `tools/check_film.py` fails the build if that
  re-encode is removed.
- **Nothing is read without you choosing it.** The picker is `PhotosPicker`,
  which hands the app only the images you select and needs no library
  permission at all.

Photographs live in the app's own Documents folder and are deleted with the
app. Removing one in the app deletes the file immediately.
