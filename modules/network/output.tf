output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

output "subnet_pub" {
  value = ["${aws_subnet.public.*.id}"]
}

output "subnet_prv" {
  value = ["${aws_subnet.private.*.id}"]
}

