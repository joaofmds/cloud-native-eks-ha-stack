resource "aws_eks_addon" "vpc_cni" {
  count     = var.enable_core_addons ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "vpc-cni"
  addon_version = var.addon_vpc_cni_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags = local.common_tags
}

resource "aws_eks_addon" "coredns" {
  count     = var.enable_core_addons ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = var.addon_coredns_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [aws_eks_cluster.this]
  tags = local.common_tags
}

resource "aws_eks_addon" "kube_proxy" {
  count     = var.enable_core_addons ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  addon_version = var.addon_kube_proxy_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [aws_eks_cluster.this]
  tags = local.common_tags
}