#!/usr/bin/env groovy

def deployToProd = false

pipeline {

  // Build Global Environment Specific variables

  environment {
     SLACK_COLOR_DANGER     = '#E01563'
     SLACK_COLOR_INFO       = '#6ECADC'
     SLACK_COLOR_WARNING    = '#FFC300'
     SLACK_COLOR_GOOD       = '#3EB991'
     SLACK_CHANNEL_Success  = '#ci-success'
     SLACK_CHANNEL_Failures = '#ci-failures'
  }

  // Build Log Rotation config properties

  options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  // Agent and Parameter variables

  agent {
    node {
       label 'docker-capable'
    }
  }
     parameters {
        choice(
            name: 'AWS_Region',
            choices:"us-east-1\nus-west-2",
            description: "Region you'd like to deploy (e.g., us-east-1, us-east-2, or us-west-2)"
        )
        booleanParam(
             name: 'Development',
             defaultValue: true,
             description: 'Deploy to Development'
        )
        booleanParam(
             name: 'Production',
             defaultValue: false,
             description: 'Deploy to Production'
        )
     }

// Build Stages and it's sub-sequent steps to perform for a defined pipeline

  stages {

      // Slack Notifying the team.

      stage('Notify the Team...!!!') {
         steps {
             slackSend (
                  color: "${env.SLACK_COLOR_INFO}",
                  channel: "${SLACK_CHANNEL_Success}",
                  message: "*STARTED:* Job:- ${env.JOB_NAME}\n Build:- ${env.BUILD_NUMBER}\n For more information about the build: ${env.BUILD_URL}"
             )
         }
      }

      stage('Unit testing') {
         agent {
           docker {
             label 'docker-capable'
             image '1234567890.dkr.ecr.us-east-1.amazonaws.com/infra:6.0'
             args '-v $HOME/.ssh:$HOME/.ssh -v $HOME/.aws:$HOME/.aws -v $HOME/.aws:/root/.aws -v $HOME/.ssh:/root/.ssh -u=root'
           }
         }

         steps {
            sh """
               echo "Verifying for source code"
               ls -lrt
               pwd
               pushd ./modules/
               terraform validate
               terraform fmt -check=true -write=false -diff=true
               find . -type f -name "*.tf" -exec dirname {} \;|sort -u |while read line; do pushd $line; docker run --rm -v $(pwd):/data -t wata727/tflint; popd; done
               popd
            """
         }
      }

      // Deployment to Development environment.

      stage('Deploy to Dev') {
         agent {
            docker {
             label 'docker-capable'
             image '1234567890.dkr.ecr.us-east-1.amazonaws.com/infra:6.0'
             args '-v $HOME/.ssh:$HOME/.ssh -v $HOME/.aws:$HOME/.aws -v $HOME/.aws:/root/.aws -v $HOME/.ssh:/root/.ssh -u=root'
            }
         }
         when {
            expression { return (params.Development == true) }
         }
         steps {
               sh """
                  pushd infra/live/nonprod/us-east-1/dev/tele
                  echo "Initializing..."
                  terraform init -input=true
                  echo "Planning..."
                  terraform plan -var-file=dev.tfvars
                  echo "Applying..."
                  terraform apply -var-file=dev.tfvars
                  popd
               """
         }
      }



      // Preparing for Production Deployment

      stage('Preparing to Deploy onto Prod') {
         agent {
            docker {
             label 'docker-capable'
             image '1234567890.dkr.ecr.us-east-1.amazonaws.com/infra:6.0'
             args '-v $HOME/.ssh:$HOME/.ssh -v $HOME/.aws:$HOME/.aws -v $HOME/.aws:/root/.aws -v $HOME/.ssh:/root/.ssh -u=root'
            }
         }
         when {
            expression { return (params.Production == true) }
         }
         steps {
            sh """
              pushd infra/live/prod/us-east-1/prod/tele
              echo "Initializing..."
              terraform init -input=true
              echo "Planning..."
              terraform plan -var-file=prod.tfvars
              popd
            """
         }
      }

      // User input confirming to proceed for Prod deployment(s).

      stage('Ask for Prod Deployment Confirmation') {
         when {
            expression { return (params.Production == true) }
         }
         steps {
            script {
              deployToProd = confirmBlock(5, 'MINUTES', 'Deploy Tele to AWS Prod ${params.AWS_Region}?')
            }
         }
      }

      // Deployment to Production environment.

      stage('Deploy to Prod') {
         agent {
            docker {
             label 'docker-capable'
             image '1234567890.dkr.ecr.us-east-1.amazonaws.com/infra:6.0'
             args '-v $HOME/.ssh:$HOME/.ssh -v $HOME/.aws:$HOME/.aws -v $HOME/.aws:/root/.aws -v $HOME/.ssh:/root/.ssh -u=root'
            }
         }
         when {
            expression { return (params.Production == true) }
         }
         steps {
            sh """
              pushd infra/live/prod/us-east-1/prod/tele
              echo "Planning..."
              terraform plan -var-file=prod.tfvars
              echo "Applying..."
              terraform apply -var-file=prod.tfvars
              popd
            """
         }
      }
  }

// Post clean-up and notification steps after clean/un-clean build process.

  post {
     aborted {
        echo "Sending ABORT Message to Slack..."
        slackSend (
            color: "${env.SLACK_COLOR_WARNING}",
            channel: "${SLACK_CHANNEL_Failures}",
            message: "*ABORTED:* Job:- ${env.JOB_NAME}\n Build:- ${env.BUILD_NUMBER}\n For more information about the build: ${env.BUILD_URL}"
        )
     }
     failure {
        echo "Sending Failure Message to Slack..."
        slackSend (
          color: "${env.SLACK_COLOR_DANGER}",
          channel: "${SLACK_CHANNEL_Failures}",
          message: "*FAILED:* Job:- ${env.JOB_NAME}\n Build:- ${env.BUILD_NUMBER}\n For more information about the build-failed: ${env.BUILD_URL}"
        )
     }
     success {
        echo "Sending Success Message to Slack..."
        slackSend (
          color: "${env.SLACK_COLOR_GOOD}",
          channel: "${SLACK_CHANNEL_Success}",
          message: "*SUCCESS:* Job:- ${env.JOB_NAME}\n Build:- ${env.BUILD_NUMBER}\n For more information about the build: ${env.BUILD_URL}"
        )
        sh 'echo "Waiting 5 minutes for deployment to complete..."'
        sh 'sleep 300'           // in seconds
     }
  }

}

// Confirmation block not to throw a Failure event, when user's confirmation was not received.

def confirmBlock(int _time, String _unit, String _message) {
    def userInput = false
    def didTimeout = false
    try {
        timeout(time: _time, unit: _unit) {
            input(ok: 'Confirm', message: _message)
            // user confirmed - set the answer to 'true'
            userInput = true
        }
    } catch(err) { // timeout reached or input false
        def user = err.getCauses()[0].getUser()
        if('SYSTEM' == user.toString()) { // SYSTEM means timeout.
            didTimeout = true
        } else {
            userInput = false
            echo "Aborted by: [${user}]"
        }
    }

    if (didTimeout) {
        return false
    } else {
        return userInput
    }
}
