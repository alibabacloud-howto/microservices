# Variables
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "prefix" {}
variable "suffix" {}
variable "domain" {}  # ADDED
variable "subdomain" {}  # ADDED

# Provider
provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

# OSS
resource "alicloud_oss_bucket" "oss" {
  bucket = "${var.prefix}oss${var.suffix}"
  acl = "private"

  website = {
    index_document = "index.html"
  }
}

# CDN
resource "alicloud_cdn_domain_new" "domain" {
  domain_name = "${var.subdomain}.${var.domain}"
  cdn_type = "web"
  scope = "overseas"  # domestic, overseas, global.
  sources {
      content = "${alicloud_oss_bucket.oss.id}.${alicloud_oss_bucket.oss.extranet_endpoint}"
      type = "oss"
      port = 80
  }
}

# DNS record
resource "alicloud_dns_record" "record" {
  name = "${var.domain}"
  host_record = "${var.subdomain}"
  type = "CNAME"
  value = "${alicloud_cdn_domain_new.domain.domain_name}.w.kunlunsl.com"
}


# Output
output "[output] oss id" {
  value = "${alicloud_oss_bucket.oss.id}"
}
output "[output] oss extranet_endpoint" {
  value = "${alicloud_oss_bucket.oss.extranet_endpoint}"
}
output "[output] cdn domain_name" {
  value = "${alicloud_cdn_domain_new.domain.domain_name}"
}
