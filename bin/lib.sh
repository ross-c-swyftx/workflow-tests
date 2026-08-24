# shellcheck shell=bash
REPO=ross-c-swyftx/workflow-tests

dispatch() { # dispatch <workflow-file> <tag> [-f k=v ...]
  local wf=$1 tag=$2; shift 2
  gh workflow run "$wf" --repo "$REPO" -f tag="$tag" "$@" >/dev/null
}

run_id() { # run_id <workflow-file> <tag> - poll until the dispatched run appears
  local wf=$1 tag=$2 id=""
  for _ in $(seq 1 40); do
    id=$(gh run list --repo "$REPO" --workflow "$wf" --limit 20 \
      --json databaseId,displayTitle \
      --jq ".[] | select(.displayTitle | endswith(\" ${tag}\")) | .databaseId" | head -1)
    [ -n "${id}" ] && { echo "${id}"; return 0; }
    sleep 3
  done
  echo "no run appeared for ${wf} ${tag}" >&2
  return 1
}

state() { # state <run-id> -> status/conclusion
  gh run view "$1" --repo "$REPO" --json status,conclusion \
    --jq '"\(.status)/\(.conclusion // "-")"'
}

wait_state() { # wait_state <run-id> <status prefix>
  local s=""
  for _ in $(seq 1 100); do
    s=$(state "$1")
    [ "${s%%/*}" = "$2" ] && { echo "$s"; return 0; }
    sleep 5
  done
  echo "timed out waiting for $2 on $1 (last ${s})" >&2
  return 1
}

wait_done() { # wait_done <run-id...>
  local id s
  for id in "$@"; do
    for _ in $(seq 1 150); do
      s=$(state "${id}")
      [ "${s%%/*}" = "completed" ] && break
      sleep 5
    done
  done
}

report() { # report <label:run-id ...>
  local pair
  echo
  printf '%-14s %-12s %s\n' LABEL RUN STATE
  for pair in "$@"; do
    printf '%-14s %-12s %s\n' "${pair%%:*}" "${pair#*:}" "$(state "${pair#*:}")"
  done
}
