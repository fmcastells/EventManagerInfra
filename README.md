# EventManagerInfra

For Pipeline:

Stage Prepare

step: Download terraform ansible:
sh -c "wget https://github.com/nbering/terraform-provider-ansible/releases/download/v1.0.3/terraform-provider-ansible-linux_amd64.zip"

step: Unzip terrafor ansible:
sh - "unzip terraform-provider-ansible-linux_amd64.zip"

step: Move package to right folder:
sh -c "mv linux_amd64 ~/.terraform.d/plugins/"

step: Prepare to generate machine
sh -c "terraform init"

step: Generate machines
sh -c "terraform apply"

step: Install nginx and docker
sh -c "ansible-playbook -i terraform.py --private-key labkey playbook.yml"
