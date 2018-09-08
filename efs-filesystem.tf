/* efs filesystem comment in branch develop*/
resource "aws_efs_file_system" efs {
#resource "aws_efs_file_system" "${var.name}" {
  creation_token = "my-efs"
  encrypted = "true"

  tags {
    Name = "efs"
    Purpose = "Container data mount"
  }
}


# next EFS SG with aid of https://cwong47.gitlab.io/technology-terraform-aws-efs/

resource "aws_security_group" "efs" {
  name        = "${var.name}-efs-c${var.cluster_num}"
  description = "Allow NFS traffic."
  vpc_id      = "${aws_vpc.robmetrics.id}"

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port   = "2049"
    to_port     = "2049"
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    security_groups = ["${aws_security_group.robmetrics-node.id}"]
    #cidr_blocks = ["${var.allowed_cidr_blocks}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.name}-c${var.cluster_num}"
    Environment = "${var.environment}"
    Cluster     = "${var.cluster_num}"
    Terraform   = "true"
  }
}


# next two stanza's come from https://www.terraform.io/docs/providers/aws/d/subnet_ids.html
/* The following example retrieves a list of all subnets in a VPC with a custom tag of Name = "eks-robmetrics-node"
so that the aws_efs_mount_target resource can loop through the subnets, putting mount targets across availability zones.
*/

data "aws_subnet_ids" "eks-robmetrics-node" {
  vpc_id      = "${aws_vpc.robmetrics.id}"
  tags {
    Name = "eks-robmetrics-node"
  }
}

resource "aws_efs_mount_target" "efs" {
  count         = "3"
  file_system_id = "${aws_efs_file_system.efs.id}"
  subnet_id     = "${element(data.aws_subnet_ids.eks-robmetrics-node.ids, count.index)}"
  security_groups = ["${aws_security_group.efs.id}"] # from https://cwong47.gitlab.io/technology-terraform-aws-efs/
}
