# IPv6 EKS Cluster

This example deploys VPC, Subnets and EKS Cluster with IPv6 networking enabled

- Creates a new sample VPC with IPv6, 3 Private Subnets and 3 Public Subnets
- Creates Internet gateway for Public Subnets and NAT Gateway for Private Subnets
- Creates EKS Cluster Control plane with one managed node group

Checkout EKS the documentation for more details about [IPv6](https://docs.aws.amazon.com/eks/latest/userguide/cni-ipv6.html)

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
cd examples/ipv6-eks-cluster/
terraform init
```

#### Step 3: Run Terraform PLAN

Verify the resources created by this execution

```shell script
export AWS_REGION=<ENTER YOUR REGION>   # Select your own region
terraform plan
```

#### Step 4: Finally, Terraform APPLY

to create resources

```shell script
terraform apply
```

Enter `yes` to apply

#### Step 5: Verify EC2 instances running with IPv6 support

```shell script
aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=ipv6-preprod-dev-eks" --query "Reservations[].Instances[? State.Name == 'running' ][].NetworkInterfaces[].Ipv6Addresses" --output table
```

### Configure `kubectl` and test cluster

EKS Cluster details can be extracted from terraform output or from AWS Console to get the name of cluster.
This following command used to update the `kubeconfig` in your local machine where you run kubectl commands to interact with your EKS Cluster.

#### Step 6: Run `update-kubeconfig` command

`~/.kube/config` file gets updated with cluster details and certificate from the below command

```shell script
aws eks --region <enter-your-region> update-kubeconfig --name <cluster-name>
```

#### Step 7: List all the PODS running in `kube-system` and observe the **IP allocated**

```shell script
kubectl get pods -n kube-system  -o wide
```

Output

        NAME                                           READY   STATUS    RESTARTS   AGE    IP                                      NODE                                        NOMINATED NODE   READINESS GATES
        aws-load-balancer-controller-bd6cb6fcc-4r8hw   1/1     Running   0          10m    2a05:d018:434:7702:2e8a::               ip-10-0-10-23.eu-west-1.compute.internal    <none>           <none>
        aws-load-balancer-controller-bd6cb6fcc-z7m8p   1/1     Running   0          10m    2a05:d018:434:7703:6b5d::1              ip-10-0-11-186.eu-west-1.compute.internal   <none>           <none>
        aws-node-f7s6m                                 1/1     Running   0          140m   2a05:d018:434:7702:3784:d6b:fc0d:e156   ip-10-0-10-23.eu-west-1.compute.internal    <none>           <none>
        aws-node-lg5rb                                 1/1     Running   0          142m   2a05:d018:434:7703:b3eb:2aa:aa4a:c838   ip-10-0-11-186.eu-west-1.compute.internal   <none>           <none>
        coredns-57b66fb77c-hk5ks                       1/1     Running   0          144m   2a05:d018:434:7702:2e8a::1              ip-10-0-10-23.eu-west-1.compute.internal    <none>           <none>
        coredns-57b66fb77c-j69fq                       1/1     Running   0          144m   2a05:d018:434:7703:6b5d::               ip-10-0-11-186.eu-west-1.compute.internal   <none>           <none>
        kube-proxy-k992g                               1/1     Running   0          3h1m   2a05:d018:434:7702:3784:d6b:fc0d:e156   ip-10-0-10-23.eu-west-1.compute.internal    <none>           <none>
        kube-proxy-nzfrq                               1/1     Running   0          3h1m   2a05:d018:434:7703:b3eb:2aa:aa4a:c838   ip-10-0-11-186.eu-west-1.compute.internal   <none>           <none>

## How to Destroy

The following command destroys the resources created by `terraform apply`

```shell script
cd examples/eks-cluster-with-new-vpc
terraform destroy --auto-approve
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
| <a name="module_aws_vpc"></a> [aws\_vpc](#module\_aws\_vpc) | terraform-aws-modules/vpc/aws | ~> 3.0 |
| <a name="module_eks_blueprints"></a> [eks\_blueprints](#module\_eks\_blueprints) | ../.. | n/a |
| <a name="module_eks_blueprints_kubernetes_addons"></a> [eks\_blueprints\_kubernetes\_addons](#module\_eks\_blueprints\_kubernetes\_addons) | ../../modules/kubernetes-addons | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_configure_kubectl"></a> [configure\_kubectl](#output\_configure\_kubectl) | Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
