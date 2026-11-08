# Errands-rb — component parity (2026-11-08)

Adversarial pass: does every upstream window, dialog, page, menu item,
keyboard shortcut, preference, action, empty state and error state exist in
the port, and behave the same? Re-verifies the 2026-11-07 verdict against
today's `HEAD` (`4beb4696`) rather than restating it unchecked.

## Windows / pages — PASS, with one caveat (unchanged)

Main window, sidebar, Today/Tags/Trash pages, task list, task row, task
toolbar and its sub-dialogs all still have a `lib/errands/*.rb` counterpart.
The notes editor caveat from last round stands, re-verified today: no
markdown syntax highlighting, no line numbers, no dark-mode-aware colour
scheme (`notes_dialog.rb` still builds plain `Gtk::TextView`). Still
**partial**, not done. See `component-identification-audit.md`.

## Dialogs — PASS, shortcuts dialog now more complete than last round

About, add/rename list, confirm, attachments, datetime, import,
preferences, shortcuts all exist. The outstanding item from last round —
"did not do a line-by-line accelerator diff" — is now done: the port's
`Adwaita::ShortcutsDialog` has 6 real shortcuts, all matching upstream's
`help-overlay.ui` (Preferences was added since last pass). Upstream's 7th
entry, "Toggle Details" (`F9`), corresponds to no action or panel anywhere in
upstream's own source (verified by grep against `origin/main`'s `window.py`
today) — an upstream dead UI entry, not a port gap. **This item is now fully
closed, not residual**, upgrading last round's "spot-checked, not diffed."

## Preferences — PASS structurally, with a new behavioural caveat on Sync

Every row from `errands/widgets/preferences.py` has a counterpart,
re-confirmed by direct read today. New finding this round: the sync
password field, while present and functional (drive step `[70]` passes,
value round-trips), is **not** backed by libsecret/Secret Service the way
upstream's is — `Settings.get_secret`/`set_secret` write it into the same
plaintext JSON file as every other setting. The row behaves the same from
the keyboard, but not the same with respect to where the credential ends up
on disk. See the security note below.

## Actions, menus and keyboard shortcuts — re-audited for shortcuts this round, rest still carried over

Shortcuts: fully diffed this round (see Dialogs, above). Actions and menus:
`component-inventory.md`'s per-unit tables were spot-read again but not
re-derived from scratch; same carried-over caveat as last report.

## Empty states — PASS (re-confirmed by today's drive run)

Drive run today (165/165) still exercises and passes every empty-state
check identified last round (no task lists, trash emptied, attachments
empty, back-to-empty-state after deleting the last list).

## Error states — the regression flagged last round is fixed

Last round's confirmed, reproducible failure — `[49]/[51] the trashed task
is hidden and marked` → `widget is hidden` failing on 3/3 runs — **no longer
fails.** Ran the drive twice today: 165/165 both times, including that exact
check passing (`ok widget is hidden`). This is a genuine fix to the
revealer-collapse behaviour (or its surrounding timing), not a re-assertion
of an old claim — it was independently re-run and re-checked in this audit,
not taken on trust from the commit log.

## New finding: a real security-relevant divergence, documented in passing but never surfaced as a behavioural gap

Upstream stores the sync password via GNOME's Secret Service (libsecret),
which is encrypted at rest and access-controlled by the desktop session. The
port stores it in plaintext in the same on-disk JSON file used for every
other preference (confirmed by reading `settings.rb` and its own comment
explaining the substitution). This was recorded as an *environment blocker*
("Secret typelib is not in the dev shell") in `component-inventory.md` back
on 2026-11-02 and never updated to reflect that the team shipped a plaintext
substitute instead of resolving the blocker — and no prior
`component-parity.md` stated this as a user-facing behavioural difference.
A user who sets a Nextcloud or CalDAV password in this port's Preferences
page gets a materially weaker security property than the same action in
upstream, with nothing in the UI, the settings, or (until this report) the
parity record saying so. This belongs on the open-gaps list as its own item,
not folded silently into "sync: PASS."

## Translation of component text — see translation-parity.md (unchanged)

Re-verified today: still 0 of 150 msgids wired to any UI string. Every label
checked is a bare literal. Unchanged from 2026-11-07.

## Bottom line

Two of last round's three open items are now closed with evidence (the
trash-reveal regression, fixed and re-verified; the shortcuts accelerator
diff, completed and clean). One (notes editor) is unchanged. One new,
real item is added (sync password storage is a silent security-relevant
substitution, not a resolved blocker). The systemic translation gap is
unchanged and remains the largest single item. `clean: true` is not
warranted.
