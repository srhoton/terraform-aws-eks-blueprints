provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
  }
}

locals {
  name   = basename(path.cwd)
  region = "us-west-2"

  node_group_name = "self-ondemand"
  cluster_version = "1.21"
  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]

  tags = {
    Blueprint  = local.name
    GithubRepo = "terraform-aws-eks-blueprints"
  }
}

#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------
module "eks_blueprints" {
  source = "../.."

  cluster_name    = local.name
  cluster_version = local.cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  node_security_group_additional_rules = {
    ingress_nodes_karpenter_port = {
      description                   = "Cluster API to Nodegroup for Karpenter"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # Karpenter requires one node to get up and running
  self_managed_node_groups = {
    self_mg_4 = {
      node_group_name    = local.node_group_name
      launch_template_os = "amazonlinux2eks"
      max_size           = 1
      subnet_ids         = module.vpc.private_subnets
    }
  }

  tags = local.tags
}

module "eks_blueprints_kubernetes_addons" {
  source = "../../modules/kubernetes-addons"

  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  enable_karpenter = true

  depends_on = [module.eks_blueprints.self_managed_node_groups]
}

# Creates Launch templates for Karpenter
# Launch template outputs will be used in Karpenter Provisioners yaml files. Checkout this examples/karpenter/provisioners/default_provisioner_with_launch_templates.yaml
module "karpenter_launch_templates" {
  source = "../../modules/launch-templates"

  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  launch_template_config = {
    linux = {
      ami                    = data.aws_ami.eks.id
      launch_template_prefix = "karpenter"
      iam_instance_profile   = module.eks_blueprints.self_managed_node_group_iam_instance_profile_id[0]
      vpc_security_group_ids = [module.eks_blueprints.worker_node_security_group_id]
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = "200"
        }
      ]
    }

    bottlerocket = {
      ami                    = data.aws_ami.bottlerocket.id
      launch_template_os     = "bottlerocket"
      launch_template_prefix = "bottle"
      iam_instance_profile   = module.eks_blueprints.self_managed_node_group_iam_instance_profile_id[0]
      vpc_security_group_ids = [module.eks_blueprints.worker_node_security_group_id]
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = "200"
        }
      ]
    }
  }

  tags = merge(local.tags, { Name = "karpenter" })
}

# Deploying default provisioner for Karpenter autoscaler
data "kubectl_path_documents" "karpenter_provisioners" {
  pattern = "${path.module}/provisioners/default_provisioner.yaml"
  vars = {
    azs                     = join(",", local.azs)
    iam-instance-profile-id = module.eks_blueprints.self_managed_node_group_iam_instance_profile_id[0]
    eks-cluster-id          = module.eks_blueprints.eks_cluster_id
  }
}

# You can also deploy multiple provisioner files with the below code snippet
# data "kubectl_path_documents" "karpenter_provisioners" {
#   pattern = "${path.module}/provisioners/*.yaml"
# }

resource "kubectl_manifest" "karpenter_provisioner" {
  for_each  = toset(data.kubectl_path_documents.karpenter_provisioners.documents)
  yaml_body = each.value

  depends_on = [module.eks_blueprints_kubernetes_addons]
}

#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = "1"
  }

  tags = local.tags
}

data "aws_ami" "eks" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-*"]
  }
  owners = ["amazon"]
}

data "aws_ami" "bottlerocket" {
  most_recent = true
  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-${local.cluster_version}-x86_64-*"]
  }
  owners = ["amazon"]
}
