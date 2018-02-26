pipeline {
  agent any
  stages {
    stage('Container Build') {
      parallel {
        stage('Container Build') {
          steps {
            echo 'Building...'
          }
        }
        stage('Building tng-rep') {
          steps {
            sh 'docker build -t registry.sonata-nfv.eu:5000/tng-rep .'
          }
        }
      }
    }
    stage('Unit Test') {
      parallel {
        stage('Unit Tests') {
          steps {
            echo 'Performing Unit Tests'
          }
        }
        stage('Running Unit Tests') {
          steps {
            sh 'if ! [[ "$(docker inspect -f {{.State.Running}} mongo 2> /dev/null)" == "" ]]; then docker rm -fv mongo ; fi || true'
            sh 'docker run -p 27017:27017 -d --net tango --network-alias mongo --name mongo mongo'
            sh 'sleep 10'
            sh 'docker run --rm=true --net tango --network-alias tng-rep -e RACK_ENV=test -v "$(pwd)/spec/reports:/app/spec/reports" registry.sonata-nfv.eu:5000/tng-rep rake ci:all'
            sh 'if ! [[ "$(docker inspect -f {{.State.Running}} mongo 2> /dev/null)" == "" ]]; then docker rm -fv mongo ; fi || true'
          }
        }
      }
    }
    stage('Containers Publication') {
      parallel {
        stage('Containers Publication') {
          steps {
            echo 'Publication of containers in local registry....'
          }
        }
        stage('Publishing tng-rep') {
          steps {
            sh 'docker push registry.sonata-nfv.eu:5000/tng-rep'
          }
        }
      }
    }
    stage('Publish results') {
      steps {
        junit(allowEmptyResults: true, testResults: 'spec/reports/*.xml')
      }
    }
  }
  post {
    always {
      junit(allowEmptyResults: true, testResults: 'spec/reports/*.xml')
      sh 'sudo chown jenkins: spec/reports/*'
    }
  }
}
