#!/bin/bash

#------------------------------------------------------------------------------*
# docker-archive/load-archive 1.0.0 BETA                                       *
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

VERSION="load-archive 1.0.0 BETA"

readonly SCRIPTNAME=$(basename "${0}")
SCRIPTDIR=$(readlink -m $(dirname "${0}"))

USAGE="Usage: ${SCRIPTNAME} --image-list imagelist [--server server] [--target target[:port]] [--debug]

Loads a list of docker images into a StarlingX VM.

If the imagelist file is unspecified, then the file image-list is used by default, 
and it must be available in the StarlingX VM.

A target vm address may be omitted, if the script runs inside the StarlingX VM.

ARGUMENTS:
  target      : target StarlingX VM address
  server      : server address
  imagelist   : input file with a list of images to be uploaded
  debug       : provides a more verbose output for debugging purposes
  port        : StarlingX VM port number

Examples:
./load-archive.sh --image-list lists/stx-8.0.lst --target sysadmin@10.10.10.2
./load-archive.sh --image-list lists/stx-8.0.lst --server $USER@<remote ip addr> --target sysadmin@10.10.10.2
./load-archive.sh --image-list lists/stx-8.0.lst --server $USER@<remote ip addr> --target sysadmin@<remote ip addr>:10100
"

# Defaults
DEBUG="off"
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
    --target|-t)
      target="${2}"
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

# Target port number
if [[ "${target}" == *":"* ]]; then
  target_port=$(echo $target | awk -F: '{ print $2}')
  target=${target/%:*/""}
  regex='^[0-9]+$'  # Check for a digits expression
  if ! [[ ${target_port} =~ ${regex} ]] ; then
    echo "error: Invalid target port number: ${target_port}" >&2
    exit 1
  fi
else
  target_port="22"
fi;

# The given image list must be available, and next it is uploaded in the StarlingX VM.
if [ ! -s ${imagelist} ]; then
  echo "error: Missing image list" >&2
  echo "${USAGE}"
  exit 1
fi

if [ -s "/etc/build.info" ] && [ $(cat "/etc/build.info" | grep -c "SW_VERSION") -eq 1 ]; then
  source "/etc/build.info"
else
  if [ -z ${target} ]; then
    echo "error: Missing target" >&2
    echo "${USAGE}"
    exit 1
  else
    echo "Transferring resources to target machine..."
    rsync -e "ssh -p ${target_port}" -avP --relative ${SCRIPTNAME} ${imagelist} ${target}:~

    echo "Connecting to target machine..."
    ssh -t ${target} -p ${target_port} "~/${SCRIPTNAME} --image-list ${imagelist} --server ${SERVER} ${DEBUG}"
    exit
  fi
fi

#-------------------------
# On controller-0
#-------------------------

sudo mkdir -p /opt/platform-backup/"${SW_VERSION}"
sudo chown sysadmin:sys_protected /opt/platform-backup/"${SW_VERSION}"

# Image List
cp "${imagelist}" /opt/platform-backup/"${SW_VERSION}"
imagelist=$(basename "${imagelist}")

cd /opt/platform-backup/"${SW_VERSION}"

# Server IP address
if [[ "${SERVER}" == *"@localhost" ]]; then
  IP=$(echo $SSH_CLIENT | awk '{ print $1}')
  SERVER=${SERVER/%@localhost/@${IP}}
fi;

echo "Transferring image tarballs from docker-archive server..."
cat "${imagelist}" | tr -d '[:blank:]' | sed -e '/^$/ d' -e '/^#/ d' | sort | sed 's/$/.tar.gz/' > tgz-"${imagelist}"
rsync -avP --files-from=tgz-"${imagelist}" "${SERVER}":~/docker-archive/images ./images

# Login Local Registry
while true;
  do
    echo "Login local registry"
    sudo docker login -u admin -p "${STXPASSWD}" registry.local:9001 2>/dev/null
    if [ "${?}" -eq "0" ]; then
        break;
    else
        echo "Trying again after 1min..."
        sleep 1m;
    fi; 
  done

date
echo Loading and pushing images to local registry...

# Load images from docker-archive server
cd images
i=1
while read IMAGE;
  do
    echo "${i} ${IMAGE}"
    sudo docker load --input "${IMAGE}".tar.gz
    sudo docker tag "${IMAGE}" registry.local:9001/"${IMAGE}"
    sudo docker push registry.local:9001/"${IMAGE}"
    ((i++))
  done < <(cat ../"${imagelist}" | tr -d '[:blank:]' | sed -e '/^$/ d' -e '/^#/ d' | sort)

date
echo "Done!"
