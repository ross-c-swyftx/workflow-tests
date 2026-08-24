#!/usr/bin/env bash
# Does a job awaiting environment approval hold its concurrency group?
#
# Claim under test: the group is held for the whole approval wait, so an apply gated on a required
# reviewer blocks everything else in that group for as long as the review takes. Needs the `gated`
# environment to have a required reviewer; without one the gated job runs immediately and the
# experiment proves nothing.
set -Eeuo pipefail
cd "$(dirname "$0")"
# shellcheck source=lib.sh
source ./lib.sh

reviewers=$(gh api "repos/${REPO}/environments/gated" \
  --jq '[.protection_rules[]? | select(.type == "required_reviewers")] | length' 2>/dev/null || echo 0)
if [ "${reviewers}" = "0" ]; then
  echo "the 'gated' environment has no required reviewer - nothing to wait on. Add one first." >&2
  exit 1
fi

echo "expect: gated sits in waiting, follower stays queued behind it and never starts"

dispatch exp2-gated.yaml g1
gated=$(run_id exp2-gated.yaml g1)
wait_state "${gated}" waiting >/dev/null

dispatch exp2-follower.yaml f1
follower=$(run_id exp2-follower.yaml f1)
sleep 30

report "gated:${gated}" "follower:${follower}"
echo
echo "approve or reject ${gated} in the browser, then re-read the follower:"
echo "  gh run view ${follower} --repo ${REPO}"
