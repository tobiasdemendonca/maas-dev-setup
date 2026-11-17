#
# Configuration variables for setup-dev-env-.sh
#

# The Ubuntu version to run the dev container on. Leave empty to auto-derive it
# from MAAS_BRANCH below (defaults to resolute for master). Only set this explicitly to override the derived value, or if
# MAAS_BRANCH has no known mapping (e.g. "latest"/"edge").
UBUNTU_VERSION=""

# This assumes that your maas source should be installed next to this project, e.g.
# $HOME/src/setup-maas-dev-env/ --> $HOME/src/maas/
MAAS_SRC="../maas"

# This is the name of container MAAS will be running in
# as well as the name for the related LXD profile
MAAS_CONTAINER_NAME="maas-dev"

# Enter your GitHub ID so the script can automatically set up your local fork
# and import your public ssh key from GitHub. The SSH key on your GitHub account should 
# be the same as the one on your local machine (see the docs on adding an ssh key to
# your GitHub account if you haven't already https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account). 
MAAS_GITHUB_ID=""

# The upstream branch to check out after cloning, e.g. "3.7". Leave empty to stay on 
# main for development. Use this if you are trying to debug an older release.
MAAS_BRANCH=""  # e.g. "3.7"

# The netmasks for the LXD networks you would like to use
# Note:
#   netmasks will be set to /24 and IP_RANGEs have to end with .1 / ::1
MAAS_CONTROL_NETWORK="maas-dev"
MAAS_CONTROL_IP_RANGE="10.10.0.1"
MAAS_MANAGEMENT_NETWORK="maas-dev"
MAAS_MANAGEMENT_IP_RANGE="10.20.0.1"
MAAS_IPV6_NETWORK="maas-ipv6"
MAAS_IPV6_IP_RANGE="fd42:be3f:b08a:3d6c::1"
MAAS_DUAL_STACK_NETWORK="maas-dual-stack"
MAAS_DUAL_STACK_IPV4_RANGE="10.30.0.1"
MAAS_DUAL_STACK_IPV6_RANGE="fd42:be3f:b08b:3d6d::1"

# Number of empty LXD VMs to create on your host and add to MAAS as
# machines (power_type=lxd). They are named ${MAAS_CONTAINER_NAME}-machine-<n>.
# Set to 0 (or pass --skip-machines) to skip this.
MAAS_MACHINE_COUNT=2

# The LXD profile for those VMs, which are booted as machines in MAAS. 
# It lives in LXD's default project.
MAAS_MACHINE_PROFILE="maas-machine"
