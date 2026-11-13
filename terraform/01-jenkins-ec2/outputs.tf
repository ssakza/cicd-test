output "instance_id" {
  description = "EC2 인스턴스 ID"
  value       = aws_instance.jenkins.id
}

output "public_ip" {
  description = "Jenkins 서버 공인 IP"
  value       = var.use_elastic_ip ? aws_eip.jenkins[0].public_ip : aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins 웹 UI 주소"
  value       = "http://${var.use_elastic_ip ? aws_eip.jenkins[0].public_ip : aws_instance.jenkins.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH 접속 명령어"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${var.use_elastic_ip ? aws_eip.jenkins[0].public_ip : aws_instance.jenkins.public_ip}"
}

output "initial_password_command" {
  description = "Jenkins 초기 비밀번호 확인 명령어"
  value       = "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}
