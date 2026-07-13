provider "aws" {

    region = "us-east-1"
  
}

resource "aws_key_pair" "kp" {
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCX1V8xG/4LAoXv0BL1ddlE+NKjQuGOl8mdKsZxFrKf6vKgs60QKTySa3S1guUQp8Tvw7JO0CUy0GNB+GX/9TkpxtOcr4iGvPHSUG2eokLDavhKHT7VuipUMJSz1kxbjKh6DONkrGt+JXXbUhVpoEFzBWVVABuzhv6rjj31zeCdK1TGak2E0BTRSpm4d3gRfRoDCLZpsMf1SX3KMpcg3FdxFGOX4XLyxlTjiT9PyYRlHjP2o4OG4343fa+c98O3ZsXbuD0Vr39Mcb4SSKyFL98t9W37vnWusKhUJutMcwvbEUBfP0n01Tafkc49gfMxgsNHwiL6xkLRGqeD6iODR59pwL8JGe0590wImj0LnXukhS7d8j2No4xoRj8q+kKYZWTxeTgOac8KT9cgo/L2WUqJW5fFaVhehZVukrMchJ1vgFnTZmlHT2w0rpe3M7E0UPaOOIJ5S1T1n0fEAEjUjjuE4QSl8erFmk90qp/IEIRtTZq8PO+3LCwhe75BXoN6gSk= prudh@Prudhvi"
    key_name = "my-key"
  
}

resource "aws_vpc" "myvpc" {

    cidr_block = "172.20.0.0/16"
    enable_dns_hostnames = true
    tags = {
      Name = "myvpc"
    }
  
}

resource "aws_subnet" "pubsnt" {

    vpc_id = aws_vpc.myvpc.id
    cidr_block = "172.20.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    tags = {
      Name = "pubsnt"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id

    tags = {
      Name = "igw"
    }
  
}

resource "aws_route_table" "pubrt" {

    vpc_id = aws_vpc.myvpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
      Name = "pubrt"
    }
  
}

resource "aws_route_table_association" "pubrtassocaition" {
    subnet_id = aws_subnet.pubsnt.id
    route_table_id = aws_route_table.pubrt.id
}

resource "aws_security_group" "jenkinssg" {
    vpc_id = aws_vpc.myvpc.id
    name = "jenkinssg"

    ingress {
    description = "Jenkins HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Ping"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "SonarQube HTTP"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "allow outbound"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkinssg"
  }
  
}

resource "aws_security_group" "appsg" {
    vpc_id = aws_vpc.myvpc.id
    name = "appsg"

    ingress {
    description = "app HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Ping"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "allow outbound"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "appsg"
  }
  
}

resource "aws_instance" "jenkinsinst" {
    ami = "ami-01edba92f9036f76e"
    instance_type = "c7i-flex.large"
    key_name = aws_key_pair.kp.key_name
    subnet_id = aws_subnet.pubsnt.id
    vpc_security_group_ids = [aws_security_group.jenkinssg.id]

    connection {
      type = "ssh"
      host = self.public_ip
      user = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
    }

    provisioner "remote-exec" {

        inline = [ 
            "sudo yum update -y",
            "sudo yum install java-21-amazon-corretto -y",
            "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
            "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key",
            "sudo yum install jenkins -y",
            "sudo systemctl enable jenkins && sudo systemctl start jenkins",
            "sudo yum install wget git maven ansible docker -y",
            "sudo systemctl enable docker && sudo systemctl start docker",
            "sudo usermod -aG docker ec2-user",
            "sudo usermod -aG docker jenkins",
            "sudo chmod 666 /var/run/docker.sock",
            "sudo docker run -d --name sonarct -p 9000:9000 sonarqube",
            "sudo rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.18.3/trivy_0.18.3_Linux-64bit.rpm"
        ]
      
    }
    tags = {
      Name = "jenkins terrafrom"
    }
  
}

resource "aws_instance" "appinst" {

    ami = "ami-01edba92f9036f76e"
    instance_type = "c7i-flex.large"
    key_name = aws_key_pair.kp.key_name
    subnet_id = aws_subnet.pubsnt.id
    vpc_security_group_ids = [aws_security_group.appsg.id]

    tags = {
      Name = "my app terraform"
    }
  
}

