# Jenkins EC2 Terraform

Jenkins 서버를 AWS EC2에 자동으로 생성하는 Terraform 코드입니다.

## 사전 준비

1. **Terraform 설치**
   - Windows: `choco install terraform`
   - 또는 [공식 다운로드](https://developer.hashicorp.com/terraform/downloads)

2. **AWS CLI 설정**
   ```bash
   aws configure --profile hong
   ```

3. **EC2 Key Pair 생성**
   - AWS Console → EC2 → Key Pairs → Create key pair
   - `.pem` 파일 안전하게 보관

## 사용법

### 1. 변수 설정

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 파일을 열고 본인 환경에 맞게 수정:

```hcl
aws_profile = "hong"           # 본인의 AWS 프로필
key_name    = "my-jenkins-key" # 본인의 Key Pair 이름
```

### 2. 인프라 생성

```bash
# 초기화
terraform init

# 실행 계획 확인
terraform plan

# 인프라 생성
terraform apply
```

### 3. Jenkins 접속

```bash
# 출력된 jenkins_url로 브라우저 접속
# 예: http://3.35.xxx.xxx:8080

# SSH 접속 후 초기 비밀번호 확인
ssh -i my-jenkins-key.pem ec2-user@<public_ip>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 4. 리소스 삭제

```bash
terraform destroy
```

## 생성되는 리소스

- EC2 인스턴스 (t3.small)
- 보안 그룹 (SSH:22, Jenkins:8080)
- (선택) Elastic IP

## 비용

- EC2 t3.small: 약 $15/월
- Elastic IP (미사용 시): 약 $3.6/월

> 💡 학습 완료 후 반드시 `terraform destroy`로 리소스를 삭제하세요!
