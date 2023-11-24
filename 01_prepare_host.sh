#!/usr/bin/env bash
set -eux

PROJECT_DIR=$(dirname -- $(readlink -e -- ${BASH_SOURCE[0]}))

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Please run as a non-root user"
  exit 1
fi

# Check OS type and version
source /etc/os-release
export DISTRO="${ID}${VERSION_ID%.*}"
export OS="${ID}"
export OS_VERSION_ID="${VERSION_ID}"
export SUPPORTED_DISTROS=(ubuntu22)

if [[ ! "${SUPPORTED_DISTROS[*]}" =~ ${DISTRO} ]]; then
  echo "Supported OS distros for the host are: Ubuntu 22.04"
  exit 1
fi


if [[ "${OS}" = "ubuntu" ]]; then
  # Set apt retry limit to higher than default to
  # make the data retrival more reliable
  sudo sh -c ' echo "Acquire::Retries \"10\";" > /etc/apt/apt.conf.d/80-retries '
  sudo DEBIAN_FRONTEND=noninteractive apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y install python3-pip python3-dev jq curl wget pkg-config bash-completion

  # Set update-alternatives to python3
  if [[ "${DISTRO}" = "ubuntu22" ]]; then
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
  fi
fi

sudo python -m pip install ansible

# Install requirements
ansible-galaxy install -r requirements.yml

# Run ansible prepare host playbook
export ANSIBLE_ROLES_PATH=$PROJECT_DIR/roles
ANSIBLE_FORCE_COLOR=true ansible-playbook \
  -i ${PROJECT_DIR}/inventories/localhost_inventory.yml \
  $PROJECT_DIR/playbooks/prepare_host.yml $@

# Restart libvirtd service to get the new group membership loaded
if ! id "${USER}" | grep -q libvirt; then
  if [[ "${OS}" = "ubuntu" ]]; then
    # Workaround - disable apparmor for libvirt as it doesn't seem to work with user-created volume pools
    selinux="#security_driver = \"selinux\""
    apparmor="security_driver = \"apparmor\""
    none="security_driver = \"none\""
    sudo sed -i "s/$selinux/$none/g" /etc/libvirt/qemu.conf
    sudo sed -i "s/$apparmor/$none/g" /etc/libvirt/qemu.conf
  fi

  sudo adduser "${USER}" libvirt
  sudo adduser "${USER}" kvm
  sudo systemctl restart libvirtd
  sudo setfacl -m user:$USER:rw /var/run/libvirt/libvirt-sock
  echo "Note: to view libvirt resources as non-root log out and log in again"
  echo "Alternatively export LIBVIRT_DEFAULT_URI=\"qemu:///system\""
fi

# Ensure we have an SSH key, used for access to VMs
if [ ! -f ~/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -C "m3-demo" -f ~/.ssh/id_ed25519 -N ""
fi
