pipeline {
    agent any
    stages {

        stage('Checkout'){
            steps {
            checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '2e56e149-1a09-4640-845b-0aeff4b48fc2', url: 'git@github.com:fmcastells/EventManagerInfra.git']]])
            }
        }
        stage('Set Terraform path') {
            steps {
                sh "pwd"
                sh "ls -al"
                sh "docker run -i hashicorp/terraform:light version"
                sh "docker run -i hashicorp/terraform:light init main.tf"
            }
        }
       
            stage('Terraform Apply') {
                steps {

                    sh 'docker run -i hashicorp/terraform:light apply main.tf'
                }
            }
       
       }
     }
    
