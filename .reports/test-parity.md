# Errands-rb — test parity (2026-11-08)

## Is every upstream test ported?

Upstream (`origin/main`) still has **no test suite at all** —
`git ls-tree -r --name-only origin/main | grep -i test` returns nothing, no
`tests/` directory, no `*_test.py`, no pytest config. So "0 upstream tests, 0
ported" remains a true, not a hollow, statement on this axis.

## Does the port have its own test suite, and does it run?

`spec/` still contains zero `*_spec.rb` files (`spec/spec_helper.rb` and
`spec/README.md` only). Ran it for real, in the dev shell, today:

```
ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
→ NOTE: kettle-test isn't installed; running with plain RSpec.
→ No examples found.
→ 0 examples, 0 failures
```

Unchanged from the prior audit. There are still no unit tests for the CalDAV
provider, the Nextcloud provider, the iCal (VTODO) read/write round-trip in
`data.rb`, the `.po` parser in `translations.rb`, or settings persistence.
All of this logic is exercised, if at all, only indirectly through the
end-to-end drive script below — and per `translation-parity.md`,
`translations.rb` is exercised by *nothing*, not even that, because no
production code calls it.

## The integration driver — this round's gate reproduces

Previous audit (2026-11-07) found the stated gate (140/140, 51 components)
did **not** reproduce: three runs of `test/drive_main_window.rb` all failed
one check (`widget is hidden`, in the "trashed task is hidden" step), scoring
139/140.

Re-ran `xvfb-run -a ruby test/drive_main_window.rb` in the dev shell twice on
today's `HEAD` (`4beb4696`):

```
165 of 165 checks passed
DRIVE OK
```

Identical both times, and the specific step that failed last round now
passes cleanly:

```
[51] the trashed task is hidden and marked
    ok   record is trashed
    ok   widget is hidden
```

This round's stated gate (`drive_ok=true, 165 checks passed, 0 failed, 34
components`) **reproduces** for the check-count portion. This is the
opposite of last round's finding and is recorded here plainly: the false
green from 2026-11-07 is fixed, not just re-asserted.

**One part of the gate is not independently verifiable from the drive
output, and is flagged for that reason, not because it is known wrong:**
nothing in `test/drive_main_window.rb`'s output — not a log line, not a
summary — states a "components" count. `grep -n -i component test/*.rb` and
a full capture of the run's stdout both come back with zero occurrences of
the word. "34 components" is therefore an externally-asserted number this
audit could not tie to anything the suite itself prints, the same shape of
problem as last round's untraceable "51 components" (which was also never
grounded in the script's own output). The 165/165 count is verified; the
34-components count is not, and should not be repeated as verified until
something in the harness actually emits it.

## What "ran" actually means here, now

165 real, executed, currently-passing checks across 73 `step`s, reproduced on
two independent runs today. This is a genuine, load-bearing, green integration
suite — stronger than last round's state, and the specific regression flagged
last time (`task.root.reveal_child?` not reflecting the trashed state) has
been fixed in the window/task code, not papered over in the test.

## Gap not caught by either suite (unchanged)

Nothing in `spec/` or `test/drive_main_window.rb` exercises the CalDAV/
Nextcloud sync providers against a real or fake server — the drive script is
confined to local window/data flow, GOA's nil-safe lookup with no account
configured, and the notifications daemon against fabricated data. Sync
provider logic (`caldav_provider.rb`, `nextcloud_provider.rb`) remains
unverified by anything that runs.

## A labeling mismatch inside a passing check (new this round)

`test/drive_main_window.rb` step `[70]`, titled *"typing a password stores it
in the secret backend for that provider"*, passes — but what it actually
exercises is `Errands::Settings.set_secret`, which (by `settings.rb`'s own
comment) writes the password into the same plaintext JSON file as every other
setting, not a Secret Service / libsecret backend. The check itself is
correct (the value is stored and read back), but its name describes a
security property — "the secret backend" — the implementation does not have.
A reader skimming green drive output would reasonably conclude the sync
password is protected the way upstream protects it (via libsecret); it is
not. See `component-parity.md` and `accountability-ensurance.md` for the
underlying gap this test name is glossing over.
