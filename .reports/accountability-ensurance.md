# Errands-rb — accountability ensurance (2026-11-07)

Grepped `lib/`, `exe/`, `.reports/` and (would have grepped) `PORTING.md` for
`TODO`, `FIXME`, `not implemented`, `for now`, `in a future`. No
`PORTING.md` exists in this repo — not a gap in itself, just noting the file
named in the brief isn't there. The literal grep came back clean (the only
hits were `VTODO`, the iCalendar component name, a false positive). A clean
grep is not the same as a clean port; three real gaps found by running things
and reading code, not by grepping for an admission string, follow.

## 1. The runtime gate claimed for this round does not reproduce — the most serious finding

The task's stated gate: `drive_ok=true, 140 checks passed, 0 failed, 51
components`. Ran `xvfb-run -a ruby test/drive_main_window.rb` on `HEAD`
(`ceb3d6e8`) three separate times in this audit:

```
139 of 140 checks passed
  failed check: widget is hidden
DRIVE FAILED (1)
```

Identical on all three runs — not a flake that passed on retry. Whoever or
whatever produced "140 passed, 0 failed" for this round either ran a
different commit, a different environment, or the number is simply wrong.
**This is the false-green case the task asked to watch for, and it is sitting
in the task's own framing of this round, not just in a report a port-writer
left behind.** Treat the stated gate as unverified until someone reruns it
and gets 140/140 twice.

## 2. A fully-built, individually-correct subsystem that is never called — a Potemkin feature

`lib/errands/translations.rb` is 205 lines of careful, tested-in-this-audit,
working `.po`-parsing/gettext code: `msgctxt`, plural forms, continuation
lines, C escapes, locale candidate resolution. It is `require_relative`d from
`application.rb`. It is called from **nowhere** — zero call sites across all
32 files in `lib/errands/`. Every translatable string in the app is a bare
English literal. Full detail in `translation-parity.md`.

This is worse than an admitted gap, because nothing announces it: the module
exists, loads cleanly, has a docstring explaining upstream's gettext usage in
convincing detail, and would pass a shallow "does `translations.rb` exist and
look right" check. Only tracing whether its methods are ever invoked from the
UI surfaces that it does nothing at runtime. If a future report says
"translations: ported" on the strength of this file's existence, that claim
is false, and this is exactly the shape of false claim the task asked to be
adversarial about.

## 3. A documented gap whose root cause was never escalated to a fix

`lib/errands/notes_dialog.rb`'s own comment candidly says GtkSourceView "has
no binding in this port's dev shell," and substitutes a plain `Gtk::TextView`.
This comment is honest, not evasive — it names the real upstream widget, the
real behavioural loss (markdown highlighting, dark-mode scheme, line
numbers), and the real reason. Verified the reason is accurate: `flake.nix`'s
`gtkStack` genuinely has no `gtksourceview` package or typelib. What was never
done: `gtksourceview5` and its introspection data are ordinary nixpkgs
packages, addable to that list, after which the GtkSource binding would be
available and this gap would close. The comment documents the gap instead of
either closing it or opening a tracked follow-up — "for now" in spirit, even
though the literal phrase isn't there to grep for. This is the task's own
example of the pattern to watch for: a gap excused by prose rather than
tracked as work.

## 4. The existing `.reports/component-inventory.md` has already caught and corrected one of its own false claims — flagged here as a good sign, not a new issue

That document's 2026-11-07 section explicitly retracts an earlier claim in
the same file that `errands/lib/plugins.py` "is commented out at its only call
site upstream," after re-reading upstream and finding the claim false, and
separately flags its own "ShortcutsWindow is unusable" claim as needing
independent re-verification rather than being inherited silently. Both checked
in this audit: the plugins loader is now genuinely ported
(`lib/errands/plugins.rb`, wired from `application.rb`), and
`Gtk::ShortcutsWindow.new` does genuinely raise
(`TypeError: GtkWindow is not subtype of GtkShortcutsWindow`) in this binding,
confirming both of that document's conclusions. Recorded here because the
task explicitly asked to check whether gaps get excused rather than tracked,
and self-correcting a prior false claim, with the reasoning shown, is the
opposite failure mode from the ones above — worth distinguishing from them
rather than burying it in the same bucket.

## 5. No unit tests exist for any non-UI logic, and that absence is not stated anywhere as a limitation

`spec/` has zero spec files (verified: `0 examples, 0 failures` from a real
run). The `.po` parser, the CalDAV/Nextcloud providers, and the iCal
read/write round-trip have never been exercised by anything except, for the
parts the drive script happens to touch, the end-to-end driver — and the
translations engine, as established above, is touched by *nothing at all*,
not even indirectly, because the UI never calls it. "The drive script passes"
(when it does) is being asked to stand in for test coverage it does not
provide for code the UI doesn't reach. See `test-parity.md`.

## Verdict

`clean: true` is not warranted. Three independent, confirmed issues — a
runtime gate that doesn't reproduce, a dead-code localization layer presented
by its own docstring as real support, and an environment gap documented but
never fixed or tracked — plus zero unit-test coverage of non-UI logic.
