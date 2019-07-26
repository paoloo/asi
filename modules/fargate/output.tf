output "alb_hostname" {
  value = "${aws_alb.main.dns_name}"
}

output "alb_arn" {
  value = "${aws_alb.main.arn}"
}

output "cluster_name" {
  value = "${aws_ecs_cluster.main.name}"
}

output "service_name" {
  value = "${aws_ecs_service.main.name}"
}

output "task_secgrp_id" {
  value = ["${aws_security_group.ecs_tasks.id}"]
}
