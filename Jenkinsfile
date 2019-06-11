pipeline {
    agent any
    stages {
        stage('Set Terraform path') {
            steps {
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
    
