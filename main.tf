#################################################################################################################################
# Data Blocks
#################################################################################################################################

data "template_file" "application1_install" {
  template = file("${path.module}/application1_install.tpl")
}

data "template_file" "application2_install" {
  template = file("${path.module}/application2_install.tpl")
}

#################################################################################################################################
#Locals
#################################################################################################################################

locals {
  vpc_cidr1    = "10.${var.pod_number}.0.0/16"
  vpc_cidr2    = "10.${var.pod_number + 100}.0.0/16"
  subnet_cidr1 = "10.${var.pod_number}.100.0/24"
  subnet_cidr2 = "10.${var.pod_number + 100}.100.0/24"
  app1_nic     = ["10.${var.pod_number}.100.10"]
  app2_nic     = ["10.${var.pod_number + 100}.100.10"]
}

#################################################################################################################################
#Application VPC & Subnet
#################################################################################################################################

resource "aws_vpc" "app_vpc" {
  count                = 2
  cidr_block           = count.index == 0 ? local.vpc_cidr1 : local.vpc_cidr2
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = "pod${var.pod_number}-app${count.index + 1}-vpc"
  }
}

resource "aws_subnet" "app_subnet" {
  count      = 2
  vpc_id     = aws_vpc.app_vpc["${count.index}"].id
  cidr_block = count.index == 0 ? local.subnet_cidr1 : local.subnet_cidr2
  tags = {
    Name = "pod${var.pod_number}-app${count.index + 1}-subnet"
  }
}

#################################################################################################################################
# Keypair
#################################################################################################################################

resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.key_pair.private_key_openssh
  filename        = "mcd-keypair"
  file_permission = 0700
}

resource "aws_key_pair" "sshkeypair" {
  key_name   = "mcd-keypair"
  public_key = tls_private_key.key_pair.public_key_openssh
}

#################################################################################################################################
# EC2 Instance
#################################################################################################################################

resource "aws_instance" "AppMachines" {
  count         = 2
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.micro"
  key_name      = "mcd-keypair"
  user_data     = count.index == 0 ? data.template_file.application1_install.rendered : data.template_file.application2_install.rendered
  network_interface {
    network_interface_id = aws_network_interface.application_interface["${count.index}"].id
    device_index         = 0
  }

  tags = {
    Name = "app${count.index + 1}"
  }
}

resource "aws_network_interface" "application_interface" {
  count = 2

  subnet_id   = aws_subnet.app_subnet["${count.index}"].id
  private_ips = count.index == 0 ? local.app1_nic : local.app2_nic
  tags = {
    Name = "app${count.index + 1}-nic"
  }
}

#################################################################################################################################
# Internet Gateway
#################################################################################################################################

resource "aws_internet_gateway" "int_gw" {
  count  = 2
  vpc_id = aws_vpc.app_vpc["${count.index}"].id
  tags = {
    Name = "app${count.index + 1}-igw"
  }
}


# #################################################################################################################################
# #Elastic IP
# #################################################################################################################################

resource "aws_eip" "app-EIP" {
  count  = 2
  domain = "vpc"
  tags = {
    Name = "app${count.index + 1}-eip"
  }
}

resource "aws_eip_association" "app-eip-assocation" {
  count                = 2
  network_interface_id = aws_network_interface.application_interface["${count.index}"].id
  allocation_id        = aws_eip.app-EIP[count.index].id
}

# #################################################################################################################################
# #Security Group
# #################################################################################################################################

resource "aws_security_group" "allow_all" {
  count  = 2
  name   = "app-sg${count.index + 1}"
  vpc_id = aws_vpc.app_vpc["${count.index}"].id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_network_interface_sg_attachment" "app-sg" {
  count                = 2
  security_group_id    = aws_security_group.allow_all["${count.index}"].id
  network_interface_id = aws_network_interface.application_interface[count.index].id
}

##################################################################################################################################
#Routing Tables and Routes
##################################################################################################################################

resource "aws_route_table" "app-route" {
  count  = 2
  vpc_id = aws_vpc.app_vpc["${count.index}"].id
  tags = {
    Name = "app-rt${count.index + 1}"
  }
}

resource "aws_route" "ext_default_route" {
  count                  = 2
  route_table_id         = aws_route_table.app-route["${count.index}"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.int_gw["${count.index}"].id
}

resource "aws_route_table_association" "app_association" {
  count          = 2
  subnet_id      = aws_subnet.app_subnet["${count.index}"].id
  route_table_id = aws_route_table.app-route["${count.index}"].id
}

##################################################################################################################################
# Outputs
##################################################################################################################################

output "app1-public-ip" {
  value = aws_eip.app-EIP[0].public_ip
}

output "app2-public-ip" {
  value = aws_eip.app-EIP[1].public_ip
}

output "Command_to_use_for_ssh_into_application_vms" {
  value = "ssh -i mcd-keypair ubuntu@<app-ip-address>"
}
