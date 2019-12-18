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

# prepare path
QUICK_START_PATH=${JENKINS_HOME}/${BED}/singlebox/quick-start
CONFIG_PATH=${JENKINS_HOME}/${BED}/singlebox/cluster-configuration
sudo mkdir -p ${QUICK_START_PATH} ${CONFIG_PATH}

# generate quick-start and config
rm -rf ${CONFIG_PATH}/*.yaml
${JENKINS_HOME}/scripts/${BED}-gen_single-box.sh ${QUICK_START_PATH}
python paictl.py config generate -i ${QUICK_START_PATH}/quick-start.yaml -o ${CONFIG_PATH}
# update image tag
sed -i "s/tag: \\(latest\\|v[[:digit:]]\\+.[[:digit:]]\\+.[[:digit:]]\\+\\)/tag: ${IMAGE_TAG}/" ${CONFIG_PATH}/services-configuration.yaml
# setup registry
${JENKINS_HOME}/scripts/setup_azure_int_registry_new_com.sh ${CONFIG_PATH}
# build images
sudo python build/pai_build.py build -c ${CONFIG_PATH}
# push images
sudo python build/pai_build.py push -c ${CONFIG_PATH}
