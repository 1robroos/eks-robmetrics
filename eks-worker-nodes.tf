#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EC2 Security Group to allow networking traffic
#  * Data source to fetch latest EKS worker AMI
#  * AutoScaling Launch Configuration to configure worker instances
#  * AutoScaling Group to launch worker instances
#

resource "aws_iam_role" "robmetrics-node" {
  name = "eks-robmetrics-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "robmetrics-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.robmetrics-node.name}"
}

resource "aws_iam_role_policy_attachment" "robmetrics-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.robmetrics-node.name}"
}

resource "aws_iam_role_policy_attachment" "robmetrics-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.robmetrics-node.name}"
}

resource "aws_iam_instance_profile" "robmetrics-node" {
  name = "eks-robmetrics"
  role = "${aws_iam_role.robmetrics-node.name}"
}

resource "aws_security_group" "robmetrics-node" {
  name        = "eks-robmetrics-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${aws_vpc.robmetrics.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "eks-robmetrics-node",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
  }"
}

resource "aws_security_group_rule" "robmetrics-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.robmetrics-node.id}"
  source_security_group_id = "${aws_security_group.robmetrics-node.id}"
  to_port                  = 65535
  type                     = "ingress"
}

#resource "aws_security_group_rule" "robmetrics-node-vpcdefault" {
#  description              = "Add VPC default SG to eks worker for usage with EFS"
#  from_port                = 0
#  protocol                 = "-1"
#  security_group_id        = "${aws_security_group.robmetrics-node.id}"
#  source_security_group_id = "sg-02b3803f7cf4217e1"
#  to_port                  = 65535
#  type                     = "ingress"
#}
resource "aws_security_group_rule" "robmetrics-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.robmetrics-node.id}"
  source_security_group_id = "${aws_security_group.robmetrics-cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "robmetrics-node-ingress-londoncontrolserver" {
  description = "Allow London Control Server to ssh into the worker node"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["${local.workstation-external-cidr}"]
  security_group_id = "${aws_security_group.robmetrics-node.id}"
  type = "ingress"
  }

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["eks-worker-*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon
}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-nodegroup.yaml
locals {
  robmetrics-node-userdata = <<USERDATA
#!/bin/bash -xe

CA_CERTIFICATE_DIRECTORY=/etc/kubernetes/pki
CA_CERTIFICATE_FILE_PATH=$CA_CERTIFICATE_DIRECTORY/ca.crt
mkdir -p $CA_CERTIFICATE_DIRECTORY
echo "${aws_eks_cluster.robmetrics.certificate_authority.0.data}" | base64 -d >  $CA_CERTIFICATE_FILE_PATH
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.robmetrics.endpoint},g /var/lib/kubelet/kubeconfig
sed -i s,CLUSTER_NAME,${var.cluster-name},g /var/lib/kubelet/kubeconfig
sed -i s,REGION,${data.aws_region.current.name},g /etc/systemd/system/kubelet.service
sed -i s,MAX_PODS,20,g /etc/systemd/system/kubelet.service
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.robmetrics.endpoint},g /etc/systemd/system/kubelet.service
sed -i s,INTERNAL_IP,$INTERNAL_IP,g /etc/systemd/system/kubelet.service
DNS_CLUSTER_IP=10.100.0.10
if [[ $INTERNAL_IP == 10.* ]] ; then DNS_CLUSTER_IP=172.20.0.10; fi
sed -i s,DNS_CLUSTER_IP,$DNS_CLUSTER_IP,g /etc/systemd/system/kubelet.service
sed -i s,CERTIFICATE_AUTHORITY_FILE,$CA_CERTIFICATE_FILE_PATH,g /var/lib/kubelet/kubeconfig
sed -i s,CLIENT_CA_FILE,$CA_CERTIFICATE_FILE_PATH,g  /etc/systemd/system/kubelet.service
systemctl daemon-reload
systemctl restart kubelet
yum install -y amazon-efs-utils
mkdir /data
chmod 777 /data
# EFS resource variables must be three parts: TYPE.NAME.ATTR
# TYPE = aws_efs_file_system
# NAME = efs  ( the name you gave to the EFS filesystem  )
# ATTR = id ( aws_efs_file_system outputs 2 attributes: id and dns name )
# So we still need the name of the EFS for mounting it.
mount -t efs ${aws_efs_file_system.efs.id}:/  /data 
USERDATA
}

resource "aws_launch_configuration" "robmetrics" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.robmetrics-node.name}"
  image_id                    = "${data.aws_ami.eks-worker.id}"
  instance_type               = "t2.medium"
  key_name = "oregonkeypair"
  #associate_public_ip_address = "true"
  name_prefix                 = "eks-robmetrics"
  security_groups             = ["${aws_security_group.robmetrics-node.id}"]
# sg-02b3803f7cf4217e1 is default SG for if you dont define a SG for the EFS filesystem
# We dont want to use the default SG
  #security_groups             = ["${aws_security_group.robmetrics-node.id}","sg-02b3803f7cf4217e1"]
  user_data_base64            = "${base64encode(local.robmetrics-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "robmetrics" {
  desired_capacity     = 1
  launch_configuration = "${aws_launch_configuration.robmetrics.id}"
  max_size             = 5
  min_size             = 1
  name                 = "eks-robmetrics"
  vpc_zone_identifier  = ["${aws_subnet.robmetrics.*.id}"]

  tag {
    key                 = "Name"
    value               = "eks-robmetrics"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
