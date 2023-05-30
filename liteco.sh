#!/bin/sh

UTILDIR="$(dirname "$(readlink -f "$0")")"

CONTDIR="$(readlink -f "$UTILDIR/.")"
STATUSDIR="/tmp/containerlite_status"
RUNPREFIX="$STATUSDIR/running_"

runin(){

  CONTNAME="$1"
  shift
  
  if [ "$CONTNAME" = "" ] ; then
    echo "unknown container '$CONTNAME'" 1>&2
    exit 13
  fi
  
  ROOTFS="$CONTDIR/$CONTNAME"
  cd "$ROOTFS"
  
  bwrap \
    \
    --cap-add ALL \
    --uid 0 \
    --gid 0 \
    --as-pid-1 \
    --unshare-pid \
    --unshare-ipc \
    --unshare-user \
    --unshare-uts \
    \
    --bind "$ROOTFS"/ / \
    --bind "$CONTDIR/share"/ /share \
    --dev /dev \
    --tmpfs /run \
    --tmpfs /tmp \
    --tmpfs /var/www/html \
    --tmpfs /var/log/httpd \
    --bind /sys /sys \
    --proc /proc \
    --tmpfs /dev/shm \
    --bind /sys /sys \
    \
    --chdir / \
    --setenv HOME /root \
    \
    "$@"
}

#  /usr/lib/systemd/systemd --system
#  --remount-ro / \
#  --tmpfs /var \
#  --unshare-net \
#  --hostname "$CONTNAME" \
#  --bind "$ROOTFS"/etc /etc \
#  --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
#  --setenv TERM xterm \
#  --setenv container docker  \
#  --mqueue /dev/mqueue \
#  --dev-bind /dev/tty /dev/tty \
#  --sys /sys  \
#  --no-reaper \
#  --ro-bind /sys/fs/cgroup /sys/fs/cgroup \
#  --bind /sys/fs/cgroup/systemd /sys/fs/cgroup/systemd \
#  --ro-bind /sys/fs/cgroup/cpuset /sys/fs/cgroup/cpuset \
#  --ro-bind /sys/fs/cgroup/hugetlb /sys/fs/cgroup/hugetlb \
#  --ro-bind /sys/fs/cgroup/devices /sys/fs/cgroup/devices \
#  --ro-bind /sys/fs/cgroup/cpu,cpuacct /sys/fs/cgroup/cpu,cpuacct \
#  --ro-bind /sys/fs/cgroup/freezer /sys/fs/cgroup/freezer \
#  --ro-bind /sys/fs/cgroup/pids /sys/fs/cgroup/pids \
#  --ro-bind /sys/fs/cgroup/blkio /sys/fs/cgroup/blkio \
#  --ro-bind /sys/fs/cgroup/net_cls,net_prio /sys/fs/cgroup/net_cls,net_prio \
#  --ro-bind /sys/fs/cgroup/perf_event /sys/fs/cgroup/perf_event \
#  --ro-bind /sys/fs/cgroup/memory /sys/fs/cgroup/memory \
#  --bind /sys/fs/cgroup/systemd /sys/fs/cgroup/systemd  \

rerun(){
  while [ -f "$RUNFILE" ]; do
    runin "$CONTNAME" "$CMDLIN"
    sleep 3
  done
}
  
startas(){

  CONTNAME="$1"
  shift
  CMDLIN="$@"
  
  RUNFILE="$RUNPREFIX${CONTNAME%/}"
  
  echo "container: $CONTNAME / args: $CMDLIN"
  
  mkdir -p "$STATUSDIR"
  touch "$RUNFILE"
  
  rerun&
  MAINPID="$!"
  
  inotifywait -e delete "$RUNFILE"
  
  children_reco() {
    for ppid in $@ ; do
      if [ ! -z "$(ps -o pid= --pid $ppid)" ] ; then # check parent still exists
        PIDS="$PIDS $ppid" # add parent to the list
        local PART=$(ps -o pid= --ppid "$ppid") # find all the children
        for pid in $PART ; do # loop on every child
          children_reco "$pid" # recurse find children
        done
      fi
    done
  }
  process_tree(){
    PIDS=""
    children_reco $@
  }
  
  process_tree $MAINPID
  echo "interrupting $PIDS"
  kill $PIDS

  sleep 3

  process_tree $PIDS
  echo "killing $PIDS"
  kill -09 $PIDS
}

stopit(){

  CONTNAME="$1"
  
  RUNFILE="$RUNPREFIX$CONTNAME"
  
  if [ "$CONTNAME" = "all" ] ; then
    rm -f "$RUNPREFIX"*
  else
    if [ -f "$RUNFILE" ] ; then
      rm -f "$RUNFILE"
    else
      echo "no container '$CONTNAME' found ($RUNFILE)" 1>&2
    fi
  fi

}

SUBCMD="$1"
shift
if   [ "run" = "$SUBCMD" ] ; then
  runin $@
elif [ "go" = "$SUBCMD" ] ; then
  startas $@
elif [ "stop" = "$SUBCMD" ] ; then
  stopit $@
else
  echo "unknown command $SUBCMD" 1>&2
  exit 13
fi

