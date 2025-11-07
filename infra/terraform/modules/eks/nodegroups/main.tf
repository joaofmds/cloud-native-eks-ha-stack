data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

locals {
  common_tags = merge({
    ManagedBy   = "Terraform",
    Project     = var.project,
    Environment = var.environment,
    Owner       = var.owner,
  }, var.tags)
}

resource "aws_iam_role" "node" {
  for_each = { for k, ng in var.nodegroups : k => ng if !try(ng.node_role_name_override != null && ng.node_role_name_override != "", false) }

  name = "${var.cluster_name}-${each.key}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  for_each   = aws_iam_role.node
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  for_each   = aws_iam_role.node
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  for_each   = aws_iam_role.node
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  for_each   = { for k, ng in var.nodegroups : k => ng if try(ng.enable_ssm, false) && contains(["AL2", "BOTTLEROCKET"], upper(ng.ami_family)) && !try(ng.node_role_name_override != null && ng.node_role_name_override != "", false) }
  role       = aws_iam_role.node[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "node_additional" {
  for_each = {
    for combo in flatten([
      for k, ng in var.nodegroups : [
        for idx, policy_arn in try(ng.additional_policies_arns, []) : {
          key        = "${k}-${idx}"
          role_key   = k
          policy_arn = policy_arn
        }
      ]
      if !try(ng.node_role_name_override != null && ng.node_role_name_override != "", false)
    ]) : combo.key => combo
  }
  role       = aws_iam_role.node[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_instance_profile" "node" {
  for_each = { for k, ng in var.nodegroups : k => ng if !try(ng.node_role_name_override != null && ng.node_role_name_override != "", false) }
  name     = "${var.cluster_name}-${each.key}-instance-profile"
  role     = aws_iam_role.node[each.key].name
  tags     = local.common_tags
}

locals {
  resolved = {
    for k, ng in var.nodegroups : k => merge(ng, {
      _name = coalesce(try(ng.name, null), k)
      _ami_type = coalesce(try(ng.ami_type_override, null),
        upper(ng.ami_family) == "BOTTLEROCKET" ? (contains(ng.instance_types, "t4g.small") || length([for it in ng.instance_types : it if can(regex("^.*g\\..*$", it))]) > 0 ? "BOTTLEROCKET_ARM_64" : "BOTTLEROCKET_X86_64")
      : (length([for it in ng.instance_types : it if can(regex("^.*g\\..*$", it))]) > 0 ? "AL2_ARM_64" : "AL2_x86_64"))
    })
  }
}

resource "aws_launch_template" "managed" {
  for_each = var.default_security_group_id != null ? { for k, ng in local.resolved : k => ng if try(ng.launch_template, null) == null } : {}

  name_prefix   = "${var.cluster_name}-${each.key}-"
  update_default_version = true

  vpc_security_group_ids = [var.default_security_group_id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.cluster_name}-${each.value._name}"
    })
  }
}

locals {
  effective_launch_templates = {
    for k, ng in local.resolved :
    k => (
      try(ng.launch_template, null) != null ? ng.launch_template :
      (var.default_security_group_id != null && contains(keys(aws_launch_template.managed), k) ? {
        id      = aws_launch_template.managed[k].id
        version = aws_launch_template.managed[k].latest_version
      } : null)
    )
  }
}

resource "aws_eks_node_group" "this" {
  for_each        = local.resolved
  cluster_name    = var.cluster_name
  node_group_name = each.value._name
  node_role_arn   = each.value.node_role_name_override != null && each.value.node_role_name_override != "" ? "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/${each.value.node_role_name_override}" : aws_iam_role.node[each.key].arn

  subnet_ids     = var.subnet_ids
  capacity_type  = upper(each.value.capacity_type)
  instance_types = each.value.instance_types
  ami_type       = each.value._ami_type
  disk_size      = try(each.value.disk_size, 40)
  version        = var.cluster_version

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = try(each.value.desired_size, null)
  }

  dynamic "remote_access" {
    for_each = try(each.value.remote_access.enabled, false) ? [1] : []
    content {
      ec2_ssh_key               = try(each.value.remote_access.ec2_key_name, null)
      source_security_group_ids = try(each.value.remote_access.source_security_group_ids, [])
    }
  }

  labels = try(each.value.labels, {})

  dynamic "taint" {
    for_each = try(each.value.taints, [])
    content {
      key    = taint.value.key
      value  = try(taint.value.value, null)
      effect = upper(taint.value.effect) # NO_SCHEDULE | NO_EXECUTE | PREFER_NO_SCHEDULE
    }
  }

  dynamic "update_config" {
    for_each = [1]
    content {
      max_unavailable            = try(each.value.update_max_unavailable, null)
      max_unavailable_percentage = try(each.value.update_max_unavailable_percentage, 33)
    }
  }

  dynamic "launch_template" {
    for_each = local.effective_launch_templates[each.key] != null ? [local.effective_launch_templates[each.key]] : []
    content {
      id      = launch_template.value.id
      version = launch_template.value.version
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-${each.value._name}" })
}

