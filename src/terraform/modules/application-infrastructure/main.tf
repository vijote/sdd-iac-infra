terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Providers will be configured by the calling module

# Create namespace for infrastructure components
resource "kubernetes_namespace" "application_infrastructure" {
  metadata {
    name = var.namespace
    labels = {
      name       = var.namespace
      managed-by = "terraform"
      project    = "sdd-infra"
      component  = "application-infrastructure"
    }
  }
}

# Note: For kubeadm clusters, the EBS CSI driver uses EC2 instance profile
# No IAM role needed here - the nodes use their instance profile for EBS access

# Create storage classes
resource "kubernetes_storage_class" "storage_classes" {
  for_each = merge(
    {
      gp3 = {
        type                = "gp3"
        iops                = 3000
        throughput          = 125
        encrypted           = true
        reclaim_policy      = "Retain"
        allow_expansion     = true
        volume_binding_mode = "WaitForFirstConsumer"
        is_default_class    = true
      }
      io2 = {
        type                = "io2"
        iops                = 10000
        encrypted           = true
        reclaim_policy      = "Retain"
        allow_expansion     = true
        volume_binding_mode = "WaitForFirstConsumer"
        is_default_class    = false
      }
      io1 = {
        type                = "io1"
        iops                = 5000
        encrypted           = true
        reclaim_policy      = "Retain"
        allow_expansion     = true
        volume_binding_mode = "WaitForFirstConsumer"
        is_default_class    = false
      }
      sc1 = {
        type                = "sc1"
        encrypted           = true
        reclaim_policy      = "Delete"
        allow_expansion     = false
        volume_binding_mode = "WaitForFirstConsumer"
        is_default_class    = false
      }
      st1 = {
        type                = "st1"
        encrypted           = true
        reclaim_policy      = "Delete"
        allow_expansion     = false
        volume_binding_mode = "WaitForFirstConsumer"
        is_default_class    = false
      }
    },
    var.storage_classes
  )

  metadata {
    name = each.key
    labels = merge(
      {
        "app.kubernetes.io/name"      = "aws-ebs-csi-driver"
        "app.kubernetes.io/component" = "storageclass"
      },
      each.value.is_default_class ? {
        "storageclass.kubernetes.io/is-default-class" = "true"
      } : {}
    )

    annotations = merge(
      {
        "description" = "${each.value.type} storage class"
      },
      each.value.is_default_class ? {
        "storageclass.kubernetes.io/is-default-class" = "true"
      } : {}
    )
  }

  storage_provisioner = "ebs.csi.aws.com"

  parameters = merge(
    {
      type      = each.value.type
      encrypted = tostring(each.value.encrypted)
      fsType    = "ext4"
    },
    contains(["gp3", "io2", "io1"], each.value.type) && each.value.iops != null ? {
      iops = tostring(each.value.iops)
    } : {},
    each.value.type == "gp3" && each.value.throughput != null ? {
      throughput = tostring(each.value.throughput)
    } : {}
  )

  allow_volume_expansion = each.value.allow_expansion
  reclaim_policy         = each.value.reclaim_policy
  volume_binding_mode    = each.value.volume_binding_mode

  depends_on = [
    helm_release.ebs_csi_driver
  ]
}

# EBS CSI Driver Helm chart
resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.20.0"

  # Desactivar bloqueo estricto y limpiar si falla
  wait             = false
  cleanup_on_fail  = true

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  # For kubeadm, EBS CSI driver uses EC2 instance profile
  # No IAM role annotation needed

  depends_on = [
    kubernetes_namespace.application_infrastructure
  ]
}

# cert-manager Helm chart
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = var.namespace
  version    = "v1.13.2"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "prometheus.enabled"
    value = var.enable_monitoring
  }

  depends_on = [
    kubernetes_namespace.application_infrastructure,
    helm_release.ebs_csi_driver
  ]
}

# Let's Encrypt ClusterIssuer
resource "kubernetes_manifest" "letsencrypt_prod_issuer" {
  count = var.cert_manager_email != null ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
      labels = {
        "app.kubernetes.io/name"      = "cert-manager"
        "app.kubernetes.io/component" = "cluster-issuer"
        "environment"                 = "production"
      }
      annotations = {
        "description" = "Let's Encrypt production certificate issuer"
      }
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.cert_manager_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
                podTemplate = {
                  spec = {
                    nodeSelector = {
                      "kubernetes.io/os" = "linux"
                    }
                    tolerations = [
                      {
                        key      = "node-role.kubernetes.io/master"
                        operator = "Exists"
                        effect   = "NoSchedule"
                      },
                      {
                        key      = "node-role.kubernetes.io/control-plane"
                        operator = "Exists"
                        effect   = "NoSchedule"
                      }
                    ]
                  }
                }
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [
    helm_release.cert_manager
  ]
}

# Let's Encrypt Staging ClusterIssuer
resource "kubernetes_manifest" "letsencrypt_staging_issuer" {
  count = var.cert_manager_email != null ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
      labels = {
        "app.kubernetes.io/name"      = "cert-manager"
        "app.kubernetes.io/component" = "cluster-issuer"
        "environment"                 = "staging"
      }
      annotations = {
        "description" = "Let's Encrypt staging certificate issuer for testing"
      }
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = var.cert_manager_email
        privateKeySecretRef = {
          name = "letsencrypt-staging-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
                podTemplate = {
                  spec = {
                    nodeSelector = {
                      "kubernetes.io/os" = "linux"
                    }
                    tolerations = [
                      {
                        key      = "node-role.kubernetes.io/master"
                        operator = "Exists"
                        effect   = "NoSchedule"
                      },
                      {
                        key      = "node-role.kubernetes.io/control-plane"
                        operator = "Exists"
                        effect   = "NoSchedule"
                      }
                    ]
                  }
                }
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [
    helm_release.cert_manager
  ]
}

# NGINX Ingress Controller Helm chart
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = var.namespace
  version    = "4.8.3"

  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx"
  }

  set {
    name  = "controller.ingressClassResource.controllerValue"
    value = "k8s.io/ingress-nginx"
  }

  set {
    name  = "controller.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "controller.metrics.enabled"
    value = var.enable_monitoring
  }

  set {
    name  = "controller.replicaCount"
    value = var.resource_limits.controller_replicas
  }

  dynamic "set" {
    for_each = var.ingress_annotations
    content {
      name  = "controller.service.annotations.${replace(set.key, ".", "\\.")}"
      value = set.value
    }
  }

  depends_on = [
    kubernetes_namespace.application_infrastructure,
    helm_release.cert_manager
  ]
}