#!/usr/bin/env bash
# Shared helpers for the lab scripts. Source this file; do not run it directly.

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../config/lab.env
source "$LAB_ROOT/config/lab.env"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- Authentication ---------------------------------------------------------
# DevStack's openrc exports OS_AUTH_URL etc. We load it once as admin, remember
# the admin password, then switch identity with auth_as.
load_openrc() {
  [[ -f "$DEVSTACK_DIR/openrc" ]] || die "DevStack not found at $DEVSTACK_DIR (set DEVSTACK_DIR)."
  command -v openstack >/dev/null || die "'openstack' CLI not found in PATH."
  set +eu
  # shellcheck disable=SC1091
  source "$DEVSTACK_DIR/openrc" admin admin >/dev/null 2>&1
  set -e
  [[ -n "${OS_AUTH_URL:-}" ]] || die "openrc did not export OS_AUTH_URL - is DevStack installed?"
  ADMIN_PW="$OS_PASSWORD"
}

auth_as() { # auth_as <user> <project> <password>
  export OS_USERNAME="$1" OS_PROJECT_NAME="$2" OS_PASSWORD="$3"
}
as_admin()  { auth_as admin "admin" "$ADMIN_PW"; }
as_lab()    { auth_as "$LAB_USER" "$LAB_PROJECT" "$LAB_PASSWORD"; }
as_reader() { auth_as "$LAB_READER" "$LAB_PROJECT" "$LAB_PASSWORD"; }

# ---- Small utilities --------------------------------------------------------
# exists <openstack args...>  ->  success if "openstack <args>" succeeds
# e.g.  exists network show lab-net || openstack network create lab-net
exists() { openstack "$@" >/dev/null 2>&1; }

# wait_for <description> <timeout-seconds> <command...>
wait_for() {
  local desc="$1" timeout="$2"; shift 2
  local end=$((SECONDS + timeout))
  until "$@" >/dev/null 2>&1; do
    (( SECONDS < end )) || die "Timed out after ${timeout}s waiting for: $desc"
    sleep 3
  done
}

volume_status_is()   { [[ "$(openstack volume show "$1" -f value -c status)" == "$2" ]]; }
snapshot_status_is() { [[ "$(openstack volume snapshot show "$1" -f value -c status)" == "$2" ]]; }

# First fixed IPv4 address of a server
server_ip() {
  openstack port list --server "$1" -f value -c "Fixed IP Addresses" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1
}

# Floating IP currently attached to a server (empty if none)
get_fip() {
  local port
  port="$(openstack port list --server "$1" -f value -c ID | head -n1)"
  [[ -n $port ]] || return 0
  openstack floating ip list --port "$port" -f value -c "Floating IP Address"
}

# Run a command inside a CirrOS instance over SSH
ssh_vm() { # ssh_vm <floating-ip> <command...>
  local ip="$1"; shift
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 -o LogLevel=ERROR "cirros@$ip" "$@"
}
