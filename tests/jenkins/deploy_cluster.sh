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

cluster_or_singlebox="$1"
dev_box_name="dev-box-yarn-${cluster_or_singlebox}"

CONFIG_PATH=${JENKINS_HOME}/${BED}/${cluster_or_singlebox}/cluster-configuration
QUICK_START_PATH=${JENKINS_HOME}/${BED}/${cluster_or_singlebox}/quick-start

# Run dev-box
# Assume the path of custom-hadoop-binary-path in service-configuration is /pathHadoop.
# Assume the directory path of cluster-configuration is /pathConfiguration.
# By now, you can leave it as it is, we only mount those two directories into docker container for later usage.
sudo docker run -itd \
  -e COLUMNS=$COLUMNS \
  -e LINES=$LINES \
  -e TERM=$TERM \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/jenkins/scripts:/jenkins/scripts \
  -v /pathHadoop:/pathHadoop \
  -v ${CONFIG_PATH}:/cluster-configuration \
  -v ${QUICK_START_PATH}:/quick-start \
  --privileged=true \
  --name=${dev_box_name} \
  ${_REGISTRY_URI}/openpai/dev-box:${IMAGE_TAG} nofetch

sudo docker exec ${dev_box_name} rm -rf /pai
sudo docker cp ${WORKSPACE} ${dev_box_name}:/pai

# Work in dev-box
sudo docker exec -i ${dev_box_name} /bin/bash << EOF_DEV_BOX
set -ex
cd /pai

# 1. generate quick-start and configuration
rm -rf /cluster-configuration/*.yaml
/jenkins/scripts/${BED}-gen_${cluster_or_singlebox}.sh /quick-start
python paictl.py config generate -i /quick-start/quick-start.yaml -o /cluster-configuration
# update image tag
sed -i "s/tag: \\(latest\\|v[[:digit:]]\\+.[[:digit:]]\\+.[[:digit:]]\\+\\)/tag: ${IMAGE_TAG}/" /cluster-configuration/services-configuration.yaml
# setup registry
/jenkins/scripts/setup_azure_int_registry_new_com.sh /cluster-configuration

# 2. bootup kubernetes
python paictl.py cluster k8s-bootup -p /cluster-configuration
sleep 10s

# 3. push cluster configuration
echo "pai" | python paictl.py push -p /cluster-configuration

# 4. start PAI services
echo "pai" | python paictl.py service start

EOF_DEV_BOX
