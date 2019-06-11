variable "region" {
  default = "us-west-1"
}

variable "ami" {
  default = "ami-0a851426a8a56bf4b"
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

resource "aws_subnet" "subnet_b" {
  vpc_id                  = "${aws_vpc.tf_network.id}"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true
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

resource "aws_route_table_association" "public_route_assoc_b" {
  subnet_id      = "${aws_subnet.subnet_b.id}"
  route_table_id = "${aws_route_table.public_rt.id}"
}

resource "aws_key_pair" "edgenda_key" {
  key_name   = "ec2_instance_key_12015"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCold4SfcnZSWyNT3oTZU3inKyUWqUOZYyX0Fpdelkp2nQo1wljW7h9YET0Vt+uzVUeZRZ2qQwGHikOp1+LhlZXBUrTHi1BTrf5d6YpVaColTWer0bef4JvyvGaVKbErq9M0fhnQ9z6eD9rXQBW3dG/EXtMxV3WuNlpzPxADLMc/Aw55I5lOdVxg7IReiLQH82lJLX0q7QUPmjBXDbJ/N5zdyugtEgXQP2cX/y6eoCkfIQfySEdPUqJS3XcZrSsKH2UZoRK9qb11hmG7P86LApwYuq2CDR/fa9Ud/+zIFcs0mrF1olVkaEIBLQsin1U35qiZEkOxzNADwrZkGQaW5lYuEdV5hwjpswCCdPEqShoNb1f4iKy6PzDq6GKbg9cC6lChNm7gEY2EyGe/a1f5fwWPGYsB4p3Md9NhBoPPx/8GLU0m+oesLOo6O0We+ZVHCwDheyT8kAx15KrKB18T4d81xiYvo3CNFQyybbr9qsMEPj5h0OgsUtqDoIuwAVz+NVq6/oCM0nX3OoaRxfRPnVCjX0lnc2VN9nEguBEbaOIxg7KXha1rgEnrxhBu4iMKjPHHigKls8s+rSkNfkAFBnpfXhd9ADPX9v//P9ZuhEhvPvjMYSqfxF6T7RW20YA8sHGPtBVRO8+nomE7yHBlqilTb+3YqEVHMIbU2QxuijUTQ== etiennebrouillard@MacBook-Pro-de-Etienne.local"
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
    from_port   = 80
    to_port     = 80
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
  key_name      = "${aws_key_pair.edgenda_key.key_name}"
  instance_type = "t2.micro"
  count         = 2

  subnet_id                   = "${count.index % 2 == 0 ? aws_subnet.subnet_a.id : aws_subnet.subnet_b.id}"
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
      private_key = "${file("~/.ssh/id_rsa_lab")}"
      host 	  = "${self.public_ip}"
    }

    inline = [
      "sudo apt install -y python",
    ]
  }
}

resource "aws_elb" "lb" {
  name            = "terraform-demo-elb"
  instances       = "${aws_instance.webservers.*.id}"
  security_groups = ["${aws_security_group.allow_http.id}", "${aws_security_group.allow_https.id}", "${aws_security_group.allow_all_out_ipv4.id}", "${aws_security_group.ensure_ssh_ipv4.id}"]
  subnets         = ["${aws_subnet.subnet_a.id}", "${aws_subnet.subnet_b.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}

resource "ansible_host" "default" {
  count              = 2
  inventory_hostname = "${element(aws_instance.webservers.*.id, count.index)}"

  vars = {
    ansible_user = "ubuntu"
    ansible_host = "${element(aws_instance.webservers.*.public_ip, count.index)}"
  }
}