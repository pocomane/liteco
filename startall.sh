#!/bin/sh

UTILDIR=$(dirname "$(readlink -f "$0")")

"$UTILDIR"/liteco.sh go container_webdav_001 /run/sh &
#"$UTILDIR"/liteco.sh go debian_container /opt/myweb.sh &
"$UTILDIR"/liteco.sh go arch_container_018 /opt/supid_bot.sh &
# bla bla

wait $(jobs -p)

