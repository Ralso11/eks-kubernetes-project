output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "API endpoint for the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}
