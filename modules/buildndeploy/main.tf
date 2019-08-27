/* ========================================================================= */
/* ================= STORAGE =============================================== */
/* ========================================================================= */

/* ================================================================ Artifact */

resource "aws_s3_bucket" "main" {
  bucket = "${var.ecs_cluster_name}-${var.environment}"
  acl    = "private"
  tags = {
    Name        = "${var.ecs_cluster_name}-${var.environment}"
    Environment = var.environment
  }
}

/* ========================================================================= */
/* ================= BUILD ================================================= */
/* ========================================================================= */

/* =============================================================== CodeBuild */

resource "aws_codebuild_project" "docker_build" {
  name          = "${var.repository_name}-${var.environment}-build"
  build_timeout = "10"
  service_role  = aws_iam_role.buildndeploy-role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/docker:17.09.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = templatefile("${path.module}/appspec.yml",{ app_environment     = var.environment,
                                                            repository_uri      = var.registry_uri,
                                                            region              = var.region,
                                                            cluster_name        = var.ecs_cluster_name,
                                                            subnet_id           = join(",", var.task_subnet_id),
                                                            security_group_ids  = join(",", var.task_secgrp_id) })
  }
}

/* ========================================================================= */
/* ================= DEPLOY ================================================ */
/* ========================================================================= */

/* ============================================================ CodePipeline */

resource "aws_codepipeline" "pipeline" {
  name     = "${var.repository_name}-${var.environment}-pipeline"
  role_arn = aws_iam_role.buildndeploy-role.arn
  artifact_store {
    location = aws_s3_bucket.main.bucket
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source"]
      configuration = {
        Owner      = var.repository_owner
        Repo       = var.repository_name
        Branch     = var.repository_branch
        OAuthToken = var.github_token
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["imagedefinitions"]
      configuration = {
        ProjectName = "${var.repository_name}-${var.environment}-build"
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["imagedefinitions"]
      version         = "1"
      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

/* ========================================================================= */
/* ================= SECURITY ============================================== */
/* ========================================================================= */

/* =============================================================== IAM Roles */

resource "aws_iam_role" "buildndeploy-role" {
  name               = "${var.repository_name}-${var.environment}-buildndeploy-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ecs.amazonaws.com",
          "codepipeline.amazonaws.com",
          "codebuild.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "buildndeploy-policy" {
  name   = "${var.repository_name}-${var.environment}-buildndeploy-policy"
  role   = aws_iam_role.buildndeploy-role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets",
        "codebuild:*",
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "ecr:*",
        "ecs:RegisterTaskDefinition",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeServices",
        "ecs:CreateService",
        "ecs:ListServices",
        "ecs:UpdateService",
        "logs:PutLogEvents",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "iam:GetRole",
        "iam:PassRole"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF

}

