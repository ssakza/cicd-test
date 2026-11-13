variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"  # 서울 리전
}

variable "aws_profile" {
  description = "AWS CLI 프로필명"
  type        = string
  default     = "default"  # 본인의 프로필명으로 변경
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.small"  # 최소 2GB RAM 필요
}

variable "key_name" {
  description = "EC2 Key Pair 이름 (미리 생성 필요)"
  type        = string
  # default 값 없음 - 반드시 지정해야 함
}

variable "use_elastic_ip" {
  description = "Elastic IP 사용 여부 (고정 IP)"
  type        = bool
  default     = false  # 학습용이므로 기본 비활성화
}
