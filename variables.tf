#
# Variables Configuration
#

variable "cluster-name" {
  default = "eks-robmetrics"
  type    = "string"
}

# from  https://cwong47.gitlab.io/technology-terraform-aws-efs/

variable "name" {
  description = "(Required) The reference_name of your file system. Also, used in tags."
  type        = "string"
  default = "efs"
}

#variable "region" {
#  description = "(Optional) The region of your file system."
#  type        = "string"
#  default     = "us-east-1"
#}

variable "environment" {
  description = "(Required) The environment of your file system. Also, used in tags."
  type        = "string"
  default     = "test"
}

variable "cluster_num" {
  description = "(Optional) The cluster number of your file system. Also, used in tags."
  type        = "string"
  default     = "01"
}

variable "performance_mode" {
  description = "(Optional) The performance mode of your file system."
  type        = "string"
  default     = "generalPurpose"
}

#variable "vpc_id" {
#  description = "(Required) The VPC ID where NFS security groups will be."
#  type        = "string"
#  default     = "${aws_vpc.robmetrics.id}"
#}

#variable "subnets" {
#  description = "(Required) A comma separated list of subnet ids where mount targets will be."
#  type        = "list"
#}

#variable "allowed_cidr_blocks" {
#  description = "(Required) A comma separated list of CIDR blocks allowed to mount target."
#  type        = "list"
#}

