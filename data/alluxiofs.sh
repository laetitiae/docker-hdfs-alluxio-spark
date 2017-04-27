#!/bin/bash

action="$1"
local_file="$2"
remote_filepath="$3"

alluxio_proxy=${ALLUXIO_PROXY:-"http://alluxio-master-rest-has.eurocloud.hyperscale.io"}

debug="-s"
case $action in
    upload)
        stream_id=$(curl $debug -L -X POST \
            "${alluxio_proxy}/api/v1/paths/${remote_filepath}/create-file")

        re='^[0-9]+$'
        if ! [[ ${stream_id} =~ $re ]] ; then
           echo "error: ${stream_id}" >&2; exit 1
        fi

        curl $debug -L -H "Content-Type: application/octet-stream" -X POST \
            -d @${local_file} \
            "${alluxio_proxy}/api/v1/streams/${stream_id}/write"

        curl $debug -L -X POST \
            "${alluxio_proxy}/api/v1/streams/${stream_id}/close"
    ;;
    ls)
        remote_filepath=${local_file}
        curl -L $debug -X POST \
            "${alluxio_proxy}/api/v1/paths/${remote_filepath}/list-status"
    ;;
    mkdir)
        remote_filepath=${local_file}
        curl -L $debug -X POST -H "Content-Type: application/json" -d '{"recursive":"true"}' \
         "${alluxio_proxy}/api/v1/paths/${remote_filepath}/create-directory"
    ;;
    rm)
        remote_filepath=${local_file}
        curl -L $debug -H "Content-Type: application/json" -X POST -d '{"recursive":"true"}'  \
        "${alluxio_proxy}/api/v1/paths/${remote_filepath}/delete"
    ;;
    get)
        remote_filepath=${local_file}
        stream_id=$(curl $debug -L -X POST \
            "${alluxio_proxy}/api/v1/paths/${remote_filepath}/open-file")

        re='^[0-9]+$'
        if ! [[ ${stream_id} =~ $re ]] ; then
           echo "error: ${stream_id}" >&2; exit 1
        fi

        curl $debug -L -X POST \
            "${alluxio_proxy}/api/v1/streams/${stream_id}/read"

        curl $debug -L -X POST \
            "${alluxio_proxy}/api/v1/streams/${stream_id}/close"
    ;;
    *)
      echo "Invalid action: ${action}"
      exit 1
    ;;
esac
