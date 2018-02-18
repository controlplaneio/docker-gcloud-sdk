pipeline {
  agent none

  environment {
    CONTAINER_TAG = 'latest'
  }

  stages {
    stage('Build') {
      agent {
        docker {
          image 'docker.io/controlplane/gcloud-sdk:latest',
          args '-v /var/run/docker.sock:/var/run/docker.sock ' +
            '--user=root ' +
            '--cap-drop=ALL ' +
            '--cap-add=DAC_OVERRIDE'
        }
      }

      steps {
        ansiColor('xterm') {
          sh 'id '
          sh 'make build CONTAINER_TAG="${CONTAINER_TAG}"'
        }
      }
    }

    stage('Push') {
      agent {
        docker {
          image 'docker.io/controlplane/gcloud-sdk:latest',
          args '-v /var/run/docker.sock:/var/run/docker.sock ' +
            '--user=root ' +
            '--cap-drop=ALL ' +
            '--cap-add=DAC_OVERRIDE'
        }
      }

      environment {
        DOCKER_HUB_PASSWORD = credentials('docker-hub-controlplane')
      }

      steps {
        ansiColor('xterm') {
          sh 'docker login ' +
            '--username "controlplane" ' +
            '--password "${DOCKER_HUB_PASSWORD}"'
          sh 'make push CONTAINER_TAG="${CONTAINER_TAG}"'
        }
      }
    }
  }
}
