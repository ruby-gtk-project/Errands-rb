# Errands-rb — component parity (2026-11-07)

Adversarial pass: does every upstream window, dialog, page, menu item,
keyboard shortcut, preference, action, empty state and error state exist in
the port, and behave the same? Verdict per area, not a restatement of the
file-level inventory already in `.reports/component-inventory.md`.

## Windows / pages — PASS, with one caveat

Main window, sidebar, Today/Tags/Trash pages, task list, task row, task
toolbar and its sub-dialogs (datetime, attachments, notes, import) all have a
`lib/errands/*.rb` counterpart, confirmed present and structurally matching by
spot-reading (see component-identification-audit.md). The caveat is the notes
editor: it is present and behaves like a text editor, but **does not behave
like upstream's** — no markdown syntax highlighting, no line numbers, no
dark-mode-aware colour scheme. A user opening a task's notes sees a different,
lesser widget than upstream, even though "a notes dialog exists" is true.
Treat `errands/notes_dialog.rb` as **partial**, not done.

## Dialogs — PASS

About, add/rename list, confirm (delete list/task/all-completed), attachments,
datetime, import, preferences, shortcuts all exist. `shortcuts_dialog.rb`
substitutes `Adw::ShortcutsDialog` for upstream's `Gtk.ShortcutsWindow` built
from `data/resources/gtk/help-overlay.ui`; verified in this pass that
`Gtk::ShortcutsWindow.new` genuinely raises in this binding
(`TypeError: GtkWindow is not subtype of GtkShortcutsWindow`), so the
substitution is a real constraint, not an excuse. Need to verify the
substitute dialog actually lists every shortcut group/shortcut from
`help-overlay.ui` — spot-checked the counts (upstream scan: 4 `ShortcutsGroup`,
7 `ShortcutsShortcut`) and did not do a line-by-line accelerator diff in this
pass; that is a residual gap in this audit, not a stated finding against the
port.

## Preferences — PASS structurally

Every row from `errands/widgets/preferences.py` has a counterpart in
`lib/errands/preferences_dialog.rb`: theme radio rows (System/Light/Dark),
new-task-position combo, notifications/background/launch-on-startup switches,
sync provider combo, server URL / username / password rows, test-connection
row and button. Confirmed by direct line-by-line read of both files.

## Actions, menus and keyboard shortcuts — not independently re-audited this pass

The existing `component-inventory.md` tracks these per-unit already. This
pass did not re-derive the action/shortcut tables from scratch; treat that
material as carried over, not re-verified.

## Empty states — spot-checked, PASS

The drive script (`test/drive_main_window.rb`) explicitly exercises and
asserts on empty states: "the empty-state page is shown" (attachments dialog,
no attachments yet), "the status page is back" (trash emptied), "the app is
back to its empty state" / "status page is showing" (last list deleted). These
pass in the current drive run (see `test-parity.md`), so the empty-state
behaviour is both present and runtime-verified, which is stronger evidence
than a static read.

## Error states — one real, load-bearing finding

The drive run **fails** a check: `[49] the trashed task is hidden and marked`
→ `FAIL widget is hidden` (`!task.root.reveal_child?` is false right after
`task.delete`). Reproduced on three consecutive runs — not a one-off flake.
This means the task row's revealer is not collapsed by the point the drive
script asserts it, which is either a real UI regression (the row visually
still shows after being trashed) or a test timing bug (the revealer's
transition is asynchronous and the check runs before GTK processes it). Either
way, it is a live, reproducible mismatch between "trash a task" behaving the
way upstream's trash flow does and what this port currently does, and it
directly contradicts the runtime gate figure quoted for this round
(140/140, 0 failed). See `test-parity.md` and `accountability-ensurance.md`.

## Translation of component text — see translation-parity.md

Every title/label checked above (`'System'`, `'Test Connection'`, `'Show
Notifications'`, etc. in `preferences_dialog.rb`; equivalent literals
throughout the other widget files) is a bare Ruby string literal, not run
through any gettext call. The component *exists* and the *text* is right for
English, but the component does not behave the same as upstream for any
non-English locale — upstream's `_("...")` calls resolve through gettext at
runtime; the port's identical-looking strings never do. This is a parity gap
on every single translatable component in the app, detailed in
`translation-parity.md`.

## Bottom line

Structural existence of components: strong (23+ of the upstream's major units
mapped, confirmed by direct reading). Behavioural parity: two confirmed real
gaps (notes editor syntax highlighting; the trash-reveal failure) and one
systemic gap that touches every component with visible text (no localization
actually wired). `clean: true` is not warranted.
