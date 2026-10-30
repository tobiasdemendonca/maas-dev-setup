# MAAS dev infrastructure recipes: LXD networks, profiles and the dev
# container on the host, plus SSH access from the workshop control plane.
#
# All configuration comes from config.sh (sourced per recipe); every variable
# can be overridden from the environment. Idempotent: safe to re-run.

set positional-arguments

# Fails if run from inside the workshop (these recipes manage the host's LXD).
assert-host:
    #!/bin/bash -e
    if [ "${USER:-}" = "workshop" ]; then
      echo "ERROR: this recipe manages the host's LXD; run it on the host" >&2
      exit 1
    fi

# Initialize LXD and expose its API for MAAS (VM host over HTTPS).
init-lxd: assert-host
    #!/bin/bash -e
    if lxc info &>/dev/null; then
      echo "✓ LXD already initialized. Skipping init."
    else
      lxd init --auto
      echo "✓ LXD initialized"
    fi
    if [ -z "$(lxc config get core.https_address)" ]; then
      lxc config set core.https_address '[::]:8443'
      echo "✓ core.https_address set to [::]:8443 (MAAS uses the host as a LXD VM host)"
    else
      echo "✓ core.https_address already set. Skipping."
    fi

# Create the maas-ctrl (DHCP, region traffic) and maas-kvm (no DHCP, composed
# VMs) bridge networks.
create-networks: assert-host init-lxd
    #!/bin/bash -e
    cd {{justfile_directory()}}
    . ./config.sh
    control_prefix=${MAAS_CONTROL_IP_RANGE%.*}

    if ! lxc network info "$MAAS_CTRL_NETWORK" &>/dev/null; then
      lxc network create "$MAAS_CTRL_NETWORK" --type=bridge \
        dns.domain="$MAAS_CTRL_NETWORK" \
        ipv4.address="${MAAS_CONTROL_IP_RANGE}/24" \
        ipv4.dhcp=true \
        "ipv4.dhcp.ranges=${control_prefix}.16-${control_prefix}.31" \
        ipv4.nat=true \
        ipv6.address=none
      echo "✓ Network $MAAS_CTRL_NETWORK created"
    else
      echo "✓ Network $MAAS_CTRL_NETWORK already exists. Skipping."
    fi

    if ! lxc network info "$MAAS_KVM_NETWORK" &>/dev/null; then
      lxc network create "$MAAS_KVM_NETWORK" --type=bridge \
        ipv4.address="${MAAS_MANAGEMENT_IP_RANGE}/24" \
        ipv4.dhcp=false \
        ipv4.nat=true \
        ipv6.address=none
      echo "✓ Network $MAAS_KVM_NETWORK created"
    else
      echo "✓ Network $MAAS_KVM_NETWORK already exists. Skipping."
    fi

# Create the region profile (idmap, cloud-init vendor-data, /work mount,
# eth0 on maas-ctrl + eth1 on maas-kvm) and the maas-machine VM profile.
create-profiles: assert-host create-networks
    #!/bin/bash -e
    cd {{justfile_directory()}}
    . ./config.sh

    if [ -z "$MAAS_GITHUB_ID" ]; then
      echo "ERROR: MAAS_GITHUB_ID is not set (see config.sh) - required to import your ssh key via ssh_import_id" >&2
      exit 1
    fi

    mkdir -p .state/ssh
    if [ ! -f .state/ssh/maas_dev_key ]; then
      ssh-keygen -t ed25519 -f .state/ssh/maas_dev_key -N "" -C "maas-dev"
      chmod 0600 .state/ssh/maas_dev_key
      echo "✓ SSH key generated at .state/ssh/maas_dev_key"
    fi

    maas_src=$(readlink -f "$MAAS_SRC")
    if [ ! -d "$maas_src" ]; then
      echo "ERROR: MAAS source not found at $maas_src (MAAS_SRC in config.sh); clone it first" >&2
      exit 1
    fi

    if ! lxc profile show "$MAAS_CONTAINER_NAME" &>/dev/null; then
      lxc profile create "$MAAS_CONTAINER_NAME"
      lxc profile set "$MAAS_CONTAINER_NAME" raw.idmap "uid $(id -u) 1000
    gid $(id -g) 1000"
      PUB_KEY="$(cat .state/ssh/maas_dev_key.pub)" MAAS_GITHUB_ID="$MAAS_GITHUB_ID" \
        envsubst '${PUB_KEY} ${MAAS_GITHUB_ID}' < just/maas-dev-cloud-init.yaml \
        | lxc profile set "$MAAS_CONTAINER_NAME" user.vendor-data -
      lxc profile device add "$MAAS_CONTAINER_NAME" work disk source="$maas_src" path=/work
      lxc profile device add "$MAAS_CONTAINER_NAME" eth0 nic name=eth0 network="$MAAS_CTRL_NETWORK"
      lxc profile device add "$MAAS_CONTAINER_NAME" eth1 nic name=eth1 network="$MAAS_KVM_NETWORK"
      echo "✓ Profile $MAAS_CONTAINER_NAME created"
    else
      echo "✓ Profile $MAAS_CONTAINER_NAME already exists. Skipping."
    fi

    if ! lxc profile show "$MAAS_MACHINE_PROFILE" &>/dev/null; then
      lxc profile create "$MAAS_MACHINE_PROFILE"
      lxc profile set "$MAAS_MACHINE_PROFILE" boot.mode uefi-nosecureboot
      lxc profile set "$MAAS_MACHINE_PROFILE" limits.cpu 2
      lxc profile set "$MAAS_MACHINE_PROFILE" limits.memory 6GiB
      lxc profile device add "$MAAS_MACHINE_PROFILE" eth0 nic name=eth0 nictype=bridged parent="$MAAS_KVM_NETWORK" boot.priority=1
      lxc profile device add "$MAAS_MACHINE_PROFILE" root disk path=/ pool=default size=8GB boot.priority=0
      echo "✓ Profile $MAAS_MACHINE_PROFILE created"
    else
      echo "✓ Profile $MAAS_MACHINE_PROFILE already exists. Skipping."
    fi

# Launch the MAAS dev container and record its maas-ctrl IP in .state/.
create-maas-dev: assert-host create-networks create-profiles
    #!/bin/bash -e
    cd {{justfile_directory()}}
    . ./config.sh

    # Derive UBUNTU_VERSION from MAAS_BRANCH unless set (same mapping as setup-dev-env.sh).
    if [ -z "$UBUNTU_VERSION" ]; then
      case "$MAAS_BRANCH" in
        3.4|3.5) UBUNTU_VERSION=jammy ;;
        3.6|3.7) UBUNTU_VERSION=noble ;;
        3.8|"") UBUNTU_VERSION=resolute ;;
        *) echo "ERROR: MAAS_BRANCH='$MAAS_BRANCH' has no known Ubuntu mapping; set UBUNTU_VERSION in config.sh" >&2; exit 1 ;;
      esac
    fi

    if lxc info "$MAAS_CONTAINER_NAME" &>/dev/null; then
      echo "✓ Container $MAAS_CONTAINER_NAME already exists. Skipping launch."
    else
      lxc launch "ubuntu:${UBUNTU_VERSION}" "$MAAS_CONTAINER_NAME" -p default -p "$MAAS_CONTAINER_NAME"
      echo "✓ Container $MAAS_CONTAINER_NAME launched (ubuntu:$UBUNTU_VERSION)"

      echo "Waiting for cloud-init to finish..."
      lxc exec "$MAAS_CONTAINER_NAME" -- cloud-init status --wait
    fi

    control_prefix=${MAAS_CONTROL_IP_RANGE%.*}
    addr=""
    for i in $(seq 1 40); do
      addr=$(lxc list "$MAAS_CONTAINER_NAME" --format json \
        | jq -r --arg p "$control_prefix" \
          '.[0].state.network.eth0.addresses[]? | select(.family=="inet" and .scope=="global" and (.address | startswith($p + "."))) | .address' \
        | head -1)
      [ -n "$addr" ] && break
      sleep 3
    done
    if [ -z "$addr" ]; then
      echo "ERROR: $MAAS_CONTAINER_NAME has no IP on $MAAS_CTRL_NETWORK ($control_prefix.0/24)" >&2
      exit 1
    fi
    mkdir -p .state
    echo "$addr" > .state/maas-dev-ip
    echo "✓ Container IP on $MAAS_CTRL_NETWORK: $addr"

    # Authorize the recipe key also on containers created before it existed
    # (e.g. by setup-dev-env.sh), where the profile vendor-data lacks it.
    pub_key=$(cat .state/ssh/maas_dev_key.pub)
    lxc exec "$MAAS_CONTAINER_NAME" -- su - ubuntu -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh &&
      { grep -qxF '$pub_key' ~/.ssh/authorized_keys 2>/dev/null || echo '$pub_key' >> ~/.ssh/authorized_keys; }"
    echo "✓ SSH key authorized in $MAAS_CONTAINER_NAME"

    just workshop-ssh

# Wire `ssh <container>` inside the workshop. Re-run after every workshop
# refresh, which resets ~/.ssh. The stanza lives in a dedicated config.d file
# so re-runs just rewrite it. Note: `sed -i '1i'` is a no-op on an empty file,
# hence the append; and `~` must stay quoted so it expands inside the
# workshop, not on the host.
workshop-ssh: assert-host
    #!/bin/bash -e
    cd {{justfile_directory()}}
    . ./config.sh
    if [ ! -f .state/maas-dev-ip ]; then
      echo "⊘ No container IP recorded; skipping workshop SSH wiring (run 'just create-maas-dev')"
      exit 0
    fi
    if ! workshop info dev 2>/dev/null | grep -q "status:.*ready"; then
      echo "⊘ Workshop not running; skipping workshop SSH wiring (run 'just setup-workshop')"
      exit 0
    fi
    addr=$(cat .state/maas-dev-ip)
    workshop exec dev -- bash -c 'mkdir -p ~/.ssh/config.d'
    if ! workshop exec dev -- bash -c 'grep -qxF "Include config.d/*" ~/.ssh/config' 2>/dev/null; then
      workshop exec dev -- bash -c 'cat >> ~/.ssh/config' <<'EOF'
    Include config.d/*
    EOF
    fi
    workshop exec dev -- bash -c "cat > ~/.ssh/config.d/$MAAS_CONTAINER_NAME" <<EOF
    Host $MAAS_CONTAINER_NAME
      HostName $addr
      User ubuntu
      IdentityFile /project/.state/ssh/maas_dev_key
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
    EOF
    echo "✓ Workshop SSH wired: 'ssh $MAAS_CONTAINER_NAME' works inside the workshop"

# Delete the container, both profiles, both networks and local state.
delete-maas-dev: assert-host
    #!/bin/bash -e
    cd {{justfile_directory()}}
    . ./config.sh

    if lxc info "$MAAS_CONTAINER_NAME" &>/dev/null; then
      lxc delete -f "$MAAS_CONTAINER_NAME"
      echo "✓ Container $MAAS_CONTAINER_NAME deleted"
    fi
    if lxc profile show "$MAAS_CONTAINER_NAME" &>/dev/null; then
      lxc profile delete "$MAAS_CONTAINER_NAME"
      echo "✓ Profile $MAAS_CONTAINER_NAME deleted"
    fi
    if lxc profile show "$MAAS_MACHINE_PROFILE" &>/dev/null; then
      lxc profile delete "$MAAS_MACHINE_PROFILE"
      echo "✓ Profile $MAAS_MACHINE_PROFILE deleted"
    fi
    for net in "$MAAS_CTRL_NETWORK" "$MAAS_KVM_NETWORK"; do
      if lxc network info "$net" &>/dev/null; then
        lxc network delete "$net"
        echo "✓ Network $net deleted"
      fi
    done
    rm -f .state/maas-dev-ip
    if workshop info 2>/dev/null | grep -q "status:.*ready"; then
      workshop exec -- bash -c "rm -f ~/.ssh/config.d/$MAAS_CONTAINER_NAME" || true
    fi
    echo "✓ Teardown complete"

# SSH into the dev container. Works from the host and from inside the workshop.
maas-shell:
    #!/bin/bash -e
    cd {{justfile_directory()}}
    . ./config.sh
    if [ ! -f .state/maas-dev-ip ]; then
      echo "ERROR: no container IP recorded; run 'just create-maas-dev' first" >&2
      exit 1
    fi
    if [ "${USER:-}" = "workshop" ]; then
      exec ssh "$MAAS_CONTAINER_NAME"
    else
      exec ssh -i .state/ssh/maas_dev_key -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null "ubuntu@$(cat .state/maas-dev-ip)"
    fi

# Install and start MAAS inside the dev container. Expects the MAAS source at
# MAAS_SRC prepared like setup-dev-env.sh does (checked out, snap tree built).
maas-bootstrap:
    #!/bin/bash -e
    cd {{justfile_directory()}}
    . ./config.sh
    if [ ! -f .state/maas-dev-ip ]; then
      echo "ERROR: no container IP recorded; run 'just create-maas-dev' first" >&2
      exit 1
    fi
    if [ "${USER:-}" = "workshop" ]; then
      run_ssh() { ssh "$MAAS_CONTAINER_NAME" "$@"; }
    else
      run_ssh() { ssh -i .state/ssh/maas_dev_key -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null "ubuntu@$(cat .state/maas-dev-ip)" "$@"; }
    fi
    run_ssh \
      MAAS_CONTROL_IP_RANGE="$MAAS_CONTROL_IP_RANGE" \
      MAAS_MANAGEMENT_IP_RANGE="$MAAS_MANAGEMENT_IP_RANGE" \
      MAAS_IPV6_IP_RANGE="$MAAS_IPV6_IP_RANGE" \
      MAAS_DUAL_STACK_IPV4_RANGE="$MAAS_DUAL_STACK_IPV4_RANGE" \
      MAAS_DUAL_STACK_IPV6_RANGE="$MAAS_DUAL_STACK_IPV6_RANGE" \
      bash -s < setup-region-via-ssh.bash
