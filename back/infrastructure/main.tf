# Variables
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "ssh_key_name" {}
variable "ssh_key_local_path" {}
variable "prefix" {}
variable "suffix" {}
variable "domain" {}
variable "subdomain" {}
variable "ecs_image_id" {}  # ADDED


# Provider
provider "alicloud" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

# VPC
resource "alicloud_vpc" "vpc" {
    cidr_block = "192.168.0.0/16"
    name = "${var.prefix}vpc${var.suffix}"
}

# VSwitch
data "alicloud_zones" "zones" {
    available_resource_creation = "VSwitch"
}
resource "alicloud_vswitch" "vswitch" {
    vpc_id = "${alicloud_vpc.vpc.id}"
    availability_zone = "${data.alicloud_zones.zones.zones.0.id}"
    cidr_block = "192.168.0.0/24"
    name = "${var.prefix}vswitch${var.suffix}"
}

# Security group
resource "alicloud_security_group" "sg" {
    vpc_id = "${alicloud_vpc.vpc.id}"
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
    availability_zone = "${data.alicloud_zones.zones.zones.0.id}"
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

# EIP (ecs1)
resource "alicloud_eip" "eip_ecs1" {
    bandwidth = "10"
    name = "${var.prefix}eip1${var.suffix}"
}
resource "alicloud_eip_association" "eip1_asso" {
    allocation_id = "${alicloud_eip.eip_ecs1.id}"
    instance_id   = "${alicloud_instance.ecs1.id}"

    provisioner "local-exec" {
        command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_key_local_path} ../app/target/backend-app-1.0-SNAPSHOT.jar root@${alicloud_eip.eip_ecs1.ip_address}:/usr/local/libexec/"
    }
    provisioner "local-exec" {
        command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_key_local_path} ./provisioner/systemd/microservicesbackendapp.service root@${alicloud_eip.eip_ecs1.ip_address}:/etc/systemd/system/"
    }
    provisioner "remote-exec" {
        script = "./provisioner/ecs-remote-exec.sh"
        connection {
            type = "ssh"
            user = "root"
            private_key = "${file(alicloud_key_pair.keypair_ecs1.key_file)}"
            host = "${alicloud_eip.eip_ecs1.ip_address}"
            timeout = "1m"
        }
    }
}

# SLB
resource "alicloud_slb" "slb" {
    vswitch_id = "${alicloud_vswitch.vswitch.id}"
    name = "${var.prefix}slb${var.suffix}"
    specification = "slb.s1.small"
}
# SLB listener
resource "alicloud_slb_listener" "http80" {
    load_balancer_id = "${alicloud_slb.slb.id}"
    backend_port = 8080
    frontend_port = 80
    protocol = "tcp"
    bandwidth = -1
    health_check_connect_port = 8080
    scheduler = "wlc"
}
# EIP (slb)
resource "alicloud_eip" "eip_slb" {
    bandwidth = "10"
    name = "${var.prefix}eip-slb${var.suffix}"
}
resource "alicloud_eip_association" "eip_slb_asso" {
    allocation_id = "${alicloud_eip.eip_slb.id}"
    instance_id   = "${alicloud_slb.slb.id}"
}

# DNS record
resource "alicloud_dns_record" "record" {
    name = "${var.domain}"
    host_record = "${var.subdomain}"
    type = "A"
    value = "${alicloud_eip.eip_slb.ip_address}"
}

# Auto Scaling Group
resource "alicloud_ess_scaling_group" "asg" {
    vswitch_ids = ["${alicloud_vswitch.vswitch.id}"]
    min_size = 1
    max_size = 1
    removal_policies = ["OldestInstance", "NewestInstance"]
    loadbalancer_ids = ["${alicloud_slb.slb.id}"]

    scaling_group_name = "${var.prefix}asg${var.suffix}"
}
# Auto Scaling Group config
resource "alicloud_ess_scaling_configuration" "config" {
    scaling_group_id  = "${alicloud_ess_scaling_group.asg.id}"
    image_id = "${var.ecs_image_id}"
    instance_type = "${data.alicloud_instance_types.2c4g.instance_types.0.id}"
    security_group_id = "${alicloud_security_group.sg.id}"

    key_name = "${alicloud_key_pair.keypair_ecs1.key_name}"  # re-use the same SSH key as the one used by the ECS 1

    enable = true  # enable asg
    active = true  # active asg config
    force_delete = true  # delete asg when asg config is deleted

    scaling_configuration_name = "${var.prefix}asg-config${var.suffix}"
}
# Auto Scaling Group rule
### It is recommended to use the rule "Target Tracking Scaling Rule", but only "Simple Scaling Rule" can be created by Terraform currently.


# Output
output "[output] vpc id" {
    value = "${alicloud_vpc.vpc.id}"
}
output "[output] ecs1 id" {
    value = "${alicloud_instance.ecs1.id}"
}
output "[output] ecs1 image_id" {
    value = "${alicloud_instance.ecs1.image_id}"
}
output "[output] ecs1 instance_type" {
    value = "${alicloud_instance.ecs1.instance_type}"
}
output "[output] ecs1 keypair_ecs1 key_name" {
    value = "${alicloud_key_pair.keypair_ecs1.key_name}"
}
output "[output] ecs1 eip_ecs1 ip_address" {
    value = "${alicloud_eip.eip_ecs1.ip_address}"
}
output "[output] eip_slb ip_address" {
    value = "${alicloud_eip.eip_slb.ip_address}"
}
output "[output] dns_record ip" {
    value = "${alicloud_dns_record.record.value}"
}
output "[output] dns domain_name" {
    value = "${alicloud_dns_record.record.host_record}.${alicloud_dns_record.record.name}"
}
output "[output] asg id" {
    value = "${alicloud_ess_scaling_group.asg.id}"
}