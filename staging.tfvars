region = "ap-southeast-1"

name = "tvlk-stg"

cidr = "172.25.0.0/16"

environment = "staging"

enable_dns_support = "true"

enable_dns_hostnames = "true"

availability_zones = [
  "ap-southeast-1a",
  "ap-southeast-1b",
]

public_subnets = [
  "172.25.192.0/20",
  "172.25.208.0/20",
]

app_subnets = [
  "172.25.0.0/19",
  "172.25.32.0/19",
]

data_subnets = [
  "172.25.128.0/20",
  "172.25.144.0/20",
]

zone_name = "stg.tvlk.cloud"
