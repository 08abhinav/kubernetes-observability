variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "observability-cluster"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
