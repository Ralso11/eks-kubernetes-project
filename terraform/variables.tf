variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name used to prefix and tag all resources in this project"
  type        = string
  default     = "eks-kubernetes-project"
}

variable "vpc_cidr" {
  description = "IP address range for the VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "subnet_a_cidr" {
  description = "IP address range for subnet in availability zone A"
  type        = string
  default     = "10.2.1.0/24"
}

variable "subnet_b_cidr" {
  description = "IP address range for subnet in availability zone B"
  type        = string
  default     = "10.2.2.0/24"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}
