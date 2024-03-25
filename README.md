# EKS Workload Accelerator for Terraform

The EKS workload accelerator is a collection of reference implementation for Amazon EKS designed to accelerate the time it takes to launch a workload ready cluster. It includes an opinionated set of tools/add-ons and best practices to support Autoscaling, Observability, Networking and Security.

This is a WIP, and more reference implementations will be added.

> **_NOTE:_**  Even though these reference architectures deploy a fully configured environments based on Amazon EKS Clusters, they should treated as a starting point for building your own production ready configuration.

## Single Amazon EKS Cluster per environment on a single AWS Account
Currently there's one reference implementation for customers that manages a single Amazon EKS cluster per environment, in a single Account. To get started, please refer to this specific [README](./single-account-single-cluster-multi-env/README.md)


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

