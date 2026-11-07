# Errands-rb — test parity (2026-11-07)

## Is every upstream test ported?

Upstream (`origin/main`) has **no test suite at all** — `git ls-tree -r
--name-only origin/main | grep -i test` returns nothing, no `tests/` directory,
no `*_test.py`, no pytest config. So there is nothing to port on that axis,
and "0 upstream tests, 0 ported" is a true, not a hollow, statement.

## Does the port have its own test suite, and does it run?

`spec/` exists (`spec/spec_helper.rb`, `spec/README.md` describing
`kettle-test` harness helpers) but **contains zero `*_spec.rb` files.**
Ran it for real, in the dev shell:

```
ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
→ NOTE: kettle-test isn't installed; running with plain RSpec.
→ No examples found.
→ 0 examples, 0 failures
```

So the "run the specs" command the dev shell banner advertises executes
successfully and reports 0/0 — this is not a broken suite, it is an **empty**
one. There are no unit tests for anything in `lib/`: no tests for the CalDAV
provider, the Nextcloud provider, the iCal (VTODO) read/write round-trip in
`data.rb`, the gettext-style `.po` parser in `translations.rb`, settings
persistence, or any pure-Ruby logic. All of that logic is exercised, if at
all, only indirectly through the end-to-end drive script below. A `.po` parser
handling msgctxt, plural forms, continuation lines and C escapes (205 lines,
`translations.rb`) with zero unit tests is exactly the kind of code most
likely to have an edge-case bug that only an integration run would catch —
and as the translation-parity report shows, in this case the integration
point (the UI actually calling it) does not exist either, so this code has
**never been exercised by anything, ever.**

## The integration driver — ran it, does not currently pass clean

`test/drive_main_window.rb`, run three times in the dev shell with
`xvfb-run -a ruby test/drive_main_window.rb`:

```
139 of 140 checks passed
  failed check: widget is hidden
DRIVE FAILED (1)
```

Identical result on all three runs (same step, same check, same count). This
directly **contradicts** the round's stated runtime gate
(`drive_ok=true, 140 checks passed, 0 failed, 51 components`). Whatever
produced that figure either ran against a different commit, ran in a
different environment that happened not to expose this, or the figure is
stale. As it stands right now, on `HEAD` of `ruby`
(`ceb3d6e8 Fix spec suite load errors...`), the drive does **not** reach
140/140.

The failing check, in `test/drive_main_window.rb`:

```ruby
d.step('the trashed task is hidden and marked') do
  d.check('record is trashed') { Errands::UserData.tasks.find { |t| t.text == 'Bread' }.trash }
  task = application.window.sidebar.rows.first.task_list.tasks.find { |t| t.task_data.text == 'Bread' }
  d.check('widget is hidden') { !task.root.reveal_child? }
  d.shot('13-trashed')
end
```

`record is trashed` passes; `widget is hidden` fails, meaning
`task.root.reveal_child?` is still true immediately after `task.delete`. Two
explanations, not distinguished in this pass:

1. **A real regression**: the task row's `Gtk::Revealer` isn't being told to
   collapse when a task is trashed (as opposed to deleted/restored, which the
   surrounding steps #51/#54 do check and pass for the *trash page's* list,
   not this specific row's revealer).
2. **A test-timing bug**: `reveal_child = false` is set but GTK's revealer
   state (and `reveal_child?`, depending on what it actually reflects —
   the requested value vs. the realized state) needs a main-loop iteration
   before the read reflects it, and the driver doesn't pump the loop between
   the trash action and this assertion.

Either way: this is a genuine, reproducible, currently-red check, not a flake
that passed on retry, and it belongs on the open-gaps list, not behind a
"140/140" claim.

## What "ran" actually means here

Covering 51 components with 140 checks is a reasonable claim about breadth
*if* 140/140 pass. With 139/140 passing on every run attempted in this audit,
the honest statement is: **139 real, executed, currently-passing checks, plus
one real, executed, currently-failing check.** A drive suite that fails on
every run is not "mostly green" — per this task's own framing, a failed or
narrow drive run is a parity gap in its own right.

## Gap not caught by either suite

Nothing in `spec/` or `test/drive_main_window.rb` exercises the CalDAV/
Nextcloud sync providers against anything (no fake server, no recorded
fixtures) — the drive script is confined to the local window/data flow (it
does check that GOA returns nil safely with no account configured, and that
the notifications daemon logic works against fabricated task data, which is
good coverage of what it does cover). Sync-provider logic
(`caldav_provider.rb`, `nextcloud_provider.rb`) is unverified by anything
that runs.
