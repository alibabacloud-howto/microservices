# Variables
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "prefix" {}
variable "suffix" {}
variable "local_external_ip" {}
variable "ssh_key_name" {}  # ADDED
variable "ssh_key_local_path" {}  # ADDED


# Provider
provider "alicloud" {
access_key = "${var.access_key}"
secret_key = "${var.secret_key}"
region = "${var.region}"
}

# VSwitch
# Re-use the same VPC as the one used to the ECS for back-end web application, and create a new VSwitch
data "alicloud_vswitches" "backend_vswitch" {
    name_regex = "${var.prefix}vswitch${var.suffix}"
}
data "alicloud_vpcs" "vpc" {
    vswitch_id = "${alicloud_vswitch.vswitch.id}"
}
resource "alicloud_vswitch" "vswitch" {
    name = "${var.prefix}vswitch${var.suffix}"
    availability_zone = "${data.alicloud_vswitches.backend_vswitch.vswitches.0.zone_id}"
    vpc_id = "${data.alicloud_vswitches.backend_vswitch.vswitches.0.vpc_id}"
    cidr_block = "192.168.1.0/24"
}

# RDS 1
resource "alicloud_db_instance" "rds1" {
    vswitch_id = "${alicloud_vswitch.vswitch.id}"

    engine = "MySQL"
    engine_version = "5.7"
    instance_type = "mysql.n2.small.1"
    instance_storage = "20"
    instance_name = "${var.prefix}rds${var.suffix}"

    security_ips = ["${data.alicloud_vpcs.vpc.vpcs.0.cidr_block}", "${var.local_external_ip}"]
}
# RDS Internet connection
resource "alicloud_db_connection" "connection" {
    instance_id = "${alicloud_db_instance.rds1.id}"
}
# RDS database
resource "alicloud_db_database" "micreservices" {
    instance_id = "${alicloud_db_instance.rds1.id}"
    name = "microservicesdb"
    character_set = "utf8"
    description = "${var.prefix}microservicesdb${var.suffix}"
}
# RDS account
resource "alicloud_db_account" "root" {
    instance_id = "${alicloud_db_instance.rds1.id}"
    name = "root"
    password = "r00tp@ssw0rd"
    type = "Super"
}
resource "alicloud_db_account" "howto" {
    instance_id = "${alicloud_db_instance.rds1.id}"
    name = "howto"
    password = "m!cr0serv!ces"
    type = "Normal"
}
# RDS database previlege
resource "alicloud_db_account_privilege" "readwrite" {
    instance_id = "${alicloud_db_instance.rds1.id}"
    account_name = "${alicloud_db_account.howto.name}"
    privilege = "ReadWrite"
    db_names = ["${alicloud_db_database.micreservices.name}"]
}

# Security Group
resource "alicloud_security_group" "sg" {
    vpc_id = "${data.alicloud_vpcs.vpc.vpcs.0.id}"
    name = "${var.prefix}sg${var.suffix}"
}
resource "alicloud_security_group_rule" "sgr80" {
    security_group_id = "${alicloud_security_group.sg.id}"
    type = "ingress"
    ip_protocol = "tcp"
    nic_type = "intranet"
    policy = "accept"
    port_range = "80/80"
    priority = 1
    cidr_ip = "0.0.0.0/0"
}
resource "alicloud_security_group_rule" "sgr22" {
    security_group_id = "${alicloud_security_group.sg.id}"
    type = "ingress"
    ip_protocol = "tcp"
    nic_type = "intranet"
    policy = "accept"  # accept or drop. (use accept when you need ssh)
    port_range = "22/22"
    priority = 1
    cidr_ip = "0.0.0.0/0"
}

# SSH key pair
resource "alicloud_key_pair" "keypair_ecs1" {
    key_name = "${var.ssh_key_name}"
    key_file = "${var.ssh_key_local_path}"
}

# ECS
data "alicloud_images" "centos" {
    name_regex = "^centos_7.*vhd$"
    most_recent = true
    owners = "system"
}
data "alicloud_instance_types" "2c4g" {
    cpu_core_count = 2
    memory_size = 4
    availability_zone = "${data.alicloud_vswitches.backend_vswitch.vswitches.0.zone_id}"
}
# ECS 1
resource "alicloud_instance" "ecs1" {
    availability_zone = "${alicloud_vswitch.vswitch.availability_zone}"
    security_groups = ["${alicloud_security_group.sg.id}"]
    vswitch_id = "${alicloud_vswitch.vswitch.id}"
    image_id = "${data.alicloud_images.centos.images.0.id}"
    instance_type = "${data.alicloud_instance_types.2c4g.instance_types.0.id}"
    instance_name = "${var.prefix}ecs1${var.suffix}"

    key_name = "${alicloud_key_pair.keypair_ecs1.key_name}"
}

# # EIP (ecs1)
# resource "alicloud_eip" "eip_ecs1" {
#     bandwidth = "10"
#     name = "${var.prefix}eip1${var.suffix}"
# }
# resource "alicloud_eip_association" "eip1_asso" {
#     allocation_id = "${alicloud_eip.eip_ecs1.id}"
#     instance_id   = "${alicloud_instance.ecs1.id}"

#     provisioner "local-exec" {
#         command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_key_local_path} ../app/target/database-app-1.0-SNAPSHOT.jar root@${alicloud_eip.eip_ecs1.ip_address}:/usr/local/libexec/"
#     }
#     provisioner "local-exec" {
#         command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_key_local_path} ./provisioner/systemd/microservicesdatabaseapp.service root@${alicloud_eip.eip_ecs1.ip_address}:/etc/systemd/system/"
#     }
#     provisioner "remote-exec" {
#         script = "./provisioner/ecs-remote-exec.sh"
#         connection {
#             type = "ssh"
#             user = "root"
#             private_key = "${file(alicloud_key_pair.keypair_ecs1.key_file)}"
#             host = "${alicloud_eip.eip_ecs1.ip_address}"
#             timeout = "1m"
#         }
#     }
# }


# Output
output "[output] ecs1 id" {
    value = "${alicloud_instance.ecs1.id}"
}
output "[output] ecs1 image_id" {
    value = "${alicloud_instance.ecs1.image_id}"
}
output "[output] ecs1 private_ip " {
    value = "${alicloud_instance.ecs1.private_ip }"
}
output "[output] ecs1 keypair_ecs1 key_name" {
    value = "${alicloud_key_pair.keypair_ecs1.key_name}"
}
# output "[output] ecs1 eip_ecs1 ip_address" {
#     value = "${alicloud_eip.eip_ecs1.ip_address}"
# }
output "[output] rds1 id" {
    value = "${alicloud_db_instance.rds1.id}"
}
output "[output] rds1 intranet connection endpoint" {
    value = "${alicloud_db_instance.rds1.connection_string}"
}
output "[output] rds1 internet connection endpoint" {
    value = "${alicloud_db_connection.connection.connection_string}"
}
