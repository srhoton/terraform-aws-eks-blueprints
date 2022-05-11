# Node Groups

The framework uses dedicated sub modules for creating [AWS Managed Node Groups](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/main/modules/aws-eks-managed-node-groups), [Self-managed Node groups](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/main/modules/aws-eks-self-managed-node-groups) and [Fargate profiles](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/main/modules/aws-eks-fargate-profiles). These modules provide flexibility to add or remove managed/self-managed node groups/fargate profiles by simply adding/removing map of values to input config. See [example](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/main/examples/eks-cluster-with-new-vpc).

The `aws-auth` ConfigMap handled by this module allow your nodes to join your cluster, and you also use this ConfigMap to add RBAC access to IAM users and roles.
Each Node Group can have dedicated IAM role, Launch template and Security Group to improve the security.

## Additional IAM Roles, Users and Accounts
Access to EKS cluster using AWS IAM entities is enabled by the [AWS IAM Authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html) for Kubernetes, which runs on the Amazon EKS control plane.
The authenticator gets its configuration information from the `aws-auth` [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/).

The following config grants additional AWS IAM users or roles the ability to interact with your cluster. However, the best practice is to leverage [soft-multitenancy](https://aws.github.io/aws-eks-best-practices/security/docs/multitenancy/) with the help of [Teams](https://github.com/aws-ia/terraform-aws-eks-blueprints/blob/main/docs/teams.md) module. Teams feature helps to manage users with dedicated namespaces, RBAC, IAM roles and register users with `aws-auth` to provide access to the EKS Cluster.

The below example demonstrates adding additional IAM Roles, IAM Users and Accounts using EKS Blueprints module

```hcl
module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints"

  # EKS CLUSTER
  cluster_version    = "1.21"                                         # EKS Cluster Version
  vpc_id             = "<vpcid>"                                      # Enter VPC ID
  private_subnet_ids = ["<subnet-a>", "<subnet-b>", "<subnet-c>"]     # Enter Private Subnet IDs

  # List of map_roles
  map_roles          = [
    {
      rolearn  = "arn:aws:iam::<aws-account-id>:role/<role-name>"     # The ARN of the IAM role
      username = "ops-role"                                           # The user name within Kubernetes to map to the IAM role
      groups   = ["system:masters"]                                   # A list of groups within Kubernetes to which the role is mapped; Checkout K8s Role and Rolebindings
    }
  ]

  # List of map_users
  map_users = [
    {
      userarn  = "arn:aws:iam::<aws-account-id>:user/<username>"      # The ARN of the IAM user to add.
      username = "opsuser"                                            # The user name within Kubernetes to map to the IAM role
      groups   = ["system:masters"]                                   # A list of groups within Kubernetes to which the role is mapped; Checkout K8s Role and Rolebindings
    }
  ]

  map_accounts = ["123456789", "9876543321"]                          # List of AWS account ids
}
```

## Managed Node Groups

The below example demonstrates the minimum configuration required to deploy a managed node group.

```hcl
    # EKS MANAGED NODE GROUPS
    managed_node_groups = {
      mg_4 = {
        node_group_name = "managed-ondemand"
        instance_types  = ["m5.large"]
        subnet_ids      = []  # Mandatory Public or Private Subnet IDs
        disk_size       = 100 # disk_size will be ignored when using Launch Templates
      }
    }
```

The below example demonstrates advanced configuration options for a managed node group with launch templates.

```hcl
    managed_node_groups = {
      # Managed Node groups with Launch templates using AMI TYPE
      mng_lt = {
        # Node Group configuration
        node_group_name        = "mng-lt"
        create_launch_template = true              # false will use the default launch template
        launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or windows or bottlerocket
        public_ip              = false             # Use this to enable public IP for EC2 instances; only for public subnets used in launch templates ;
        enable_monitoring      = true
        pre_userdata           = <<-EOT
                    yum install -y amazon-ssm-agent
                    systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
                EOT
        # Node Group scaling configuration
        desired_size    = 3
        max_size        = 3
        min_size        = 3
        max_unavailable = 1 # or percentage = 20

        # Node Group compute configuration
        ami_type        = "AL2_x86_64" # Amazon Linux 2(AL2_x86_64), AL2_x86_64_GPU, AL2_ARM_64, BOTTLEROCKET_x86_64, BOTTLEROCKET_ARM_64
        release_version = ""           # Enter AMI release version to deploy the latest AMI released by AWS. Used only when you specify ami_type
        capacity_type   = "ON_DEMAND"  # ON_DEMAND or SPOT
        instance_types  = ["m5.large"] # List of instances used only for SPOT type

        block_device_mappings = [
          {
            device_name = "/dev/xvda"
            volume_type = "gp3"
            volume_size = 100
          },
          {
            device_name           = "/dev/xvdf" # mount point to /local1 (it could be local2, depending upon the disks are attached during boot)
            volume_type           = "gp3" # The volume type. Can be standard, gp2, gp3, io1, io2, sc1 or st1 (Default: gp3).
            volume_size           = "100"
            delete_on_termination = true
            encrypted             = true
            kms_key_id            = "" # Custom KMS Key can be used to encrypt the disk
            iops                  = 3000
            throughput            = 125
          }
        ]

        # Node Group network configuration
        subnet_ids = [] # Mandatory - # Define private/public subnets list with comma separated ["subnet1","subnet2","subnet3"]

        additional_iam_policies = [] # Attach additional IAM policies to the IAM role attached to this worker group
        # SSH ACCESS Optional - Recommended to use SSM Session manager
        remote_access         = false
        ec2_ssh_key           = ""
        ssh_security_group_id = ""

        # Taints can be applied through EKS API or through Bootstrap script using kubelet_extra_args
        # e.g., k8s_taints = [{key= "spot", value="true", "effect"="NO_SCHEDULE"}]
        k8s_taints = [{key= "purpose", value="execution", effect="NO_SCHEDULE"}]

        # Node Labels can be applied through EKS API or through Bootstrap script using kubelet_extra_args
        k8s_labels = {
          Environment = "preprod"
          Zone        = "dev"
          WorkerType  = "ON_DEMAND"
        }
        additional_tags = {
          ExtraTag    = "m4-on-demand"
          Name        = "m4-on-demand"
          subnet_type = "private"
        }
      }
    }
```

The below example demonstrates advanced configuration options using Spot/GPU instances/ARM instances/Bottlerocket and custom AMIs managed node groups.

```hcl
    #---------------------------------------------------------#
    # SPOT Worker Group
    #---------------------------------------------------------#
    spot_m5 = {
      # 1> Node Group configuration
      node_group_name        = "spot-m5"
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks  or bottlerocket
      public_ip              = false             # Use this to enable public IP for EC2 instances; only for public subnets used in launch templates ;
      pre_userdata           = <<-EOT
                 yum install -y amazon-ssm-agent
                 systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
             EOT
      # Node Group scaling configuration
      desired_size = 2
      max_size     = 2
      min_size     = 2

      # Node Group update configuration. Set the maximum number or percentage of unavailable nodes to be tolerated during the node group version update.
      max_unavailable = 1 # or percentage = 20

      # Node Group compute configuration
      ami_type       = "AL2_x86_64"
      capacity_type  = "SPOT"
      instance_types = ["t3.large", "t3.xlarge"]

      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 100
        }
      ]

      # Node Group network configuration
      subnet_ids = [] # Defaults to private subnet-ids used by EKS Control plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      k8s_taints = []

      k8s_labels = {
        Environment = "preprod"
        Zone        = "dev"
        WorkerType  = "SPOT"
      }
      additional_tags = {
        ExtraTag    = "spot_nodes"
        Name        = "spot"
        subnet_type = "private"
      }
    }

    #---------------------------------------------------------#
    # GPU instance type Worker Group
    #---------------------------------------------------------#
    gpu = {
      # 1> Node Group configuration - Part1
      node_group_name        = "gpu-mg5"         # Max 40 characters for node group name
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket
      public_ip              = false             # Use this to enable public IP for EC2 instances; only for public subnets used in launch templates ;
      pre_userdata           = <<-EOT
            yum install -y amazon-ssm-agent
            systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
        EOT
      # 2> Node Group scaling configuration
      desired_size    = 2
      max_size        = 2
      min_size        = 2
      max_unavailable = 1 # or percentage = 20

      # 3> Node Group compute configuration
      ami_type       = "AL2_x86_64_GPU" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM
      capacity_type  = "ON_DEMAND"      # ON_DEMAND or SPOT
      instance_types = ["m5.large"]     # List of instances used only for SPOT type
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
           volume_type = "gp3"
           volume_size = 100
        }
      ]

      # 4> Node Group network configuration
      subnet_ids = [] # Defaults to private subnet-ids used by EKS Controle plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      k8s_taints = []

      k8s_labels = {
        Environment = "preprod"
        Zone        = "dev"
        WorkerType  = "ON_DEMAND"
      }
      additional_tags = {
        ExtraTag    = "m5x-on-demand"
        Name        = "m5x-on-demand"
        subnet_type = "private"
      }
    }

    #---------------------------------------------------------#
    # ARM instance type Worker Group
    #---------------------------------------------------------#
    arm = {
      # 1> Node Group configuration - Part1
      node_group_name        = "arm-mg5"         # Max 40 characters for node group name
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket
      public_ip              = false             # Use this to enable public IP for EC2 instances; only for public subnets used in launch templates ;
      pre_userdata           = <<-EOT
            yum install -y amazon-ssm-agent
            systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
        EOT
      # 2> Node Group scaling configuration
      desired_size    = 2
      max_size        = 2
      min_size        = 2
      max_unavailable = 1 # or percentage = 20

      # 3> Node Group compute configuration
      ami_type       = "AL2_ARM_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM, BOTTLEROCKET_ARM_64, BOTTLEROCKET_x86_64
      capacity_type  = "ON_DEMAND"  # ON_DEMAND or SPOT
      instance_types = ["m5.large"] # List of instances used only for SPOT type
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 100
        }
      ]
      # 4> Node Group network configuration
      subnet_ids = [] # Defaults to private subnet-ids used by EKS Controle plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      k8s_taints = []

      k8s_labels = {
        Environment = "preprod"
        Zone        = "dev"
        WorkerType  = "ON_DEMAND"
      }
      additional_tags = {
        ExtraTag    = "m5x-on-demand"
        Name        = "m5x-on-demand"
        subnet_type = "private"
      }
    }

    #---------------------------------------------------------#
    # Bottlerocket ARM instance type Worker Group
    #---------------------------------------------------------#
    # Checkout this doc https://github.com/bottlerocket-os/bottlerocket for configuring userdata for Launch Templates
    bottlerocket_arm = {
      # 1> Node Group configuration
      node_group_name        = "btl-arm"      # Max 40 characters for node group name
      create_launch_template = true           # false will use the default launch template
      launch_template_os     = "bottlerocket" # amazonlinux2eks or bottlerocket
      public_ip              = false          # Use this to enable public IP for EC2 instances; only for public subnets used in launch templates ;
      # 2> Node Group scaling configuration
      desired_size    = 2
      max_size        = 2
      min_size        = 2
      max_unavailable = 1 # or percentage = 20

      # 3> Node Group compute configuration
      ami_type       = "BOTTLEROCKET_ARM_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM, BOTTLEROCKET_ARM_64, BOTTLEROCKET_x86_64
      capacity_type  = "ON_DEMAND"           # ON_DEMAND or SPOT
      instance_types = ["m5.large"]          # List of instances used only for SPOT type
      disk_size      = 50

      # 4> Node Group network configuration
      subnet_ids = [] # Defaults to private subnet-ids used by EKS Controle plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      k8s_taints = []

      k8s_labels = {
        Environment = "preprod"
        Zone        = "dev"
        WorkerType  = "ON_DEMAND"
      }
      additional_tags = {
        ExtraTag    = "m5x-on-demand"
        Name        = "m5x-on-demand"
        subnet_type = "private"
      }
    }

    #---------------------------------------------------------#
    # Bottlerocket instance type Worker Group
    #---------------------------------------------------------#
    # Checkout this doc https://github.com/bottlerocket-os/bottlerocket for configuring userdata for Launch Templates
    bottlerocket_arm = {
      # 1> Node Group configuration - Part1
      node_group_name        = "btl-x86"      # Max 40 characters for node group name
      create_launch_template = true           # false will use the default launch template
      launch_template_os     = "bottlerocket" # amazonlinux2eks or bottlerocket
      public_ip              = false          # Use this to enable public IP for EC2 instances; only for public subnets used in launch templates ;
      # 2> Node Group scaling configuration
      desired_size    = 2
      max_size        = 2
      min_size        = 2
      max_unavailable = 1 # or percentage = 20

      # 3> Node Group compute configuration
      ami_type       = "BOTTLEROCKET_x86_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM, BOTTLEROCKET_ARM_64, BOTTLEROCKET_x86_64
      capacity_type  = "ON_DEMAND"           # ON_DEMAND or SPOT
      instance_types = ["m5.large"]          # List of instances used only for SPOT type
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 100
        }
      ]

      # 4> Node Group network configuration
      subnet_ids = [] # Defaults to private subnet-ids used by EKS Controle plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      k8s_taints = []

      k8s_labels = {
        Environment = "preprod"
        Zone        = "dev"
        WorkerType  = "ON_DEMAND"
      }
      additional_tags = {
        ExtraTag    = "m5x-on-demand"
        Name        = "m5x-on-demand"
        subnet_type = "private"
      }
    }

    #---------------------------------------------------------#
    # Managed Node groups with Launch templates using CUSTOM AMI with ContainerD runtime
    #---------------------------------------------------------#
    mng_custom_ami = {
      # Node Group configuration
      node_group_name = "mng_custom_ami" # Max 40 characters for node group name

      # custom_ami_id is optional when you provide ami_type. Enter the Custom AMI id if you want to use your own custom AMI
      custom_ami_id  = data.aws_ami.amazonlinux2eks.id
      capacity_type  = "ON_DEMAND"  # ON_DEMAND or SPOT
      instance_types = ["m5.large"] # List of instances used only for SPOT type

      # Launch template configuration
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

      # pre_userdata will be applied by using custom_ami_id or ami_type
      pre_userdata = <<-EOT
            yum install -y amazon-ssm-agent
            systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
        EOT

      # post_userdata will be applied only by using custom_ami_id
      post_userdata = <<-EOT
            echo "Bootstrap successfully completed! You can further apply config or install to run after bootstrap if needed"
      EOT

      # kubelet_extra_args used only when you pass custom_ami_id;
      # --node-labels is used to apply Kubernetes Labels to Nodes
      # --register-with-taints used to apply taints to Nodes
      # e.g., kubelet_extra_args='--node-labels=WorkerType=SPOT,noderole=spark --register-with-taints=spot=true:NoSchedule --max-pods=58',
      kubelet_extra_args = "--node-labels=WorkerType=SPOT,noderole=spark --register-with-taints=test=true:NoSchedule --max-pods=20"

      # bootstrap_extra_args used only when you pass custom_ami_id. Allows you to change the Container Runtime for Nodes
      # e.g., bootstrap_extra_args="--use-max-pods false --container-runtime containerd"
      bootstrap_extra_args = "--use-max-pods false --container-runtime containerd"

      # Taints can be applied through EKS API or through Bootstrap script using kubelet_extra_args
      k8s_taints = []

      # Node Labels can be applied through EKS API or through Bootstrap script using kubelet_extra_args
      k8s_labels = {
        Environment = "preprod"
        Zone        = "dev"
        Runtime     = "containerd"
      }

      enable_monitoring = true
      eni_delete        = true
      public_ip         = false # Use this to enable public IP for EC2 instances; only for public subnets used in launch templates

      # Node Group scaling configuration
      desired_size    = 2
      max_size        = 2
      min_size        = 2
      max_unavailable = 1 # or percentage = 20

      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 150
        }
      ]

      # Node Group network configuration
      subnet_type = "private" # public or private - Default uses the private subnets used in control plane if you don't pass the "subnet_ids"
      subnet_ids  = []        # Defaults to private subnet-ids used by EKS Control plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      additional_iam_policies = [] # Attach additional IAM policies to the IAM role attached to this worker group

      # SSH ACCESS Optional - Recommended to use SSM Session manager
      remote_access         = false
      ec2_ssh_key           = ""
      ssh_security_group_id = ""

      additional_tags = {
        ExtraTag    = "mng-custom-ami"
        Name        = "mng-custom-ami"
        subnet_type = "private"
      }
    }
```

## Self-managed Node Groups

The below example demonstrates the minimum configuration required to deploy a Self-managed node group.

```hcl
    # EKS SELF MANAGED NODE GROUPS
    self_managed_node_groups = {
        self_mg_4 = {
          node_group_name    = "self-managed-ondemand"
          launch_template_os = "amazonlinux2eks"
          subnet_ids         = module.vpc.private_subnets
        }
    }
```

The below example demonstrates advanced configuration options for a self-managed node group.

```hcl
    self_managed_node_groups = {
      self_mg_4 = {
        node_group_name      = "self-managed-ondemand"
        instance_type        = "m5.large"
        custom_ami_id        = "ami-0dfaa019a300f219c" # Bring your own custom AMI generated by Packer/ImageBuilder/Puppet etc.
        capacity_type        = ""                      # Optional Use this only for SPOT capacity as capacity_type = "spot"
        launch_template_os   = "amazonlinux2eks"       # amazonlinux2eks  or bottlerocket or windows
        pre_userdata         = <<-EOT
            yum install -y amazon-ssm-agent
            systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
        EOT
        post_userdata        = ""
        kubelet_extra_args   = ""
        bootstrap_extra_args = ""
        block_device_mapping = [
          {
            device_name = "/dev/xvda" # mount point to /
            volume_type = "gp3"
            volume_size = 20
          },
          {
            device_name = "/dev/xvdf" # mount point to /local1 (it could be local2, depending upon the disks are attached during boot)
            volume_type = "gp3"
            volume_size = 50
            iops        = 3000
            throughput  = 125
          },
          {
            device_name = "/dev/xvdg" # mount point to /local2 (it could be local1, depending upon the disks are attached during boot)
            volume_type = "gp3"
            volume_size = 100
            iops        = 3000
            throughput  = 125
          }
        ]
        enable_monitoring = false
        public_ip         = false # Enable only for public subnets

        # AUTOSCALING
        max_size   = 3
        min_size   = 1
        subnet_ids = [] # Mandatory Public or Private Subnet IDs
        additional_tags = {
          ExtraTag    = "m5x-on-demand"
          Name        = "m5x-on-demand"
          subnet_type = "private"
        }
        additional_iam_policies = []
      },
    }
```

With the previous described example at `block_device_mapping`, in case you choose an instance that has local NVMe storage, you will achieve the three specified EBS disks plus all local NVMe disks that instance brings.

For example, for an `m5d.large` you will end up with the following mount points: `/` for device named `/dev/xvda`, `/local1` for device named `/dev/xvdf`, `/local2` for device named `/dev/xvdg`, and `/local3` for instance storage (in such case a disk with 70GB).

Check the following references as you may desire:

- [Amazon EBS and NVMe on Linux instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/nvme-ebs-volumes.html).
- [AWS NVMe drivers for Windows instances](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/aws-nvme-drivers.html)
- [EC2 Instance Update – M5 Instances with Local NVMe Storage (M5d)](https://aws.amazon.com/blogs/aws/ec2-instance-update-m5-instances-with-local-nvme-storage-m5d/)

### Fargate Profile

The example below demonstrates how you can customize a Fargate profile for your cluster.

```hcl
  fargate_profiles = {
    default = {
      fargate_profile_name = "default"
      fargate_profile_namespaces = [{
        namespace = "default"
        k8s_labels = {
          Environment = "preprod"
          Zone        = "dev"
          env         = "fargate"
        }
      }]

      subnet_ids = [] # Provide list of private subnets

      additional_tags = {
        ExtraTag = "Fargate"
      }
    },
    multi = {
      fargate_profile_name = "multi-namespaces"
      fargate_profile_namespaces = [{
        namespace = "default"
        k8s_labels = {
          Environment = "preprod"
          Zone        = "dev"
          OS          = "Fargate"
          WorkerType  = "FARGATE"
          Namespace   = "default"
        }
        },
        {
          namespace = "sales"
          k8s_labels = {
            Environment = "preprod"
            Zone        = "dev"
            OS          = "Fargate"
            WorkerType  = "FARGATE"
            Namespace   = "default"
          }
      }]

      subnet_ids = [] # Provide list of private subnets

      additional_tags = {
        ExtraTag = "Fargate"
      }
    },
  }
```

### Windows Self-Managed Node Groups

The example below demonstrates the minimum configuration required to deploy a Self-managed node group of Windows nodes. Refer to the [AWS EKS user guide](https://docs.aws.amazon.com/eks/latest/userguide/windows-support.html) for more information about Windows support in EKS.

```hcl
  # SELF-MANAGED NODE GROUP with Windows support
  enable_windows_support = true

  self_managed_node_groups = {
    ng_od_windows = {
      node_group_name    = "ng-od-windows"
      launch_template_os = "windows"
      instance_type      = "m5n.large"
      subnet_ids         = module.vpc.private_subnets
      min_size           = 2
    }
  }
```

In clusters where Windows support is enabled, workloads should have explicit node assignments configured using `nodeSelector` or `affinity`, as described in the Kubernetes document [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/).
For example, if you are enabling the `metrics-server` Kubernetes add-on (Helm chart), use the following configuration to ensure its pods are assigned to Linux nodes. See the [EKS Cluster with Windows Support example](../examples/node-groups/windows-node-groups/) for full Terraform configuration and workload deployment samples.

```hcl
  enable_metrics_server = true
  metrics_server_helm_config = {
    set = [
      {
        name  = "nodeSelector.kubernetes\\.io/os"
        value = "linux"
      }
    ]
  }
```
