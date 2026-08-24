#!/usr/bin/env bash
# The real group expressions, on real pull requests and a real push to main.
#
# Claims under test, using the strings verbatim from shared-terragrunt-plan.yaml:
#   1. a second push to one PR cancels that PR's earlier plan
#   2. two PRs planning one unit do not touch each other
#   3. a plan on main queues behind an in-flight apply of that unit
set -Eeuo pipefail
cd "$(dirname "$0")"
# shellcheck source=lib.sh
source ./lib.sh

ROOT=$(git rev-parse --show-toplevel)
STAMP=$(date -u +%H%M%S)
A="exp3-a-${STAMP}"
B="exp3-b-${STAMP}"

bump() { # bump <branch> <text>
  echo "$2" >> "${ROOT}/units/unit-a.txt"
  git -C "${ROOT}" add units/unit-a.txt
  git -C "${ROOT}" commit -q -m "exp3: $2"
  git -C "${ROOT}" push -q -u origin "$1"
}

git -C "${ROOT}" checkout -q main && git -C "${ROOT}" pull -q

git -C "${ROOT}" checkout -q -b "${A}"
bump "${A}" "a1"
gh pr create --repo "${REPO}" --head "${A}" --base main \
  --title "exp3 ${A}" --body "concurrency experiment" >/dev/null
echo "PR A open on ${A}, waiting for its plan to start"
sleep 45

bump "${A}" "a2"
echo "second push on ${A} - PR A's first plan should be cancelled"

git -C "${ROOT}" checkout -q main
git -C "${ROOT}" checkout -q -b "${B}"
bump "${B}" "b1"
gh pr create --repo "${REPO}" --head "${B}" --base main \
  --title "exp3 ${B}" --body "concurrency experiment" >/dev/null
echo "PR B open on ${B} - its plan should run alongside PR A's second"

git -C "${ROOT}" checkout -q main
bump main "main1"
echo "pushed to main - its plan and apply share tg-main-units/unit-a"

echo "waiting for everything to settle"
sleep 240
echo
gh run list --repo "${REPO}" --workflow exp3-plan.yaml --limit 8 \
  --json displayTitle,conclusion,startedAt,updatedAt \
  --jq '.[] | "\(.conclusion // "-")  \(.startedAt) -> \(.updatedAt)  \(.displayTitle)"'
gh run list --repo "${REPO}" --workflow exp3-apply.yaml --limit 4 \
  --json displayTitle,conclusion,startedAt,updatedAt \
  --jq '.[] | "\(.conclusion // "-")  \(.startedAt) -> \(.updatedAt)  \(.displayTitle)"'
echo
echo "read it as: PR A's first plan cancelled, PR A's second and PR B's overlapping in time,"
echo "and main's plan starting only after main's apply finished."
