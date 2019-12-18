#!/bin/bash

# Copyright (c) Microsoft Corporation
# All rights reserved.
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
# to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

BED="$(cut -d',' -f1 <<< ${NODE_NAME})"
IMAGE_TAG="${GIT_BRANCH//\\//-}-$(git rev-parse --short HEAD)-${BUILD_ID}"

echo ${BED} > ${WORKSPACE}/BED.txt
echo ${IMAGE_TAG} > ${WORKSPACE}/IMAGE_TAG.txt

# stop all docker containers
sudo docker stop $(sudo docker ps -q) || true
# remove all docker containers
sudo docker rm $(sudo docker ps -aq) || true
# remove all docker images
sudo docker rmi $(docker images -q) || true
# prune docker system
sudo docker system prune -f

# clean tmp directories
[ $(ls /pathHadoop | wc -l) -gt 2 ] && rm /pathHadoop/*
mkdir -p /pathHadoop
rm -rf /mnt/pathConfiguration
mkdir -p /mnt/pathConfiguration

# change permissions
sudo chown ${_USER}:${_USER} -R /pathHadoop/
sudo chown ${_USER}:${_USER} -R ${WORKSPACE}
sudo chown ${_USER}:${_USER} -R ${JENKINS_HOME}

# clean remote nodes
for host in $(seq -s " " -f "10.0.1.%g" 5 8); do
  ssh ${_USER}@${host} -o StrictHostKeyChecking=no -i /home/${_USER}/.ssh/id_rsa \
  "sudo rm -rf /datastorage || true; \
   sudo docker rm -f kubelet || true; \
   sudo docker stop $(sudo docker ps -q) || true; \
   sudo docker rm $(sudo docker ps -aq) || true; \
   sudo docker rmi $(docker images -q) || true; \
   sudo docker system prune -f || true"
done
