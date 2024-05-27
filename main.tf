resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr
}
resource "aws_subnet" "subnet1" {
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
}
resource "aws_subnet" "subnet2" {
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
}
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.my_vpc.id
  
}
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.my_vpc.id

  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.RT.id
}
resource "aws_security_group" "websg" {
  name        = "websg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.my_vpc.id
  
  ingress {
    description = "http"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
    ingress {
    description = "SSH"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags={
    name="Web-sg"
  }
}
resource "aws_s3_bucket" "example" {
  bucket = "karansinghuniquebucket"
}

resource "aws_instance" "webserver1" {
 ami = "ami-04b70fa74e45c3917"
 instance_type = "t2.micro"
 vpc_security_group_ids = [ aws_security_group.websg.id ]
 subnet_id = aws_subnet.subnet1.id
 user_data = base64encode(file("userdata.sh"))
}
resource "aws_instance" "webserver2" {
 ami = "ami-04b70fa74e45c3917"
 instance_type = "t2.micro"
 vpc_security_group_ids = [ aws_security_group.websg.id ]
 subnet_id = aws_subnet.subnet2.id
 user_data = base64encode(file("userdata1.sh"))
}


#Creating Load Balancer 
resource "aws_lb" "loadbal1" {
  name = "myalb"
  internal = false
  load_balancer_type = "application"
  security_groups = [ aws_security_group.websg.id ]
  subnets = [ aws_subnet.subnet1.id,aws_subnet.subnet2.id ]
  tags = {
    name="web"
  }
}
resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
}
resource "aws_lb_target_group_attachment" "attach1" {
    target_group_arn = aws_lb_target_group.test.arn
    target_id =  aws_instance.webserver1.id
    port = 80
}
resource "aws_lb_target_group_attachment" "attach2" {
    target_group_arn = aws_lb_target_group.test.arn
    target_id =  aws_instance.webserver2.id
    port = 80
}
resource "aws_lb_listener" "listener1" {
  load_balancer_arn = aws_lb.loadbal1.arn
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.test.arn
    type = "forward"
  }
}
output "loadbalancerdns" {
  value = aws_lb.loadbal1.dns_name
}


