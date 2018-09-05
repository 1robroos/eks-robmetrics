#
# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table
#

resource "aws_vpc" "robmetrics" {
  cidr_block = "10.1.0.0/16"

  tags = "${
    map(
     "Name", "eks-robmetrics-node",
     "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"
}

resource "aws_subnet" "robmetrics" {
  count = 3

  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "10.1.${count.index}.0/24"
  vpc_id            = "${aws_vpc.robmetrics.id}"

  tags = "${
    map(
     "Name", "eks-robmetrics-node",
     "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"
}

resource "aws_internet_gateway" "robmetrics" {
  vpc_id = "${aws_vpc.robmetrics.id}"

  tags {
    Name = "eks-robmetrics"
  }
}

resource "aws_route_table" "robmetrics" {
  vpc_id = "${aws_vpc.robmetrics.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.robmetrics.id}"
  }
}

resource "aws_route_table_association" "robmetrics" {
  count = 3

  subnet_id      = "${aws_subnet.robmetrics.*.id[count.index]}"
  route_table_id = "${aws_route_table.robmetrics.id}"
}
