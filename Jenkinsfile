pipeline {
    agent any
    stages {


        stage('Set Terraform path') {
            steps {

                sh "terraform init"
                stash allowEmpty: true, includes: "*", name :"build"
            }
        }
       
            stage('Terraform Apply') {
                steps {
                    unstash name: "build"
                    sh 'terraform plan -out=tfplan -input=false && terraform apply -input=false tfplan'
                }
            }
       
                   stage('Install dependencies with Ansible') {
                steps {
                    unstash name: "build"
                    sh "chmod 777 terraform.py; chmod 600 labkey"
                    sh 'ansible-playbook -i terraform.py --private-key labkey playbook.yml'
                }
            }
       }
     }
    
