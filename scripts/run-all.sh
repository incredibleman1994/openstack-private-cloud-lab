#!/usr/bin/env bash
# Run the whole lab end to end (labs 02-06).
# Steps 01-05 are idempotent. Step 06 formats a volume, so run it once; use 99-cleanup.sh to reset.
set -eo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
for s in health-check.sh 01-keystone-setup.sh 02-glance-images.sh 03-nova-flavors.sh \
         04-neutron-network.sh 05-launch-instances.sh 06-cinder-volume.sh; do
  printf '\n\033[1;35m########## %s ##########\033[0m\n' "$s"
  bash "$DIR/$s"
done
printf '\n\033[1;32mLab complete.\033[0m Open Horizon -> Project -> Network -> Network Topology for a visual.\n'
