
# Overview

Lite Container, liteco, is a extremely simple bash script to run containers. It
is mainly a wrapper for `bubblewrap`, that saves you to write log `bwrap`
commands. It also have some extremely light "Container management" features:
you can run a container in background, automatically restart, stop it, and
a minimal interface with `systemd`.

# Why

The main container solutions strongly focus on container administration, so
the tons of features they came with completely hide the core container
operation. Fortunately there are tools that try to do one thing and do it
well. `bwrap` just makes sandbox, nothing else. And using it you can be fully
aware of what is going on under the hood.

And it turn out that you need very litte more to have a productive and effective
container system. Just few `bash` script lines.

And maybe you can do also without them...

# Status

The "Code" is very immature. The "Documentation" is a raw draft.

# License

Public Domain. What else.

# Usage

To prepare the image, e.g. using Arch Linux:

```
pacman -S arch-install-scripts
mkdir container_pacman_amd64/
pacstrap container_pacman_amd64/ pacman
```

Minimal configuration:

```
echo 'nameserver 8.8.8.8' >> container_pacman_amd64/etc/resolv.conf
```

Clone the image:

```
cp -fR container_pacman_amd64 container_test_001
```

Run a contained shell:

```
./liteco.sh run container_test_001 sh
```

NOTE: the /opt/sandbox/share folder is shared between all the containers;
inside the container it is mounted on /shared

Install software (again, using Arch `pacman`):

```
./liteco.sh run container_test_001 pacman -S syncthing
```

The previous is the same of running `pacman -S syncthing` in a contained shell.
Remember to clear the downloaded packages with:

```
rm container_test_001/var/cache/pacman/pkg/*
```

Start a command in a container, restarting on close:

```
./liteco.sh go container_test_001 sleep 3
```

Stopping a container launched with `startas`:

```
./liteco.sh stop container_test_001
```

Starting all (list hardcoded in the script):

```
./startall.sh
```

Sopping all (dynamic list of all the container launched with `startas`):

```
./liteco.sh stop all
```

Systemd wrapper:

```
cp wrapper.service /etc/systemd/system/liteco.service
systemctl start liteco
journalctl --no-pager
systemctl stop liteco
systemctl enable liteco
```

