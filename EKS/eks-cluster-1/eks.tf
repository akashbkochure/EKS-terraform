# Adding Provider details
provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

# Creating IAM role so that it can be assumed while connecting to the Kubernetes cluster.
resource "aws_iam_role" "iam-role-eks-cluster" {
  name = "terraform-eks-cluster"

  assume_role_policy = <<POLICY
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Principal": {
       "Service": "eks.amazonaws.com"
     },
     "Action": "sts:AssumeRole"
   }
  ]
}
POLICY
}

# Attach the AWS EKS service and AWS EKS cluster policies to the role.
resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.iam-role-eks-cluster.name
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.iam-role-eks-cluster.name
}

# Create security group for AWS EKS.
resource "aws_security_group" "eks-cluster" {
  name   = "SG-eks-cluster"
  vpc_id = "vpc-01f1079fb7214867a" 

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating the AWS EKS cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "terraformEKScluster"
  role_arn = aws_iam_role.iam-role-eks-cluster.arn
  version  = "1.23" # Update the version to the desired EKS version

  vpc_config {
    security_group_ids = [aws_security_group.eks-cluster.id]
    subnet_ids         = ["subnet-0cf7c3215b8dc1022", "subnet-016736ddf2fa95d0a"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSServicePolicy,
  ]
}

# Creating IAM role for AWS EKS nodes with assume policy so that it can assume
resource "aws_iam_role" "eks_nodes" {
  name = "eks-node-group"

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

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# Create AWS EKS cluster node group
resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "node_tuto"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = ["subnet-0cf7c3215b8dc1022", "subnet-016736ddf2fa95d0a"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}
