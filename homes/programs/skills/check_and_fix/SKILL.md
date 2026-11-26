---
name: check_and_fix
description: Use at the end of a change, before saying a task is done, and when asked to check that everything is as expected and there are no follow-up fixes. Audits the claim against the actual state - build, tests, the user-facing path, the whole diff, the deployed system - fixes what it finds, re-checks each fix, and reports what changed plus anything left over.
---

# Check and fix

The deliverable is a clean check pass: find what is wrong, fix it, prove the fix
with the check that found it, and say what happened. Only what cannot be fixed
here - a decision that is the user's, a dependency outside this tree - is left
as a follow-up.

## Say what "expected" is

Before looking, write the claim down in one or two lines: what the change was
supposed to do, for whom, and where it should be visible. A pass without a
claim compares the tree to nothing.

Take it from the request that started the work and from the diff - not from the
summary written at the end, which is the thing under test.

## Check, and record before fixing

Work top to bottom and note each finding as it appears; do not fix while
scanning, or the report cannot say what was actually wrong. When a layer fails,
say where you stopped and why.

| layer | check | evidence |
| --- | --- | --- |
| builds | the project's own build or eval of what changed | command and result |
| tests | the focused tests for the touched area, not the whole suite by reflex | command and result |
| behaviour | run the thing the way the user will: start it, call it, open it | actual output or status |
| diff | read all of it: only the intended change; no debug prints, scratch files, unrelated rewrites or leftovers | file list |
| consistency | comments, docs, help text and config examples still true; no stale mention of the old name or behaviour | search for the old name |
| deployment | if it only takes effect when applied, was it applied? a built store path is not a switched system | the running version, not the built one |

"Tests pass" is not "it works", and "it evaluates" is not "it runs". The
behaviour layer is the one that catches what the others miss.

## Fix

One finding at a time, each proven by the check that found it:

- **Fix the smallest thing that clears the finding.** Opportunistic refactors,
  renames and cleanups are not fixes; they belong in the next list, not this
  pass.
- **Re-run the failing check**, not the whole table, and record the result
  beside the finding it clears. A fix nobody re-checked is a new claim, not a
  repair.
- **Order cheap and safe before broad**: stale docs and leftovers before
  behaviour, behaviour before structure.
- **Leave anything that needs a decision** - scope, data, secrets, a public
  interface, a destructive step - as a follow-up, with the reason. Do not take
  it on the user's behalf.
- **Stop and report** when a fix reveals a design problem or the fix is larger
  than the change being checked. A check pass that grows into a rewrite has
  stopped being one.
- **Do not commit, stage or push** unless asked: leave the tree for the user to
  review.

Repeat until a full pass is clean or only the decision-shaped items remain.

## Report

One verdict:

- **checked and fixed** - every layer clean, findings listed with the fix and
  the check that proves it
- **checked, fixed, with follow-ups** - clean except the items below
- **not fixed** - a finding that could not be cleared; name the layer and why

Then, per finding:

```
1. <what was wrong> - <where> - fixed: <what changed> - re-checked: <command, result>
```

And for what is left:

```
- <what remains> - <why it was not fixed here> - blocker: yes | no
```

Close with the sentence this skill exists for, and only when it is true after a
full clean pass:

> No follow-up fixes: <the layers checked>.

An empty list written without re-running the checks is the failure this skill
exists to prevent.

## Boundary

`verification-before-completion` is the habit of checking before claiming one
item done. This skill is the audit at the end of the work, and it repairs what
it finds. Both apply: that one per task, this one per change.
