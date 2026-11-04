variable "cluster_version" {
  description = "Supported Kubernetes version for EKS"
  type        = string
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Your public IP allowed to access the EKS API"
  type        = list(string)
}