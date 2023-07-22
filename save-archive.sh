#!/bin/bash

#------------------------------------------------------------------------------*
# docker-archive/save-archive 1.0.0 BETA                                       *
#                                                                              *
# MIT License                                                                  *
#                                                                              *
# Copyright (c) 2023 Rogerio O. Ferraz <rogerio.o.ferraz@gmail.com>            *
#                                                                              *
# Permission is hereby granted, free of charge, to any person obtaining a copy *
# of this software and associated documentation files (the "Software"), to deal*
# in the Software without restriction, including without limitation the rights *
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell    *
# copies of the Software, and to permit persons to whom the Software is        *
# furnished to do so, subject to the following conditions:                     *
#                                                                              *
# The above copyright notice and this permission notice shall be included in   *
# all copies or substantial portions of the Software.                          *
#                                                                              *
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   *
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     *
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  *
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       *
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,*
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN    *
# THE SOFTWARE.                                                                *
#                                                                              *
#------------------------------------------------------------------------------*

VERSION="save-archive 1.0.0 BETA"

readonly SCRIPTNAME=$(basename "${0}")
SCRIPTDIR=$(readlink -m $(dirname "${0}"))

USAGE="Usage: ${SCRIPTNAME} --image-list imagelist [--server server] [--debug]

Save a list of docker images on the docker-archive server.

If the imagelist file is unspecified, then the file image-list is used by default, 
and it must be available in the docker-archive server.

A server address may be omitted, if the script runs inside the docker-archive server.

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
  echo "Transferring resources to the docker-archive server..."
  rsync -avP --relative ${SCRIPTNAME} ${imagelist} ${SERVER}:~/docker-archive

  echo "Connecting to the docker-archive server..."
  ssh -t ${SERVER} "~/docker-archive/${SCRIPTNAME} --image-list ~/docker-archive/${imagelist} ${DEBUG}"
  exit
fi

#-------------------------
# On Server
#-------------------------

imagelist=${imagelist/#*\/docker-archive\//""}

if [ ! -d ~/docker-archive ]; then
  ln -s "${SCRIPTDIR}" ~/docker-archive
  rsync "${SCRIPTNAME}" ~/docker-archive
  rsync --relative "${imagelist}" ~/docker-archive
fi

date
echo Saving images into the docker-archive server...

mkdir -p ~/docker-archive/images
cd ~/docker-archive/images
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
