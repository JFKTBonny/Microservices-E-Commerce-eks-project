

# Create EKS cluster:
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  eks_managed_node_groups = {
    default = {
      desired_size = 2
      min_size     = 2
      max_size     = 4

      instance_types = ["t3.medium"]
    }
  }

  enable_irsa = true
}

# Configure kubectl access:
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}

# Apply k8s manifests:
resource "null_resource" "apply_deployment" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "kubectl apply -k ${var.filepath_manifest} -n ${var.namespace}"
  }

  depends_on = [
    module.eks
  ]
}

# Wait for pods to be ready:
resource "null_resource" "wait_conditions" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = <<-EOT
      kubectl wait --for=condition=Available deployment --all -n ${var.namespace} --timeout=300s
      kubectl wait --for=condition=Ready pods --all -n ${var.namespace} --timeout=300s
    EOT
  }

  depends_on = [
    null_resource.apply_deployment
  ]
}

# Get kubeconfig:
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = <<EOT
aws eks update-kubeconfig \
  --region ${var.region} \
  --name ${module.eks.cluster_name}
EOT
  }

  depends_on = [module.eks]
}
