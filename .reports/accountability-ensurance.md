# Errands-rb — accountability ensurance (2026-11-08)

Grepped `lib/`, `exe/`, `.reports/` and `PORTING.md` (still does not exist —
not a gap in itself, just noted again) for `TODO`, `FIXME`, `not
implemented`, `for now`, `in a future`. Clean except for `VTODO`/`TODOS_BODY`
(the iCalendar component name and a CalDAV XML constant — false positives).
A clean grep is still not the same as a clean port. This round's job was
specifically to check whether last round's three findings got fixed, excused,
or silently dropped, and to look for new instances of the same pattern.

## 1. Last round's most serious finding — the runtime gate not reproducing — is now independently confirmed FIXED, not just re-claimed

2026-11-07's top finding was that the stated gate (140/140, 51 components)
did not reproduce: three runs all failed one check. This round's stated gate
is `drive_ok=true, 165 checks passed, 0 failed, 34 components`. Ran
`xvfb-run -a ruby test/drive_main_window.rb` twice, independently, in this
audit: **165 of 165 checks passed, DRIVE OK, both times**, including the
exact check (`widget is hidden`, in the trash step) that failed every time
last round. This is the good outcome the accountability process exists to
produce: a false-green was flagged, and the underlying bug got fixed before
the next round, not argued away. Recorded here so it isn't lost: the fix is
real and re-verified in this pass, not taken on the word of the commit log.

**One part of the stated gate still cannot be traced to anything the tools
print**: "34 components." No log line, summary, or test-file string in
`test/drive_main_window.rb` or `test/gtk_driver.rb` contains the word
"component." The check-count claim is now solid; the component-count claim
is asserted with the same lack of grounding last round's "51 components"
had, and should not be repeated as verified just because the number next to
it (165) now checks out. See `test-parity.md`.

## 2. The dead localization engine — still a live finding, unchanged, re-verified today

`lib/errands/translations.rb` is still fully built, still loads cleanly,
still tested-in-isolation working code, and is still called from **zero**
sites across all current `lib/errands/*.rb` files (re-ran the exact greps
from last round: `Translations\.(gettext|pgettext|nplural)\(` → 0 matches).
Nothing between 2026-11-07 and today touched this. If any future report
claims "translations: ported" or "i18n: done" on the strength of this file's
existence or the `.po` catalogues matching upstream's 150 msgids
(they do, verified again this round — that part is genuinely fine), that
claim is false, for the same reason it was false last round: the data is
right, the engine works, and the UI never calls either. See
`translation-parity.md`.

## 3. The GtkSourceView gap — still documented, still not escalated or fixed

Same as last round: `notes_dialog.rb`'s comment accurately names the
substitution (plain `Gtk::TextView` for `GtkSource.View`) and the reason
(`gtksourceview` typelib absent from `flake.nix`'s `gtkStack`), and the fix
(`gtksourceview5` is an ordinary nixpkgs package) remains undone. No change
since last round; carried forward rather than re-discovered, to avoid
implying it is new.

## 4. New this round: a resolved-sounding "blocker" that quietly shipped as a weaker substitute, and no report said so until now

`component-inventory.md` still lists "`Secret` typelib is not in the dev
shell" under **Blockers**, written 2026-11-02, with no later note that it
was worked around. In the meantime, `lib/errands/settings.rb` shipped
`get_secret`/`set_secret` that store the sync password in the same plaintext
JSON file as every other setting — a real, working, honestly-commented
substitution, but one with a different and weaker security property than
upstream's libsecret-backed storage. The same file's support-module table
(line 569) still calls this "the libsecret-backed `get_secret`/`set_secret`,"
which is no longer an accurate description of the code.

This is exactly the shape of gap the task asked to be adversarial about,
even though the literal phrase "for now" does not appear anywhere near it:
a real limitation, honestly commented at the code level, that never got
surfaced as a *behavioural* finding in any `component-parity.md` until this
round, and whose cross-reference in the inventory document is now stale and
would mislead a reader who trusts the table over the code. Flagged in detail
in `component-identification-audit.md` and `component-parity.md`.

## 5. A test name that claims more than its implementation delivers

`test/drive_main_window.rb`'s step `[70]`, titled "typing a password stores
it in the secret backend for that provider," passes — correctly, the value
round-trips — but exercises plaintext JSON storage, not a secret backend
(see #4). A passing, correctly-asserting test with an overclaiming name is a
small instance of the same risk as a false-green report: anyone skimming
drive output for reassurance about the password's security reads language
that isn't true. Not a bug in the check itself, but worth naming so the test
name gets fixed alongside the underlying gap, not left to drift further from
what it actually verifies.

## 6. No unit tests for non-UI logic — unchanged, still unstated as a limitation anywhere but here

`spec/` still has zero spec files; re-ran it today, `0 examples, 0 failures`.
The `.po` parser, both sync providers, and the iCal round-trip remain
exercised only indirectly (sync providers: not even that — see
`test-parity.md`) by the drive script. Unchanged from last round.

## Verdict

One of three 2026-11-07 findings is genuinely resolved and independently
re-verified in this pass (the runtime gate). Two are unchanged (dead
translation engine, GtkSourceView substitution). Two new findings are added:
a stale "blocker" that shipped as a silent weaker substitute with its own
inventory entry now inaccurate, and a test name overclaiming a security
property its implementation doesn't have. `clean: true` is not warranted.
