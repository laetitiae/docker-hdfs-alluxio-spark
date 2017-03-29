#!/usr/bin/env bash

cluster_name="$3"

set -o errexit
set -o pipefail
set -o nounset
set -o errtrace

# main script params

node="$1"
action="$2"

set +o nounset

if [ "${cluster_name}z" == "z" ]; then
	cluster_name=${HOSTNAME}
fi

# http://www.alluxio.org/docs/1.4/en/Configuration-Settings.html

export ALLUXIO_PREFIX=/opt/alluxio

export ALLUXIO_WORKER_MEMORY_SIZE=${ALLUXIO_WORKER_MEMORY_SIZE:-"1024MB"}
export ALLUXIO_RAM_FOLDER=${ALLUXIO_RAM_FOLDER:-"/mnt/ramdisk"}
export ALLUXIO_UNDERFS_ADDRESS=${ALLUXIO_UNDERFS_ADDRESS:-"hdfs://hdfs-namenode:8020"}

set +o nounset

master_node() {
	local action="$1"
	local cluster_name="$2"

	case $action in
		start)
			export ALLUXIO_MASTER_HOSTNAME=${cluster_name}
			if [ ! -f /opt/alluxio/conf/alluxio-env.sh ]; then
				${ALLUXIO_PREFIX}/bin/alluxio bootstrapConf ${cluster_name}
			fi
			if [ ! -d /opt/alluxio/journal/ ]; then
				mkdir -p /opt/alluxio/journal/
				${ALLUXIO_PREFIX}/bin/alluxio format
			fi
			${ALLUXIO_PREFIX}/bin/alluxio-start.sh master
			${ALLUXIO_HOME}/bin/alluxio-start.sh proxy
		;;
		stop)
			${ALLUXIO_HOME}/bin/alluxio-stop.sh proxy
			${ALLUXIO_PREFIX}/bin/alluxio-stop.sh master
		;;
		status)
			# I would love a status report
			echo "Not implemented"
		;;
		*)
		echo "Action not supported"
		;;
	esac

}

slave_node() {
	local action="$1"
	local cluster_name="$2"

	case $action in
		start)
			export ALLUXIO_MASTER_HOSTNAME=${cluster_name}
			${ALLUXIO_PREFIX}/bin/alluxio-start.sh worker NoMount
		;;
		stop)
			${ALLUXIO_PREFIX}/bin/alluxio-stop.sh worker
		;;
		status)
			# I would love a status report
			echo "Not implemented"
		;;
		*)
		echo "Action not supported"
		;;
	esac
}

config() {
	local file="${1}"
	shift
	local conf=("${@}")
	for p in "${conf[@]}"; do
		echo ${p} >> ${file}
	done
}


alluxio_handler() {
	local node="$1"
	local action="$2"
	local cluster_name="$3"
	echo "alluxio_handler():${node} ${action} ${cluster_name}"
	case $node in
		master)
			master_node ${action} ${cluster_name}
		;;
		slave)
			slave_node ${action} ${cluster_name}
		;;
	esac
}

setup_username() {
	export USER_ID=$(id -u)
	export GROUP_ID=$(id -g)
	cat /etc/passwd > /tmp/passwd
	echo "openshift:x:${USER_ID}:${GROUP_ID}:OpenShift Dynamic user:${ALLUXIO_PREFIX}:/bin/bash" >> /tmp/passwd
	export LD_PRELOAD=/usr/lib/libnss_wrapper.so
	export NSS_WRAPPER_PASSWD=/tmp/passwd
	export NSS_WRAPPER_GROUP=/etc/group
}

shut_down() {
	echo "Calling shutdown! $1"
	alluxio_handler ${node} stop ${cluster_name}
}

default_properties=(
	"alluxio.security.authentication.type=SIMPLE"
	"alluxio.security.authorization.permission.enabled=true"
)

trap "shut_down sigkill" SIGKILL
trap "shut_down sigterm" SIGTERM
trap "shut_down sighup" SIGHUP
trap "shut_down sigint" SIGINT
# trap "shut_down sigexit" EXIT


setup_username

config "${ALLUXIO_PREFIX}/conf/alluxio-site.properties" "${default_properties[@]}"
alluxio_handler ${node} ${action} ${cluster_name}

sleep 2s
tail -f /opt/alluxio/logs/*
