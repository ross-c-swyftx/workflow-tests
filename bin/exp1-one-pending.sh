#!/usr/bin/env bash
# Does a group hold more than one pending run?
#
# Claim under test: GitHub allows exactly one pending run per concurrency group, and a newly
# queued run cancels the one already pending. `cancel-in-progress: false` is set on every job
# here, so if the claim is wrong nothing should be cancelled.
set -Eeuo pipefail
cd "$(dirname "$0")"
# shellcheck source=lib.sh
source ./lib.sh

echo "expect: q1 cancelled without ever starting, q2 success after the holder finishes"

dispatch exp1-holder.yaml h1
holder=$(run_id exp1-holder.yaml h1)
wait_state "${holder}" in_progress >/dev/null

dispatch exp1-queued.yaml q1
q1=$(run_id exp1-queued.yaml q1)
sleep 20
dispatch exp1-queued.yaml q2
q2=$(run_id exp1-queued.yaml q2)

wait_done "${holder}" "${q1}" "${q2}"
report "holder:${holder}" "q1:${q1}" "q2:${q2}"
