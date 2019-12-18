// Copyright (c) Microsoft Corporation
// All rights reserved.
//
// MIT License
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
// to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
// BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// timeout in minutes
max_time = 10

// check health for http uri
def http_check_health(uri) {
  def status = 0
  while (!status.equals(200)) {
    try {
      sleep(10)
      echo "Waiting for PAI to be ready ..."
      def response = httpRequest(uri)
      println("Status: " + response.status)
      println("Content: " + response.content)
      status = response.status
    } catch (err) {
      if (err instanceof org.jenkinsci.plugins.workflow.steps.FlowInterruptedException) {
        echo "Http request timeout."
        return -1;
      }
      echo "PAI is not ready: ${err}"
    }
  }
  return 0;
}

pipeline {
  environment {
    _USER = "core"
    _REGISTRY_URI = "10.0.1.5:5000"
  }
  agent {
    node {
      label "pipeline"
    }
  }

  stages {
    // Prepare Cluster
    stage("Prepare Cluster") {
      agent {
        node {
          label "dev-box"
        }
      }
      steps {
        script {
          sh "bash ${WORKSPACE}/jenkins/tests/prepare_cluster.sh"
          env.BED = readFile("${WORKSPACE}/BED.txt").trim()
          env.IMAGE_TAG = readFile("${WORKSPACE}/IMAGE_TAG.txt").trim()
          echo "BED=${BED}"
          echo "IMAGE_TAG=${IMAGE_TAG}"
        }
      }
    }

    // Build Images
    stage("Build Images") {
      agent {
        node {
          label "dev-box"
        }
      }
      steps {
        sh "bash ${WORKSPACE}/jenkins/tests/build_images.sh"
      }
    }

    // Deploy PAI
    stage("Deploy PAI") {
      parallel {
        stage("YARN Single Box") {
          agent {
            node {
              label "dev-box"
            }
          }
          steps {
            script {
              try {
                sh "bash ${WORKSPACE}/jenkins/tests/deploy_cluster.sh singlebox"
              } catch (err) {
                echo "Deploy YARN Single Box Failed: ${err}"
                currentBuild.result = "FAILURE"
              }
            }
          }
        }
        stage("YARN Cluster") {
          agent {
            node {
              label "dev-box"
            }
          }
          steps {
            script {
              try {
                sh "bash ${WORKSPACE}/jenkins/tests/deploy_cluster.sh cluster"
              } catch (err) {
                echo "Deploy YARN Cluster Failed: ${err}"
                currentBuild.result = "FAILURE"
              }
            }
          }
        }
      }
    }

    // Test PAI
    stage("Test PAI") {
      parallel {
        stage("YARN Single Box") {
          agent {
            node {
              label "dev-box"
            }
          }
          steps {
            script {
              env.SINGLE_BOX_URL = readFile("${JENKINS_HOME}/${BED}/singlebox/quick-start/pai_url.txt").trim()
              if (currentBuild.result == "FAILURE") {
                echo "Deploy failed, skip test."
              } else {
                try {
                  timeout(time: max_time, unit: "MINUTES") {
                    def readiness = http_check_health("${SINGLE_BOX_URL}/rest-server/api/v1")
                    if (readiness == -1) {
                      currentBuild.result = "FAILURE"
                    }
                    sh "bash ${WORKSPACE}/jenkins/tests/test_rest_server.sh ${SINGLE_BOX_URL}"
                  }
                } catch (err) {
                  echo "Test YARN Single Box Failed: ${err}"
                  currentBuild.result = "FAILURE"
                }
              }
            }
          }
        }
        stage("YARN Cluster") {
          agent {
            node {
              label "dev-box"
            }
          }
          steps {
            script {
              env.CLUSTER_URL = readFile("${JENKINS_HOME}/${BED}/cluster/quick-start/pai_url.txt").trim()
              if (currentBuild.result == "FAILURE") {
                echo "Deploy failed, skip test."
              } else {
                try {
                  timeout(time: max_time, unit: "MINUTES") {
                    def readiness = http_check_health("${CLUSTER_URL}/rest-server/api/v1")
                    if (readiness == -1) {
                      currentBuild.result = "FAILURE"
                    }
                    sh "bash ${WORKSPACE}/jenkins/tests/test_rest_server.sh ${CLUSTER_URL}"
                  }
                } catch (err) {
                  echo "Test YARN Cluster Failed: ${err}"
                  currentBuild.result = "FAILURE"
                }
              }
            }
          }
        }
      }
    }

    // Pause on Failure
    stage("Pause on Failure") {
      agent {
        node {
          label "dev-box"
        }
      }
      steps {
        script {
          try {
            if (currentBuild.result == "FAILURE"){
              def pauseNow
              timeout(time: max_time, unit: "MINUTES"){
                pauseNow = input(
                  message: "Do you want to reserve the environment for debug?",
                  ok: "Yes",
                  parameters: [booleanParam(
                    defaultValue: true,
                    description: "If you want to debug, click the Yes", name: "Yes?"
                  )]
                )
                echo "pauseNow: " + pauseNow
              }
              if (pauseNow) {
                input (message: 'Click "Proceed" to finish!')
              }
            }
          } catch (err) {
            echo "Encountered error: ${err}"
            echo "Whatever, Will clean up cluster now!"
          }
        }
      }
    }

    // Clean up Cluster
    stage("Clean up Cluster") {
      parallel {
        stage("YARN Single Box") {
          agent {
            node {
              label "dev-box"
            }
          }
          steps {
            sh "bash ${WORKSPACE}/jenkins/tests/cleanup_cluster.sh singlebox"
          }
        }
        stage("YARN Cluster") {
          agent {
            node {
              label "dev-box"
            }
          }
          steps {
            sh "bash ${WORKSPACE}/jenkins/tests/cleanup_cluster.sh singlebox"
          }
        }
      }
    }
  }

  post {
    always {
      echo "The end of Jenkins pipeline."
    }
    success {
      echo "Jenkins succeeeded :)"
      office365ConnectorSend(
        status: "Build success",
        webhookUrl: "${env.HOOK}"
      )
    }
    unstable {
      echo "Jenkins is unstable :/"
    }
    failure {
      echo "Jenkins failed :("
      office365ConnectorSend(
        status: "Build failure",
        webhookUrl: "${env.HOOK}"
      )
      step([
        $class: "Mailer",
        notifyEveryUnstableBuild: true,
        recipients: emailextrecipients([
          [$class: "CulpritsRecipientProvider"],
          [$class: "RequesterRecipientProvider"]
        ]),
        to: "paialert@microsoft.com"
      ])
    }
    changed {
      echo "Things were different before..."
    }
  }
  options {
    disableConcurrentBuilds()
  }
}
