# EKS Cluster Deployment with new VPC and EFS

This example deploys the following Basic EKS Cluster with VPC

- Creates a new sample VPC, 3 Private Subnets and 3 Public Subnets
- Creates Internet gateway for Public Subnets and NAT Gateway for Private Subnets
- Creates EKS Cluster Control plane with one managed node group and fargate profile
- Creates EFS file system for backing the dynamic provisioning of persistent volumes

## How to Deploy

### Prerequisites:

Ensure that you have installed the following tools in your Mac or Windows Laptop before start working with this module and run Terraform Plan and Apply

1. [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [Kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### Deployment Steps

#### Step 1: Clone the repo using the command below

```shell script
git clone https://github.com/aws-ia/terraform-aws-eks-blueprints.git
```

#### Step 2: Run Terraform INIT

Initialize a working directory with configuration files

```shell script
cd examples/aws-efs-csi-driver/
terraform init
```

#### Step 3: Run Terraform PLAN

Verify the resources created by this execution

```shell script
export AWS_REGION=<ENTER YOUR REGION>   # Select your own region
terraform plan
```

#### Step 4: Finally, Terraform APPLY

To create resources

```shell script
terraform apply
```

Enter `yes` to apply

### Configure `kubectl` and test cluster

EKS Cluster details can be extracted from terraform output or from AWS Console to get the name of cluster.
This following command used to update the `kubeconfig` in your local machine where you run kubectl commands to interact with your EKS Cluster.

#### Step 5: Run `update-kubeconfig` command

`~/.kube/config` file gets updated with cluster details and certificate from the below command

    aws eks --region ${AWS_REGION} update-kubeconfig --name aws001-preprod-dev-eks

#### Step 6: List all the worker nodes by running the command below

    kubectl get nodes

#### Step 7: List all the pods running in `kube-system` namespace

    kubectl get pods -n kube-system

#### Step 8: Create a storage class to leverage the EFS file system

Retrieve your Amazon EFS file system ID

    terraform output -raw efs_file_system_id

Download a `StorageClass` manifest for Amazon EFS

    curl -o storageclass.yaml https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/examples/kubernetes/dynamic_provisioning/specs/storageclass.yaml

Edit the file and replace the value for `fileSystemId` with your file system ID

    fileSystemId: fs-xxxxxxxxxxxxxxxxx

Deploy the storage class

    kubectl apply -f storageclass.yaml

#### Step 9: Test automatic provisioning

Download a manifest that deploys a `Pod` and a `PersistentVolumeClaim`

    curl -o pod.yaml https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/examples/kubernetes/dynamic_provisioning/specs/pod.yaml

Deploy the `Pod`

    kubectl apply -f pod.yaml

Confirm that a persistent volume was created with a status of `Bound` to a `PersistentVolumeClaim`

    kubectl get pv

Wait until the sample app `Pod`'s `STATUS` becomes `Running`

    kubectl wait --for=condition=ready pod efs-app

Confirm that the data is written to the volume

    kubectl exec efs-app -- bash -c "cat data/out"
    Wed Feb 23 13:37:24 UTC 2022
    Wed Feb 23 13:37:29 UTC 2022
    Wed Feb 23 13:37:34 UTC 2022
    Wed Feb 23 13:37:39 UTC 2022
    Wed Feb 23 13:37:44 UTC 2022
    Wed Feb 23 13:37:49 UTC 2022

## How to Destroy

The following command destroys the resources created by `terraform apply`

```shell script
cd examples/aws-efs-csi-driver/
terraform destroy -auto-approve
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.72 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.4.1 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.10 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.72 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks_blueprints"></a> [eks\_blueprints](#module\_eks\_blueprints) | ../.. | n/a |
| <a name="module_eks_blueprints_kubernetes_addons"></a> [eks\_blueprints\_kubernetes\_addons](#module\_eks\_blueprints\_kubernetes\_addons) | ../../modules/kubernetes-addons | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_efs_file_system.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.efs_mt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_security_group.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_configure_kubectl"></a> [configure\_kubectl](#output\_configure\_kubectl) | Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig |
| <a name="output_efs_file_system_id"></a> [efs\_file\_system\_id](#output\_efs\_file\_system\_id) | ID of the EFS file system to use for creating a storage class |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
