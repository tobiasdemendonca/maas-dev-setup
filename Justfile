# MAAS dev environment: workshop control plane + LXD container infrastructure.
# See README.md ("Workshop + just setup") for the flow.

import 'just/maas.just'

default:
    @just --list

# Full setup: workshop control plane, LXD networks/profiles, MAAS dev container.
setup: setup-workshop create-maas-dev
    @echo "✓ Setup complete. Enter the container with 'just maas-shell'."

# Launch (or refresh) the workshop and mount MAAS_SRC at /home/workshop/maas.
setup-workshop:
    #!/bin/bash -e
    cd {{justfile_directory()}}
    . ./config.sh
    status=$(workshop info dev 2>/dev/null | sed -n 's/^status: *//p')
    case "$status" in
      ready|stopped)
        if ! workshop info dev | grep -q "maas-src:"; then
          echo "Refreshing workshop to apply the definition..."
          workshop refresh dev --verbose
        else
          echo "✓ Workshop already launched. Skipping launch."
        fi
        ;;
      *) workshop launch dev --verbose ;;
    esac

    # Point the maas-src plug at the MAAS checkout. The source is populated,
    # so Workshop requires the workshop to be stopped for the remount.
    maas_src=$(readlink -f "$MAAS_SRC")
    current=$(workshop info dev | grep -A1 "maas-src:" | sed -n 's/^ *host-source: *//p')
    current=$(readlink -f "${current/#\~/$HOME}" || true)
    if [ "$current" != "$maas_src" ]; then
      if workshop info dev | grep -q "status:.*ready"; then workshop stop dev; fi
      workshop remount dev/maas:maas-src "$maas_src"
      echo "✓ $maas_src mounted at /home/workshop/maas"
    else
      echo "✓ $maas_src already mounted at /home/workshop/maas. Skipping."
    fi
    if workshop info dev | grep -q "status:.*stopped"; then workshop start dev; fi
    just workshop-ssh

# Open a shell in the workshop, in the MAAS source.
workshop-shell:
    workshop exec -i -w /home/workshop/maas dev -- bash -l

# Open the MAAS source in VS Code, connected to the workshop over Remote-SSH.
# Connect by hostname: Workshop's SSH certificates are issued for it.
vscode:
    #!/bin/bash -e
    hostname="$(workshop info dev | awk '/^hostname:/{print $2}')"
    if [ -z "$hostname" ]; then
      echo "ERROR: could not determine the workshop hostname; run 'just setup-workshop'" >&2
      exit 1
    fi
    code --remote ssh-remote+"$hostname" /home/workshop/maas
