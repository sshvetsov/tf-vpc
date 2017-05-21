/* Backend */

terraform {
  backend "s3" {
    bucket     = "tvlk-stg-tfstate"
    key        = "vpc/tvlk-stg.tfstate"
    region     = "ap-southeast-1"
    encrypt    = true
    lock_table = "tvlk-stg-tflock"
  }
}

/* Vars */

variable "region" {
  description = "AWS region"
  type        = "string"
}

variable "cidr" {
  description = "CIDR block for VPC"
  type        = "string"
}

variable "enable_dns_support" {
  description = "Whether to enable DNS support"
  type        = "string"
}

variable "enable_dns_hostnames" {
  description = "Whether to enable DNS hostnames"
  type        = "string"
}

variable "name" {
  description = "VPC name"
  type        = "string"
}

variable "environment" {
  description = "Value of 'Environment' tag"
  type        = "string"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = "list"
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = "list"
}

variable "app_subnets" {
  description = "List of application subnet CIDRs"
  type        = "list"
}

variable "data_subnets" {
  description = "List of data subnet CIDRs"
  type        = "list"
}

variable "zone_name" {
  description = "Name of the hosted Route 53 zone"
  type        = "string"
}

/* Providers */

provider "aws" {
  region = "${ var.region }"
}

/* VPC */

resource "aws_vpc" "main" {
  cidr_block           = "${var.cidr}"
  enable_dns_support   = "${var.enable_dns_support}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"

  tags {
    Name        = "${var.name}"
    Environment = "${var.environment}"
  }
}

/* Internet Gateway */

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name        = "${var.name}"
    Environment = "${var.environment}"
  }
}

/* Subnets */

resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${element(var.public_subnets, count.index)}"
  availability_zone       = "${element(var.availability_zones, count.index)}"
  count                   = "${length(var.public_subnets)}"
  map_public_ip_on_launch = true

  tags {
    Name        = "${var.name}-${format("pub-%03d", count.index+1)}"
    Tier        = "public"
    Environment = "${var.environment}"
  }
}

resource "aws_subnet" "app" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${element(var.app_subnets, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  count             = "${length(var.app_subnets)}"

  tags {
    Name        = "${var.name}-${format("app-%03d", count.index+1)}"
    Tier        = "app"
    Environment = "${var.environment}"
  }
}

resource "aws_subnet" "data" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${element(var.data_subnets, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  count             = "${length(var.data_subnets)}"

  tags {
    Name        = "${var.name}-${format("data-%03d", count.index+1)}"
    Tier        = "data"
    Environment = "${var.environment}"
  }
}

/* NAT Gateways */

resource "aws_eip" "nat" {
  count = "${length(var.public_subnets)}"
  vpc   = true
}

resource "aws_nat_gateway" "main" {
  count         = "${length(var.public_subnets)}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  depends_on    = ["aws_internet_gateway.main"]
}

/* Route Tables */

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name        = "${var.name}-public-001"
    Environment = "${var.environment}"
  }
}

resource "aws_route" "public" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

resource "aws_route_table" "app" {
  count  = "${length(var.app_subnets)}"
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name        = "${var.name}-${format("app-%03d", count.index+1)}"
    Environment = "${var.environment}"
  }
}

resource "aws_route" "app" {
  count                  = "${length(compact(var.app_subnets))}"
  route_table_id         = "${element(aws_route_table.app.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.main.*.id, count.index)}"
}

resource "aws_route_table" "data" {
  count  = "${length(var.data_subnets)}"
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name        = "${var.name}-${format("data-%03d", count.index+1)}"
    Environment = "${var.environment}"
  }
}

resource "aws_route" "data" {
  count                  = "${length(compact(var.data_subnets))}"
  route_table_id         = "${element(aws_route_table.data.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.main.*.id, count.index)}"
}

/* Route associations */

resource "aws_route_table_association" "public" {
  count          = "${length(var.public_subnets)}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "app" {
  count          = "${length(var.app_subnets)}"
  subnet_id      = "${element(aws_subnet.app.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.app.*.id, count.index)}"
}

resource "aws_route_table_association" "data" {
  count          = "${length(var.data_subnets)}"
  subnet_id      = "${element(aws_subnet.data.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.data.*.id, count.index)}"
}

/* DNS */

resource "aws_route53_zone" "main" {
  name   = "${var.zone_name}"
  vpc_id = "${aws_vpc.main.id}"

  tags {
    VPC         = "${var.name}"
    Environment = "${var.environment}"
  }
}

/* DHCP */

resource "aws_vpc_dhcp_options" "main" {
  domain_name = "${aws_route53_zone.main.name}"

  tags {
    Name        = "${var.name}"
    Environment = "${var.environment}"
  }
}

/* DHCP Association */

resource "aws_vpc_dhcp_options_association" "main" {
  vpc_id          = "${aws_vpc.main.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.main.id}"
}
