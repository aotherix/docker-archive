#!/bin/bash

#-------------------------------------------------------------------------------
# Save Archive
# Copyright (c) 2023 Rogerio O. Ferraz <aotherix@gmail.com>
#-------------------------------------------------------------------------------

VERSION="save-archive v1.0.0"

readonly SCRIPTNAME=$(basename "${0}")
SCRIPTDIR=$(readlink -m $(dirname "${0}"))

USAGE="Usage: ${SCRIPTNAME} --image-list imagelist [--server server] [--debug]

Save a list of docker images on the dockerarchive server.

If the imagelist file is unspecified, then the file image-list is used by default, 
and it must be available in the dockerarchive server.

A server address may be omitted, if the script runs inside the dockerarchive server.

ARGUMENTS:
  server      : server address
  imagelist   : input file with a list of images to be uploaded
  debug       : provides a more verbose output for debugging purposes

Examples:
./save-archive.sh --image-list lists/stx-8.0.lst
./save-archive.sh --image-list lists/stx-8.0.lst --server $USER@<remote ip addr>
"

# Defaults
DEBUG="off"
LOCALSERVER="off"
SERVER=${USER}@localhost
imagelist=""

while [ ${#} -gt 0 ] ; do
  case "${1:-""}" in
    --debug)
      DEBUG="on"
      ;;
    --help|-h)
      echo "${USAGE}"
      exit 0
      ;;
    --image-list|-l)
      imagelist="${2}"
      shift
      ;;
    --server|-s)
      SERVER="${2}"
      shift
      ;;
    --version)
      echo "${VERSION}"
      exit 0
      ;;
  esac
  shift
done

if [ "${DEBUG}" = "on" ];then
  set -x
  DEBUG="--debug"
else
  DEBUG=""
fi

# The given image list must be available, and next it is uploaded in the StarlingX VM.
if [ ! -s ${imagelist} ]; then
  echo "error: Missing image list" >&2
  echo "${USAGE}"
  exit 1
fi

if [[ "${SERVER}" != *"@localhost" ]]; then
  echo "Transferring resources to the dockerarchive server..."
  rsync -avP --relative ${SCRIPTNAME} ${imagelist} ${SERVER}:~/dockerarchive

  echo "Connecting to the dockerarchive server..."
  ssh -t ${SERVER} "~/dockerarchive/${SCRIPTNAME} --image-list ~/dockerarchive/${imagelist} ${DEBUG}"
  exit
fi

#-------------------------
# On Server
#-------------------------

imagelist=${imagelist/#*\/dockerarchive\//""}

if [ ! -d ~/dockerarchive ]; then
  ln -s "${SCRIPTDIR}" ~/dockerarchive
  rsync "${SCRIPTNAME}" ~/dockerarchive
  rsync --relative "${imagelist}" ~/dockerarchive
fi

date
echo Saving images into the dockerarchive server...

mkdir -p ~/dockerarchive/images
cd ~/dockerarchive/images
i=1
while read IMAGE;
  do
    echo "${i} ${IMAGE}"
    if [ ! -s ${IMAGE}.tar.gz ]; then
      IMG=${IMAGE/#docker.io\//registry.hub.docker.com\/}
      sudo docker pull ${IMG}
      sudo docker tag ${IMG} ${IMAGE}
      mkdir -p $(dirname ${IMAGE})
      sudo docker save ${IMAGE} | gzip > ${IMAGE}.tar.gz
    else
      echo " [skip existing]"
    fi;
    ((i++))
  done < <(cat ../"${imagelist}" | tr -d '[:blank:]' | sed -e '/^$/ d' -e '/^#/ d' | sort)

date
echo "Done!"
