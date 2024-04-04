# Single Cluster / Single Environment / Single Account


## Design considerations 

This reference implementation is designed to deploy a single Amazon EKS cluster per environment in a single account. It designed for customers that require a simple ready-to-use cluster, configured with set of opinionated (yet configurable to some extent) tooling deployed alongside the cluster itself. The ideal customers profile includes:
* Customers who are early on their containerization/Kubernetes journey, and are looking for a simplified deployment to run their applications
* Limited resources to manage the cluster and its configurations
* Application/s that can be deployed in a single cluster
* A business unit within the organization that needs to deploy a multi-environment cluster for its specific workloads

## Architecture Diagram 

![architecture diagram](https://lucid.app/publicSegments/view/cca79846-a08c-4f72-84e3-df524efc409f/image.png)

## Capabilities deployed in this reference implementation

This pattern deploy the following resources per environment in a single account:

* Terraform remote state and locking mechanism for collaboration - this deploys  Amazon S3 and Amazon DynamoDB requires to manage Terraform remote state backend configuration.
See [`tf-base`](./00.tf-base/main.tf) configurations
  
* Network configuration - the base Amazon VPC configuration needed for the Amazon EKS cluster. As an example, this includes provisioning Amazon VPC Endpoints to [reduce cost and increase security](https://aws.amazon.com/blogs/architecture/reduce-cost-and-increase-security-with-amazon-vpc-endpoints/).
See networking [README](./10.networking/README.md) for detailed configuration

* Access Management capabilities - provisioning set of default [user-facing roles](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) that are used to access the Amazon EKS  cluster 
See "IAM Roles for EKS" [README](./20.iam-roles-for-eks/README.md) for detailed configuration
* Amazon EKS Cluster - configured with set of defaults (described in the EKS Cluster README) alongside with a baseline set of Amazon EKS add-ons that are needed for a minimal functionality (including Karpenter for node provisioning). 
See EKS Cluster [README](./40.eks/40.cluster/README.md) for detailed configuration

* EKS Blueprints addons - The intent of this folder is to provision the relevant addons, based on enabled capabilities configured for this reference implementation.
See EKS Cluster [README](./40.eks/45.addons/README.md) for detailed configuration

* Observability capabilities - based on the observability configuration, this part deploys the relevant AWS Services and addons into your cluster with a ready-to-use base to observe applications deployed to the cluster. Currently it supports the following configurations:
  * AWS OSS observability services stack (see AWS OSS [README](./50.observability/55.aws-oss-observability/README.md) folder for detailed configuration) which includes:
    * Amazon Managed Service for Prometheus - a serverless, Prometheus-compatible monitoring service for container metrics.
    * Amazon Managed Grafana - a data visualization for your operational metrics, logs, and traces
    * AWS Managed scraper for AMP that scrape metrics from your Amazon EKS cluster directly to an AMP workspace
  

## Configurable variables

This pattern use a global configurable variable per environment to allow you to customize some of the environment specific objects for the different environments. The variables are documented on a configuration file under the `00.global/var/base-env.tfvars` file. 

Instead of configuring flags for provisioning resources, this pattern uses use-case driven flags that result in a complete configuration for a collection of deployments, services, and configuration. For example, setting `observability_configuration.aws_oss_tooling = true` will result in provisioning the relevant AWS resources (such as AMP and AMG) as well the configurations that connects them together. 

## Deploying the pattern

This pattern rely on multiple Terraform configuration which resides in multiple folders (such as: networking, iam-roles-for-eks, eks, addons, and observability).    
Each folder that holds a Terraform configuration, also has a `backend.tf` terraform configuration file used to indicate the backend S3 prefix key.

Before deploying the whole cluster configuration, this pattern use Amazon S3 and Amazon DynamoDB to store the Terraform state of all resources across environments, and provide a locking mechanism.   
The deployment of the S3 Bucket and the DynamoDB table is configured under the folder [`00.tf-base`](./00.tf-base).

Default S3 bucket name: `tfstate-<AWS_ACCOUNT_ID>`  
Default DynamoDB table name: `tfstate-lock`

Several environment variables must be used before running any target
- `AWS_REGION` - Specify the AWS region to run on
- `AWS_PROFILE` - The aws configuration profile to be used.

### Makefile
We are using a [`Makefile`](./Makefile) that is designed to automate varius tasks related to managing the Terraform infrastructure.  
It provides several targets (or commands) to handle different aspects of the Terraform workflow.

**Targets**:
   - `bootstrap`: Initializes and applies the Terraform configuration in the `00.tf-base` directory, which is assumed to be responsible for setting up the backend (S3 bucket and DynamoDB table) for state management.
   - `init-all`: Initializes all Terraform modules by calling the `init` target for each module.
   - `plan-all`: Runs the `plan` target for all Terraform modules.
   - `apply-all`: Runs the `apply` target for all Terraform modules.
   - `plan`: Runs the `terraform plan` command for a specific module.
   - `apply`: Runs the `terraform apply` command for a specific module.
   - `destroy`: Runs the `terraform destroy` command for a specific module.

The `<TARGET>-all` Makefile target is iterating over all of the folders that holds any terraform configuration with a `backend.tf` terraform configuration file and deploy all of them one by one by specifying a target environment for the deployment.

**Variables**:
   - `ENVIRONMENT`: Specifies the environment (e.g., dev, prod) for which the Terraform configuration will be applied. It defaults to `dev` if not set.
   - `MODULE`: Specifies a specific MODULE to to run.

### Step 1 - deploy the Terraform resources for state management (once for all environments)
```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=default
make bootstrap
```

### Step 2 - configure environments for deployment

In this step you should define the environments you want to deploy to (can be dev, staging, prod, etc...), as well as the overall configuration variables for every environment.

To define the environments you want to deplo ensure that under the folder [`00.global/vars/`](00.global/vars) you have files for every environment with the exact name of the environments defined equivalent to the `ENVIRONMENT` we will use with our Makefile.   
As a starting point, this reference implementation includes a general baseline file names [`base-env.tfvars`](./00.global/vars/base-env.tfvars) as well as files for `dev` and `prod` environments.

### Step 3 - Deploy environment
In this step you will deploy the environment based on the configuration you defined per environment in previous step.  
You can then trigger an `apply-all` Makefile target and it'll provision an environment based on the configuration per environment.

```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=default
make ENVIRONMENT=dev apply-all
```

#### Deploy a specific module
To deploy a specific module, specify a MODULE variable before the the Makefile target.

```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=default
make ENVIRONMENT=dev MODULE=10.networking apply 
```

### Step 4 - Cleanup - destroy
Be caution when using destroy to cleanup resources.
By default, the destroy `-auto-approve` is disabled, to enable it, use the `AUTO_APPROVE=true` variable.

```
export AWS_REGION=us-east-1
export AWS_PROFILE=default
make ENVIRONMENT=dev MODULE=10.networking destroy AUTO_APPROVE=true 
```

#### Destroy ALL
This will run Terraform destroy on all modules by reverse order.

```
export AWS_REGION=us-east-1
export AWS_PROFILE=default
make ENVIRONMENT=dev destroy-all AUTO_APPROVE=true 
```

## Architecture Decisions  

### Global variable file per environment

#### Context

This pattern can deploy the same configuration to multiple environments. There's a need to customize environment specific configurations to support gradual updates, or per-environment specific configuration. 

#### Decision

This pattern standardize on a shared Terraform variable file per environment which is used in the CLI (see Makefile as it wraps the CLI commands) to use this file throughout multiple folder configurations.

#### Consequences

This decision help us share the variables across the different folders, and standardize on variable naming and values

### Storing Environment specific state using Terraform Workspaces

https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform#multi-environment-deployment
#### Context

To keep the IaC code DRY, the state of the different resources needs to be kept in the context of an environment, so other configurations in different folders will be able to access the outputs of the right environment.

#### Decision

This pattern uses Terraform Workspaces to store and retrieve environment specific state from the S3 Backend being used as the remote state backend. Per Hashicorp recommendations on ["Multi-Environment Deployment"](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform#multi-environment-deployment), it's encouraged to use Terraform workspaces to manage multiple environments: "Where possible, it's recommended to use a single backend configuration for all environments and use the terraform workspace command to switch between workspaces"

#### Consequences

The uses of Terraform workspaces allows us to use the same IaC code and backend configuration, without changing it per environment. As this project Makefile wraps the relevant workspaces commands, if users choose to rewrite their own CLI automation, they'll need to handle workspace switching before applying per-environment configuration.