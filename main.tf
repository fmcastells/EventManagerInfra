terraform {
  backend "s3" {
    bucket = "bncpd-tf-lab3-12015"
    key    = "bncpdlab3vm12015tfstate"
    region = "eu-west-1"
  }
}

variable "region" {
  default = "us-west-2"
}

variable "ami" {
  default = "ami-0475f60cdd8fd2120"
}

provider "aws" {
  region = "${var.region}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_vpc" "tf_network" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.tf_network.id}"
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = "${aws_vpc.tf_network.id}"
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}b"
  depends_on              = ["aws_internet_gateway.gateway"]
}

resource "aws_route_table" "public_rt" {
  vpc_id = "${aws_vpc.tf_network.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }
}

resource "aws_route_table_association" "public_route_assoc_a" {
  subnet_id      = "${aws_subnet.subnet_a.id}"
  route_table_id = "${aws_route_table.public_rt.id}"
}

resource "aws_key_pair" "yakine_key" {
  key_name   = "yakine_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDGOP1cg7AHC/N1eImga+VLHzLq0OFAx7cwot/Ft/4s7iB1EGrV7nOrMD36x0NKYq/WNez8wsl8OIUWHuuiSxORnL3fd5xW6K287BKZh1OYbQw4E/0W1OYNnhiweqVfHNkU74Q7XG7/yLB+nzsj3Smg2BQA5Ny6uDyOtcwstiWLyHbWDCkmR0ljUF7/hB+q/FcijJaqdos2ziY6HIiXx8oQ6OKi+FZAPtJ+XZDKpGS/xyt1CkEGLHJXkuBOgI5rJSMH/3EIcexjC/PyfgrdaBLsd5SpL2MrVYj1OKS3alJod3UHWiIe6yMhVYSEKAcrUW7Kom16xpL009WvmP6A4AGp simf003@C02YJ0KMJG5H.local"
}

resource "aws_security_group" "ensure_ssh_ipv4" {
  vpc_id = "${aws_vpc.tf_network.id}"
  name   = "Ensure_SSH_Allow_All_IPV4"

  ingress {
    to_port     = 22
    from_port   = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_http" {
  vpc_id = "${aws_vpc.tf_network.id}"
  name   = "allow_http"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_https" {
  vpc_id = "${aws_vpc.tf_network.id}"
  name   = "allow_https"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_all_out_ipv4" {
  vpc_id = "${aws_vpc.tf_network.id}"
  name   = "Allow_All_Out_IPV4"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "webservers" {
  ami           = "${data.aws_ami.ubuntu.id}"
  key_name      = "${aws_key_pair.yakine_key.key_name}"
  instance_type = "t2.micro"
  count         = 1

  subnet_id                   = "${aws_subnet.subnet_a.id}"
  associate_public_ip_address = "true"

  vpc_security_group_ids = [
    "${aws_security_group.ensure_ssh_ipv4.id}",
    "${aws_security_group.allow_all_out_ipv4.id}",
    "${aws_security_group.allow_http.id}",
    "${aws_security_group.allow_https.id}",
  ]

  provisioner "remote-exec" {
    connection {
      user        = "ubuntu"
      private_key = "${file("labkey")}"
      host 	  = "${self.public_ip}"
    }

    inline = [
      "sudo apt install -y python",
    ]
  }
}

resource "ansible_host" "webserver" {
  count              = 1
  inventory_hostname = "${element(aws_instance.webservers.*.id, count.index)}"
  groups = ["webserver"]

  vars = {
    ansible_user = "ubuntu"
    ansible_host = "${element(aws_instance.webservers.*.public_ip, count.index)}"
  }
}
