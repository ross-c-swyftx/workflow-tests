#!/usr/bin/env bash
# Does a job awaiting environment approval hold its concurrency group?
#
# Claim under test: the group is held for the whole approval wait, so an apply gated on a required
# reviewer blocks everything else in that group for as long as the review takes. `exp1` already
# showed that a *running* job blocks a follower; the question here is whether a job merely parked
# on an approval, consuming no runner, does the same.
#
# The follower's start time against the approval time is the measurement.
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

echo "expect: gated parks in 'waiting', follower stays queued and starts only after approval"

dispatch exp2-gated.yaml g1
gated=$(run_id exp2-gated.yaml g1)
wait_state "${gated}" waiting >/dev/null

dispatch exp2-follower.yaml f1
follower=$(run_id exp2-follower.yaml f1)
sleep 40
echo
echo "with the gate still unapproved:"
report "gated:${gated}" "follower:${follower}"

approved_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
env_id=$(gh api "repos/${REPO}/actions/runs/${gated}/pending_deployments" --jq '.[0].environment.id')
gh api -X POST "repos/${REPO}/actions/runs/${gated}/pending_deployments" \
  -f "environment_ids[]=${env_id}" -f state=approved -f comment=exp2 >/dev/null
echo
echo "approved at ${approved_at}"

wait_done "${gated}" "${follower}"
echo
gh run view "${follower}" --repo "${REPO}" --json startedAt,updatedAt,conclusion \
  --jq '"follower started \(.startedAt), ended \(.updatedAt), \(.conclusion)"'
echo "if that start time is after the approval, the waiting job was holding the group."
