#
# Outputs
#

locals {
  config-map-aws-auth = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.robmetrics-node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH

  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.robmetrics.endpoint}
    certificate-authority-data: ${aws_eks_cluster.robmetrics.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: heptio-authenticator-aws
      args:
        - "token"
        - "-i"
        - "${var.cluster-name}"
KUBECONFIG
}

output "config-map-aws-auth" {
  value = "${local.config-map-aws-auth}"
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}


# from  https://cwong47.gitlab.io/technology-terraform-aws-efs/ :


output "name" {
  value = "${var.name}"
}

output "file_system_id" {
  value = "${aws_efs_file_system.efs.id}"
}

output "dns_name" {
  value = "${aws_efs_file_system.efs.dns_name}"
}

output "mount_target_ids" {
  value = "${join(",", aws_efs_mount_target.efs.*.id)}"
}

output "mount_target_interface_ids" {
  value = "${join(",", aws_efs_mount_target.efs.*.network_interface_id)}"
}

output "security_group_id" {
  value = "${aws_security_group.efs.id}"
}

