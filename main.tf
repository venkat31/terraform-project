
resource "aws_vpc" "my-demo-vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
    tags = {
        Name = "Demo-VPC"
  }
}

resource "aws_subnet" "my-public-subnet" {
    cidr_block = "10.0.0.0/24"
    vpc_id = aws_vpc.my-demo-vpc.id
    availability_zone = "us-west-2a"
    tags = {
        Name = "PublicSubnet"
    }  
}

resource "aws_subnet" "my-private-subnet"{
    cidr_block = "10.0.1.0/24"
    vpc_id = aws_vpc.my-demo-vpc.id
     availability_zone = "us-west-2b"

    tags = {
        Name = "PrivateSubnet"
    }
}

resource "aws_internet_gateway" "my_igw" {
    vpc_id = aws_vpc.my-demo-vpc.id
    tags = {
        Name = "MY-Internet_gateway"
    }
}

resource "aws_route_table" "public_route_table"{
    vpc_id = aws_vpc.my-demo-vpc.id
    tags = {
      Name = "Public-Route_table"
    }
    route {
        cidr_block =  "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table_association" "public_subnet_association"{
    subnet_id = aws_subnet.my-public-subnet.id
    route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private-route-table"{
    vpc_id = aws_vpc.my-demo-vpc.id
    tags = {
        Name = "My-Private-RouteTable"
    }
}

resource "aws_route_table_association" "private_subnet_association" {
    subnet_id = aws_subnet.my-private-subnet.id
    route_table_id = aws_route_table.private-route-table.id
}

data "aws_ami" "amazon-linux-latest"{
    most_recent = true
    owners = ["amazon"]
    filter {
        name   = "name"
        values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
    filter {
        name   = "root-device-type"
        values = ["ebs"]
    }
    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_security_group" "my_security_group" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my-demo-vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.my_ip]
  }

  ingress {
    description      = "Web Access"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Jenkins Ec2 Security Group"
  }
}

# resource "aws_key_pair" "ec2_key_pair"{
#     key_name = "own_ssh_key"
#     public_key = file(var.public_key_location)
# }

resource "aws_instance" "ec2_jenkins" {
    ami = data.aws_ami.amazon-linux-latest.id
    instance_type = "t2.micro"
    subnet_id = aws_subnet.my-public-subnet.id
    availability_zone = "us-west-2a"
    associate_public_ip_address = true

    # key_name = aws_key_pair.ec2_key_pair.key_name
    key_name = "own_ssh_key"
    

    vpc_security_group_ids = [aws_security_group.my_security_group.id]

    user_data = <<-EOF
        #!/bin/bash
        sudo amazon-linux-extras install java-openjdk11 -y
        sudo wget -O /etc/yum.repos.d/jenkins.repo \
            https://pkg.jenkins.io/redhat-stable/jenkins.repo
        sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
        sudo yum upgrade -y 
        # Add required dependencies for the jenkins package
        sudo yum install git -y
        sudo yum install jenkins -y
        sudo systemctl daemon-reload
        sudo systemctl enable jenkins
        sudo systemctl start jenkins
        EOF

    tags = {
        Name = "My Jenkins Server"
    }

}
