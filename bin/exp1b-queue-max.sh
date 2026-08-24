#!/usr/bin/env bash
# Same shape as exp1, with `queue: max` on the group.
#
# Claim under test: `queue: max` raises the pending limit from one to a hundred, so both queued
# runs survive the wait and run in turn.
set -Eeuo pipefail
cd "$(dirname "$0")"
# shellcheck source=lib.sh
source ./lib.sh

echo "expect: both q1 and q2 succeed, in dispatch order"

dispatch exp1b-holder.yaml h1
holder=$(run_id exp1b-holder.yaml h1)
wait_state "${holder}" in_progress >/dev/null

dispatch exp1b-queued.yaml q1
q1=$(run_id exp1b-queued.yaml q1)
sleep 20
dispatch exp1b-queued.yaml q2
q2=$(run_id exp1b-queued.yaml q2)

wait_done "${holder}" "${q1}" "${q2}"
report "holder:${holder}" "q1:${q1}" "q2:${q2}"
