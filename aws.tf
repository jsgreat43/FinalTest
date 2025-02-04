resource "aws_vpc" "awsvpc" {
  cidr_block           = "192.168.1.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags                 =
    { 
        name           = "dt2-vpc"
    }
}

resource "aws_internet_gateway" "awsipg" {
  vpc_id               = "${aws_vpc.awsvpc.id}"
  tags                 = 
    { 
      name             = "dt2-igw"
    }
}

resource "aws_subnet" "public_1a" {
  vpc_id               = "${aws_vpc.awsvpc.id}"
  availability_zone    = "ap-northeast-2a"
  cidr_block           = "192.168.1.0/25"
  tags                 =
    { 
       name            = "dt2-public-1a"
    }
}

resource "aws_subnet" "public_1b" {
  vpc_id               = "${aws_vpc.awsvpc.id}"
  availability_zone    = "ap-northeast-2c"
  cidr_block           = "192.168.1.128/25"
  tags                 =
    {  
      name             = "dt2-public-1b"
    }
}

resource "aws_eip" "awseip3" {
  vpc = false
  tags={name="dt2-eip3"}
}

resource "aws_eip" "awseip4" {
  vpc = false
  tags={name="dt2-eip4"}
}

resource "aws_nat_gateway" "natgate_1a" {
  allocation_id = "${aws_eip.awseip3.id}"
  subnet_id     = "${aws_subnet.public_1a.id}"
  tags={name="dt2-ngw-1a"}
}

resource "aws_nat_gateway" "natgate_1b" {
  allocation_id = "${aws_eip.awseip4.id}"
  subnet_id     = "${aws_subnet.public_1b.id}"
  tags={name="dt2-ngw-1b"}
}

resource "aws_route_table" "awsrtp" {
  vpc_id = "${aws_vpc.awsvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.awsipg.id}"
  }
  
  tags={name="dt2-rt"}
}

resource "aws_route_table_association" "awsrtp1a" {
  subnet_id      = "${aws_subnet.public_1a.id}"
  route_table_id = "${aws_route_table.awsrtp.id}"
  
}

resource "aws_route_table_association" "aiwsrtp1b" {
  subnet_id      = "${aws_subnet.public_1b.id}"
  route_table_id = "${aws_route_table.awsrtp.id}"
  
}

resource "aws_default_security_group" "awssecurity" {
  vpc_id = "${aws_vpc.awsvpc.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags={name="dt2-dsg"}
} 

resource "aws_default_network_acl" "awsnetworkacl" {
  default_network_acl_id = "${aws_vpc.awsvpc.default_network_acl_id}"

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  subnet_ids = [
    "${aws_subnet.public_1a.id}",
    "${aws_subnet.public_1b.id}",
  ]
  
  tags={name="dt2-nacl"}
}

variable "amazon_linux" {
  # Amazon Linux AMI 2017.03.1 (HVM), SSD Volume Type - ami-4af5022c
  default = "ami-095ca789e0549777d"
}

resource "aws_security_group" "webserverSecurutyGroup" {
  name        = "webserverSecurutyGroup"
  description = "open ssh port for webserverSecurutyGroup"

  vpc_id = "${aws_vpc.awsvpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags={name="dt2-websg"}
}

resource "aws_instance" "web1" {
  ami               = "${var.amazon_linux}"
  availability_zone = "ap-northeast-2a"
  instance_type     = "t2.micro"
  key_name = "sre-aws-mgmtvm-test"
  vpc_security_group_ids = [
    "${aws_security_group.webserverSecurutyGroup.id}",
    "${aws_default_security_group.awssecurity.id}",
  ]

  subnet_id                   = "${aws_subnet.public_1a.id}"
  associate_public_ip_address = true
  tags={name="dt2-web1"}
}

resource "aws_instance" "web2" {
  ami               = "${var.amazon_linux}"
  availability_zone = "ap-northeast-2c"
  instance_type     = "t2.micro"
  key_name = "sre-aws-mgmtvm-test"	
  vpc_security_group_ids = [
    "${aws_security_group.webserverSecurutyGroup.id}",
    "${aws_default_security_group.awssecurity.id}",
  ]
				
  subnet_id                   = "${aws_subnet.public_1b.id}"
  associate_public_ip_address = true
  tags={name="dt2-web2"}
}
	
resource "aws_alb" "frontend" {
  name            = "dt2-alb"
  internal        = false
  security_groups = ["${aws_security_group.webserverSecurutyGroup.id}"]
  subnets         = [
    "${aws_subnet.public_1a.id}",
    "${aws_subnet.public_1b.id}"
  ]
  lifecycle { create_before_destroy = true }
  tags={name="dt2-alb"}
}

resource "aws_alb_target_group" "frontendalb" {
  name     = "dt2-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.awsvpc.id}"

  health_check {
    interval            = 30
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3				
  }
  tags={name="dt2-alb-tg"}
}

resource "aws_alb_target_group_attachment" "frontend1" {
  target_group_arn = "${aws_alb_target_group.frontendalb.arn}"
  target_id        = "${aws_instance.web1.id}"
  port             = 80
}

resource "aws_alb_target_group_attachment" "frontend2" {
  target_group_arn = "${aws_alb_target_group.frontendalb.arn}"
  target_id        = "${aws_instance.web2.id}"
  port             = 80
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = "${aws_alb.frontend.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.frontendalb.arn}"
    type             = "forward"
  }
}
