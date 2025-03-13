# GPU Inference Capability Supporting Components
# This capability enables GPU-based inference workloads on the EKS cluster
#
# ARCHITECTURE:
# This module provides the supporting components for GPU-based machine learning workloads:
# 1. The NVIDIA device plugin - enables container access to GPU resources 
# 2. DCGM Exporter - provides GPU metrics for monitoring
# 3. A dedicated 'inference' namespace for AI/ML applications
#
# INTEGRATION WITH 30.EKS:
# The actual GPU NodePool is defined in the 30.eks/30.cluster/karpenter/gpu.yaml file
# and is automatically deployed when autoscaling capability is enabled in your cluster
# configuration. This ensures the infrastructure is properly provisioned before
# deploying these supporting components.
#
# To enable both GPU infrastructure and these supporting components:
# 1. Make sure your cluster_config includes:
#    - capabilities.autoscaling = true  (for Karpenter and GPU node pool)
#    - capabilities.inference = true    (for these supporting components)
#
# NOTE: The components deployed here can either run on:
# - GPU nodes, by configuring proper nodeSelectors (like the DCGM exporter)
# - System/critical nodes, by configuring tolerations for the CriticalAddonsOnly taint
#   (useful for the NVIDIA device plugin which needs to be available at all times)

# Check if inference capability is enabled
locals {
  inference_enabled = try(var.cluster_config.inference, true)
}

# Deploy the NVIDIA device plugin to support GPU instances
resource "helm_release" "nvidia_device_plugin" {
  count      = local.inference_enabled && !local.eks_auto_mode ? 1 : 0
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"
  version    = "0.14.5"
  
  # Add tolerations so the device plugin can run on critical nodes if needed
  values = [
    <<-EOT
    tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Exists"
      - key: "nvidia.com/gpu"
        value: "present"
        effect: "NoSchedule"
    nodeSelector:
      karpenter.k8s.aws/instance-category: g
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["g5", "g6"]
    EOT
  ]
}

# Deploy DCGM exporter for GPU metrics
resource "helm_release" "dcgm_exporter" {
  count      = local.inference_enabled && !local.eks_auto_mode ? 1 : 0
  name       = "dcgm-exporter"
  repository = "https://nvidia.github.io/dcgm-exporter/helm-charts"
  chart      = "dcgm-exporter"
  namespace  = "monitoring"
  version    = "3.2.0"
  create_namespace = true
  
  values = [
    <<-EOT
    tolerations:
      - key: "nvidia.com/gpu"
        value: "present"
        effect: "NoSchedule"
    nodeSelector:
      karpenter.k8s.aws/instance-category: g
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["g5", "g6"]
    serviceMonitor:
      enabled: false
    EOT
  ]
}

# Create a namespace for inference applications
resource "kubernetes_namespace" "inference" {
  count = local.inference_enabled ? 1 : 0
  
  metadata {
    name = "inference"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "role" = "inference"
    }
  }
} 