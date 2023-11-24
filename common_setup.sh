#!/bin/bash -eu

PROJECT_DIR=$(dirname -- $(readlink -e -- ${BASH_SOURCE[0]}))
PATH=${PROJECT_DIR}/bin:${PATH}
EXTRA_VARS_FILE=${EXTRA_VARS_FILE:-$PROJECT_DIR/extra_vars.yml}
export ANSIBLE_ROLES_PATH=$PROJECT_DIR/roles
: ${LIBVIRT_IMAGES_DIR:=/var/lib/libvirt/images}

if [ ! -d ${LIBVIRT_IMAGES_DIR} ] ; then
        echo "WARNING: ${LIBVIRT_IMAGES_DIR} either not exist or not accessible by  user ${USER}."
	echo "Will use ${PROJECT_DIR}/libvirt_images instead."
	LIBVIRT_IMAGES_DIR=${PROJECT_DIR}/libvirt_images
fi

setup_name=$(basename ${BASH_SOURCE[0]} .sh)
setup_type=${setup_name#setup_}
playbook=${setup_name}
case "${setup_type}" in
#(special_case)
#	inv_name=some_value
#	;;
(*)
	inv_name=localhost
	;;
esac

playbook_args=()

if [ -f "${EXTRA_VARS_FILE}" ] ; then
	playbook_args+=( -e "@extra_vars.yml" )
fi

inv_file=${PROJECT_DIR}/inventories/${inv_name}_inventory.yml
if [ -f "${inv_file}" ]; then
	playbook_args+=( -i ${inv_file} )
fi

playbook_args+=( -e "libvirt_images_dir=${LIBVIRT_IMAGES_DIR}" )
playbook_args+=( $PROJECT_DIR/playbooks/${playbook}.yml )
playbook_args+=( "${@}" )

${DEBUG:+echo} ansible-playbook "${playbook_args[@]}"
