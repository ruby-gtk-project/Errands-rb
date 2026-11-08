# Errands-rb — component-identification audit (2026-11-08)

This supersedes nothing in `.reports/component-inventory.md` (still the
primary per-file inventory, last substantively updated 2026-11-07) or the
2026-11-07 version of this file; it re-verifies the open items against
today's `HEAD` (`4beb4696`) and adds one newly-identified component-identity
issue the prior passes did not name explicitly.

## What changed in the tree since the 2026-11-07 pass

`git log --oneline ceb3d6e8..HEAD`: ashpd Background-portal wiring and its
drive test, a dedicated "inventory upstream components" commit (the
`component-inventory.md` content read below), two shortcuts added to
`shortcuts_dialog.rb` (Preferences, Sync), and a drive-harness extension
covering the preferences theme/sync page and the import path. None of these
touch `translations.rb` or its call sites.

## Re-verified: the notes editor identity gap still stands

`lib/errands/notes_dialog.rb` still builds `Gtk::TextView`/`Gtk::TextBuffer`
in place of upstream's `GtkSource.View`/`GtkSource.Buffer` bound to a
dark-aware `GtkSource.StyleSchemeManager` and a markdown
`GtkSource.LanguageManager`. `flake.nix`'s `gtkStack` still has no
`gtksourceview` package or typelib (checked today, line-for-line against the
list used in the 2026-11-07 pass — unchanged). Same conclusion: real
environment gap, fixable by adding `gtksourceview5` to the flake, never done.

## Re-verified: the shortcuts-dialog substitution, now with two added entries

`Adwaita::ShortcutsDialog` (used because `Gtk::ShortcutsWindow.new` still
raises `TypeError: GtkWindow is not subtype of GtkShortcutsWindow` — checked
today in the dev shell) now carries 3 groups / 6 shortcuts (General ×3, Lists
×2, Sync ×1 — Preferences and the second Sync accelerator were added since
the last pass). Diffed directly against upstream's
`data/resources/gtk/help-overlay.ui` (4 groups / 7 shortcuts: General ×3,
Sync ×1, Lists ×2, Details ×1):

- General, Lists and Sync groups now match upstream shortcut-for-shortcut
  (`<Control>comma` Preferences was missing last pass and is now present;
  `F5 <Control>f` vs upstream's single `<Control>F` is a deliberate,
  commented choice carried over, not a new drift).
- The **Details** group (`F9` "Toggle Details") is still absent. Checked
  upstream's `window.py` again today for any "detail"/"F9"/"toggle" text:
  zero matches. The accelerator in `help-overlay.ui` does not correspond to
  any action, panel or callback that exists anywhere in upstream's own
  source. This is an upstream dead/aspirational UI entry, not a port gap —
  confirmed independently this round, same conclusion as before, now with
  the full grep shown rather than asserted.

So the shortcuts dialog is at full, verified parity with upstream's actually
*implemented* shortcuts (6 of 6 real ones), and the one upstream entry still
missing corresponds to a feature upstream itself never built behind that UI.

## New this round: the sync-password storage is a silent component-identity substitution, not just a "blocker" footnote

`component-inventory.md` lists "`Secret` typelib is not in the dev shell" as
blocker #2 (written 2026-11-02) and separately credits `settings.rb` with
"the libsecret-backed `get_secret`/`set_secret`" in its support-module table
(line 569) — those two statements are now in tension with what the code
actually does. Read `lib/errands/settings.rb` today: `get_secret`/`set_secret`
write the password into the same plaintext JSON file as every other setting,
by the module's own comment ("the password lives in that same file under its
own key rather than introducing a second, half-faked storage mechanism").

This is a legitimate, honestly-commented engineering choice given the
constraint — but it means the *identity* of this component has changed from
upstream's (a Secret-Service-backed credential store) to something with a
materially different security property (plaintext-on-disk), and no report
before this one states that plainly as a behavioural difference rather than
an environment blocker still pending. `component-inventory.md`'s own support
table still describes the port's version as "libsecret-backed," which is no
longer an accurate description of what ships. See `component-parity.md` and
`accountability-ensurance.md` for the parity and accountability framing of
this same finding.

## Scope not re-covered here

Full per-file widget/CSS/signal tables for the ~30 ported units remain in
`component-inventory.md`, last rebuilt 2026-11-07 and not re-scanned from
scratch in this pass; this pass's job was to chase the open items forward,
not redo the base inventory, which no commit since 2026-11-07 invalidates.
