# workflow-tests

A sandbox for settling GitHub Actions questions by running them rather than reading about them.
The workflows here do nothing real - they sleep and echo - so the only thing being measured is
Actions' own scheduling.

Everything is driven from `bin/`. Each script prints what it expects before it starts, so a run
either confirms the claim or contradicts it out loud.

    ./bin/exp1-one-pending.sh
    ./bin/exp1b-queue-max.sh
    ./bin/exp2-gated-apply.sh
    ./bin/exp3-group-expressions.sh

## What each one settles

**`exp1` - how many runs can be pending in a group.** A holder occupies group `exp1` for 150
seconds; two more runs are dispatched into the same group 20 seconds apart. Every job sets
`cancel-in-progress: false`. If GitHub keeps one pending slot per group, the first queued run is
cancelled without ever starting and the second succeeds.

**`exp1b` - whether `queue: max` lifts that limit.** Identical, with `queue: max` on the group.
Both queued runs should survive and run in turn.

**`exp2` - whether an environment gate holds the group while it waits.** `exp2-gated` has
`environment: gated` on the same job as the group, which is how the terragrunt apply is built. A
follower is dispatched into that group while the gated job waits for a reviewer. If the group is
held for the whole approval wait, the follower stays queued and never starts.

Needs the `gated` environment to carry a required reviewer; the script refuses to run without one,
because a gate nobody has to approve proves nothing. Required reviewers are only available on
private repositories under a paid plan, so this may need the repo made public.

**`exp3` - the group expressions as shipped.** Uses the strings verbatim from
`Swyftx/platform`'s `shared-terragrunt-plan.yaml`:

    group: tg-${{ github.event_name == 'pull_request' && github.ref || 'main' }}-units/unit-a
    cancel-in-progress: ${{ github.event_name == 'pull_request' }}

It opens two pull requests against the same "unit", pushes twice to the first, then pushes to
main, and prints the timings. Three things should be visible: the first PR's earlier plan
cancelled by its own second push, the two PRs' plans overlapping in time, and main's plan starting
only after main's apply of that unit finished.

## Housekeeping

`exp3` leaves branches and pull requests behind, on purpose, so the run can be read afterwards.
Delete them when you are done with them.
