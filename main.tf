# main.tf - Jenkins deployment on Minikube

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Configure Kubernetes provider for Minikube
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

# Create namespace for Jenkins
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

# Create persistent volume for Jenkins data
resource "kubernetes_persistent_volume" "jenkins_pv" {
  metadata {
    name = "jenkins-pv"
  }
  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/data/jenkins-volume"
      }
    }
  }
}

# Create persistent volume claim
resource "kubernetes_persistent_volume_claim" "jenkins_pvc" {
  metadata {
    name      = "jenkins-pvc"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
    storage_class_name = "standard"
  }
  depends_on = [kubernetes_persistent_volume.jenkins_pv]
}

# Create ServiceAccount for Jenkins
resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }
}

# Create ClusterRole for Jenkins
resource "kubernetes_cluster_role" "jenkins" {
  metadata {
    name = "jenkins"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "services", "namespaces"]
    verbs      = ["get", "list", "create", "delete", "patch", "update"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "create", "delete", "patch", "update"]
  }
}

# Bind ClusterRole to ServiceAccount
resource "kubernetes_cluster_role_binding" "jenkins" {
  metadata {
    name = "jenkins"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.jenkins.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins.metadata[0].name
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }
}

# Create Jenkins deployment
resource "kubernetes_deployment" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
    labels = {
      app = "jenkins"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "jenkins"
      }
    }

    template {
      metadata {
        labels = {
          app = "jenkins"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.jenkins.metadata[0].name
        
        container {
          image = "jenkins/jenkins:lts"
          name  = "jenkins"

          port {
            container_port = 8080
            name          = "http"
          }

          port {
            container_port = 50000
            name          = "jnlp"
          }

          volume_mount {
            name       = "jenkins-home"
            mount_path = "/var/jenkins_home"
          }

          env {
            name  = "JAVA_OPTS"
            value = "-Djenkins.install.runSetupWizard=false -Dhudson.model.DownloadService.noSignatureCheck=true -Djava.awt.headless=true -Dcom.sun.net.ssl.checkRevocation=false -Dtrust_all_cert=true -Dhudson.security.csrf.GlobalCrumbIssuerConfiguration.DISABLE_CSRF_PROTECTION=true"
          }

          env {
            name  = "JENKINS_OPTS"
            value = "--httpPort=8080"
          }

          env {
            name  = "CURL_CA_BUNDLE"
            value = ""
          }

          env {
            name  = "JENKINS_UC_INSECURE"
            value = "true"
          }

          resources {
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }
        }

        volume {
          name = "jenkins-home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.jenkins_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# Create Jenkins service
resource "kubernetes_service" "jenkins" {
  metadata {
    name      = "jenkins-service"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  spec {
    selector = {
      app = "jenkins"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      node_port   = 30080
    }

    port {
      name        = "jnlp"
      port        = 50000
      target_port = 50000
      node_port   = 30050
    }

    type = "NodePort"
  }
}

# Output the Jenkins URL
output "jenkins_url" {
  value = "Access Jenkins at http://$(minikube ip):30080"
}

output "jenkins_namespace" {
  value = kubernetes_namespace.jenkins.metadata[0].name
}