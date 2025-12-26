variable "pr_number" {
  description = "The pull request number"
  type        = number
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "The availability zones for the VPC"
  type        = list(string)
}

variable "subnet_cidr_blocks" {
  description = "List of CIDR blocks for subnets (2 public, 2 private)"
  type        = list(string)
}
