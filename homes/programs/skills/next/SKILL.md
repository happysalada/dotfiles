---
name: next
description: Use when asked what to do next - "what are the next todos", "what's left", "what should I work on", "what is worth doing here". Inventories the outstanding work in the conversation, the task list, the repository and its notes, drops what is done or abandoned, and returns a short list ordered by value to the end user rather than by what is easy or interesting for the agent.
---

# Next

The answer is a list. Do not start the work in this turn: the value of the
skill is the ranking, and an agent that begins implementing the first plausible
item has answered a different question.

## Collect

Look where work is recorded, not where it is easy to look:

- the conversation: anything the user asked for and did not see finished,
  including asides ("we should also...") and anything they deferred
- the task list of this session, and the plan document it came from
- the repository's own record: TODO, FIXME, XXX and HACK comments; "not
  implemented" and "unsupported" branches in code and help text; README or docs
  sections that say a feature is missing or planned
- version control: uncommitted changes, bookmarks or branches ahead of the
  default one, stashes, a merged change whose tests or docs were left behind
- recorded follow-ups: what this session noted as deferred, plus the project's
  issue tracker if the repository names one

## Drop

Before ranking, remove:

- work already done, including the version done differently than planned
- work the user rejected, or left behind deliberately
- work blocked outside this repository - list those separately, with what they
  wait on
- cleanup with no user-visible effect that nobody asked for

## Rank by value to the end user

Top-down:

| rank | what it is |
| --- | --- |
| 1 | something that is broken or wrong for the user right now |
| 2 | something the user asked for and does not have yet |
| 3 | work that unblocks other work |
| 4 | a user-visible improvement nobody has asked for yet |
| 5 | robustness, performance, internal correctness |
| 6 | polish: wording, layout, docs, refactors |

Cost only breaks ties: a cheap rank-5 does not come before an expensive
rank-2. A priority the user stated outranks this table - quote it and put it
first.

## Answer

At most five items. Each is an outcome rather than a task name, plus three
fields:

```
1. <outcome the user ends up with>
   value: <what they get, one clause>
   size: S | M | L        unblocks: <what, or ->
```

Then:

- **blocked** - one line each, with what it waits on
- **ruled out** - one line each for what was dropped above, so the inventory is
  visible and can be corrected
- **inferred** - anything found by reading rather than recorded by the user,
  marked as such; a priority the user never stated must not look like theirs

Close with the single next action and one sentence offering to take it. Stop
there.
