# EKS Workload Accelerator for Terraform

The EKS workload accelerator is a collection of reference implementations for Amazon EKS designed to accelerate the time it takes to launch a workload ready cluster. It includes an opinionated set of pre-configured and integrated tools/add-ons, and best practices to support core capabilities including Autoscaling, Observability, Networking and Security.

The motivation behind this project is to accelerate and simplify the process of setting up a cluster that is ready to support applications and workloads. We’ve heard from customers that there can be a learning curve associated with deploying your first application ready EKS cluster. This project aims to simplify the undifferentiated lifting, and allow you to focus on deploying and testing your applications.

If you have any questions about how to use this reference implementation, you can contact us at eks-accelerator@amazon.com. If you have suggestions for features that you’d like to see in this reference architecture, please open a GitHub issue.

NOTE: Whilst these reference architectures deploy a fully configured Amazon EKS clusters, we do not suggest they are used directly in Production. They are intended to be used as a starting point from which you can generate your own production ready configuration.

## Single Amazon EKS Cluster per environment on a single AWS Account
The first reference implementation created as part of this project supports a single Amazon EKS cluster per environment, in a single Account. To get started, please see [this](./single-account-single-cluster-multi-env/README.md) guide for an architecture diagram and description of the capabilities & add-ons that will be provisioned, alongside instructions for how to deploy. The different sub-folders have additional README files that explain the relevant design decisions that have been made in further detail.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

