# An Opinionated Setup of a MAAS Dev Environment

## Goals of this project

To make the setup of a MAAS development environment super simple.
Think of this as a one click installer.

## Alternative: workshop + just setup (this branch)

This branch adds a [Workshop](https://snapcraft.io/workshop)-based setup
inspired by lxd-dev: the workshop is the control plane (edit, commit, run
agents), and the MAAS dev container is plain LXD infrastructure managed by
idempotent `just` recipes.

```sh
just setup            # workshop + LXD init + networks + profiles + container
just workshop-shell   # shell in the workshop, in the MAAS source
just vscode           # VS Code (Remote-SSH) in the workshop, in the MAAS source
just maas-shell       # SSH into the dev container (works on host and in the workshop)
just maas-bootstrap   # install & start MAAS inside the container (runs setup-region-via-ssh.bash)
just delete-maas-dev  # tear down container, profiles and networks
```

The MAAS checkout at `MAAS_SRC` (default `../maas`) is the single source
tree, bind-mounted into both environments:

* in the workshop at `/home/workshop/maas`: edit, run git and agents here.
  `just setup-workshop` remounts the `maas:maas-src` plug (declared on the
  in-project SDK in `.workshop/maas/`) to `MAAS_SRC`;
* in the dev container at `/work`: build and run MAAS here, e.g.
  `ssh maas-dev` from the workshop.

Edits made in the workshop are immediately visible in the container.

Configuration stays in `config.sh` (shared with `setup-dev-env.sh`); every
variable can also be overridden from the environment. Network, profile and
container names default to the same values the shell script uses
(`maas-ctrl`, `maas-kvm`, `maas-dev`, `maas-machine`), so the recipes are
no-ops on a machine already set up by the script.

Notes:

* `MAAS_CONTROL_NETWORK`/`MAAS_MANAGEMENT_NETWORK` from `config.sh` were dead
  config (the shell script hardcodes `maas-ctrl`/`maas-kvm`); they are replaced
  by `MAAS_CTRL_NETWORK`/`MAAS_KVM_NETWORK` defaulting to the real names.
* The container SSH key lives in `.state/ssh/maas_dev_key` and the container
  IP in `.state/maas-dev-ip` (both gitignored). `just workshop-ssh` (run by
  `setup-workshop` and `create-maas-dev`) writes an ssh config stanza inside
  the workshop so `ssh maas-dev` works there; a workshop refresh resets
  `~/.ssh`, so re-run it after refreshing by hand.
* `just maas-bootstrap` expects the MAAS source prepared like the shell script
  does (checked out at `MAAS_SRC`, snap tree built) and is not part of
  `just setup`.
* Host package installation, UFW and libvirt setup from `setup-dev-env.sh`
  are not covered by the recipes; run the script with the relevant skip flags
  if you need them.

## Requirements

* Ubuntu (maybe Debian)
* `sudo` and the ability to run commands as root
* To use MAAS a decent amount of RAM would be good (> 8GB)
* An authentication key setup on Github for your local machine (see [GitHub docs](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account))


In the best case LXD is not configured on your system. If it isn't, run the 
following commands and restart your machine:
```bash
sudo adduser $USER lxd
newgrp lxd
```
However, if you have configured LXD and have running
containers and network configurations, this is not a problem but make sure
that the following names/network ranges are not yet used by LXD (or change values in 
`config.sh`).

* a profile in LXDs default project called `$MAAS_CONTAINER_NAME`
* two networks named `maas-ctrl` and `maas-kvm`
  * these networks will use the IP ranges `$MAAS_CONTROL_IP_RANGE` and `MAAS_MANAGEMENT_IP_RANGE`


## How to run this script?

1. Edit the `config.sh` file according to your needs.
2. Run this to see your options

```sh
./setup-dev-env.sh
```
3. Run this to start
```sh
./setup-dev-env.sh --ok
```

If you would like to tear down your MAAS dev environment completely,
do the following:

* remove everything from LXD (e.g. containers, profiles, networks, ...) for all projects
  * you can use [LXD Delete All](https://github.com/tmerten/lxd-delete-all) for this job
* remove your [libvirt](https://libvirt.org/) network definitions (`virsh net-destroy` and `virsh net-undefine` for all networks)
* delete (or move) your current maas source code

## What happens if I run this script?

### Attention

This script was carefully crafted and does not contain any destructive commands.
Still it may install dependencies that might break your system.

The script was tested on Ubuntu 22:10 and 24.04 LTS.

### No, really. What happens?

The script will:

  * DISABLE YOUR UFW FIREWALL (to make sure lxd connections work)
  * Install git, make, lxd, snapcraft, libvirt with qemu
  * Clone the source code and (if configured) add a branch for your launcpad account
  * Setup LXD to have a MAAS development container, profiles and networks
  * Setup bridges so that MAAS can reach your network
  * Will prepare to connect your local LXD to the MAAS development container, so that MAAS can provision virtual machines on your local host
    * You will still have to do a single manual step here, but you will be guided by the script

Basically the script mimics the steps described in [this discourse post](https://discourse.maas.io/t/setting-up-a-minimal-dev-environment-with-lxd/6318) and configures your maas-dev host to be able to connect to your local LXD.

The script will stop on any error, so please be sure to skip stages, if you have already done them.

You can skip some of those stages using the `-sX` arguments. Run `./setup-dev-env.sh --help` to see your options.

## Adding an SSL certificate to the trusted CA's

If you need MAAS to accept a self-signed SSL certificate, you must add the certificate (in PEM format) to the trusted CAs within the lxd container. You can do this with the `-c` or `--ca-crt` option, as such:

```bash
./setup-dev-env.sh --ok -c /path/to/cert.crt
```
