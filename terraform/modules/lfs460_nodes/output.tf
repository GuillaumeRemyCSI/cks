output "public_ips" {
  value = { for name, node in aws_instance.node : name => node.public_ip }
}

output "student_password" {
  value     = random_string.student.result
  sensitive = true
}
