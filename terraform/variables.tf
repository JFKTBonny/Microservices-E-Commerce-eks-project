variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for EKS"
  type        = list(string)
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}

variable "filepath_manifest" {
  description = "Path to kustomize directory"
  type        = string
}

variable "vpc_cidr" {}

variable "memorystore" {
    type = bool
    description = "If true, Online Boutique's in-cluster Redis cache will be replaced with a Google Cloud Memorystore Redis cache"
}

variable "private_subnet_ids" {}
