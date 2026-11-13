# Jenkins EC2 설치 및 기본 설정

## 🤔 Jenkins란?

### Jenkins 정의

**Jenkins**는 소프트웨어 개발의 빌드, 테스트, 배포를 자동화하는 **오픈소스 자동화 서버**입니다.

```
+------------------+
|     Jenkins      |
|   자동화 서버     |
+------------------+
        |
        | 자동으로 실행
        v
+-------+-------+-------+-------+
| 빌드  | 테스트 | 분석  | 배포  |
+-------+-------+-------+-------+
```

### 왜 Jenkins를 사용하는가?

| 문제 상황 | Jenkins 도입 후 |
|----------|-----------------|
| "빌드 좀 해주세요" 요청 대기 | 코드 푸시하면 자동 빌드 |
| 테스트 실행 잊어버림 | 매 빌드마다 자동 테스트 |
| 누가 배포할지 담당자 부재 | 승인 후 자동 배포 |
| 밤에 배포해야 해서 야근 | 스케줄 배포 설정 |

### 이 실습의 목적

**EC2에 Jenkins를 설치**하면:
- 나만의 CI/CD 서버를 갖게 됩니다
- 모든 자동화 작업의 중심 허브가 됩니다
- 이후 실습(GitHub 연동, Docker 빌드, ECS 배포)의 기반이 됩니다

### 실습 후 기대 효과

```
[실습 전]
개발자 --수동--> 빌드서버 접속 --수동--> 빌드 실행 --수동--> 결과 확인

[실습 후]  
개발자 --자동--> Jenkins가 알아서 빌드 --자동--> 결과 알림
```

---

## 📋 개요

| 항목 | 내용 |
|------|------|
| 목적 | AWS EC2에 Jenkins를 설치하고 CI/CD 파이프라인의 기반 환경 구성 |
| 예상 소요 시간 | 1~2시간 |
| 난이도 | ★☆☆☆☆ (초급) |
| 예상 비용 | 월 $15 내외 (t3.small 기준) |

---

## 🎯 학습 목표

- [ ] EC2 인스턴스 생성 및 보안 그룹 설정
- [ ] Jenkins 설치 및 초기 설정
- [ ] Jenkins 플러그인 설치
- [ ] Jenkins 관리자 계정 설정

---

## 🏗️ 아키텍처

```
+---------------------------------------------------+
|                     AWS VPC                        |
|                                                    |
|   +--------------------------------------------+   |
|   |              Public Subnet                 |   |
|   |                                            |   |
|   |   +------------------------------------+   |   |
|   |   |         EC2 (t3.small)             |   |   |
|   |   |                                    |   |   |
|   |   |   +----------------------------+   |   |   |
|   |   |   |         Jenkins            |   |   |   |
|   |   |   |       (Port 8080)          |   |   |   |
|   |   |   +----------------------------+   |   |   |
|   |   |                                    |   |   |
|   |   +------------------------------------+   |   |
|   |                                            |   |
|   +--------------------------------------------+   |
|                                                    |
|                  Security Group                    |
|                 - SSH (22): My IP                  |
|                 - HTTP (8080): My IP               |
|                                                    |
+---------------------------------------------------+
```

---

## 📝 실습 단계

### Step 1: EC2 인스턴스 생성

> 💡 **두 가지 방법 중 선택하세요:**
> - **방법 A**: AWS Console (UI) - 초보자 권장
> - **방법 B**: Terraform (IaC) - 코드로 인프라 관리 학습

---

#### 방법 A: AWS Console로 생성 (UI 방식)

##### A-1. AWS Console 접속
1. AWS Management Console 로그인
2. EC2 서비스로 이동
3. **Launch Instance** 클릭

##### A-2. 인스턴스 설정

| 설정 항목 | 값 | 비고 |
|----------|-----|------|
| Name | jenkins-server | 식별하기 쉬운 이름 |
| AMI | Amazon Linux 2023 | 최신 LTS 버전 권장 |
| Instance Type | t3.small | 최소 2GB RAM 필요 |
| Key Pair | 신규 생성 또는 기존 사용 | .pem 파일 안전하게 보관 |
| Storage | 20GB gp3 | Jenkins 데이터 저장 공간 |

##### A-3. 보안 그룹 설정

| Type | Protocol | Port | Source | 설명 |
|------|----------|------|--------|------|
| SSH | TCP | 22 | My IP | SSH 접속용 |
| Custom TCP | TCP | 8080 | My IP | Jenkins 웹 UI |

> ⚠️ **보안 주의**: 0.0.0.0/0 으로 열지 말고, 반드시 본인 IP만 허용

##### A-4. 인스턴스 시작
- **Launch Instance** 클릭
- 인스턴스 상태가 `running`이 될 때까지 대기 (약 1~2분)

---

#### 방법 B: Terraform으로 생성 (IaC 방식)

##### Terraform이란?

**Terraform**은 인프라를 코드로 관리하는 도구입니다.

```
Console (UI)                    Terraform (IaC)
+------------------+            +------------------+
| 클릭, 클릭, 클릭   |            | 코드 작성         |
| 설정값 입력       |     VS     | terraform apply  |
| 다음, 다음, 생성   |            | 끝!              |
+------------------+            +------------------+
        |                               |
        v                               v
   반복 어려움                      git으로 관리
   변경 추적 불가                   변경 이력 추적
   공유 어려움                      팀과 공유 용이
```

##### B-1. Terraform 코드 준비하기

> 💡 **두 가지 실행 환경 중 선택:**
> - **로컬 PC (PowerShell)**: Terraform 설치 필요
> - **CloudShell**: 설치 없이 바로 사용 가능 (권장)

---

###### 🌐 CloudShell에서 실행하기 (권장)

**Step 1: GitHub 저장소 생성 및 코드 업로드**

먼저 로컬 PC에서 GitHub에 코드를 올립니다:

```powershell
# 1. 로컬 PC (PowerShell)에서 실행
cd "d:\02. Study\aws cicd"

# 2. Git 초기화
git init

# 3. GitHub 저장소 생성 (gh CLI 사용 또는 GitHub 웹에서 생성)
# GitHub 웹: https://github.com/new → 저장소명: cicd-test

# 4. 원격 저장소 연결
git remote add origin https://github.com/<your-username>/cicd-test.git

# 5. 파일 추가 및 푸시
git add .
git commit -m "Initial commit: Jenkins CI/CD study materials"
git branch -M main
git push -u origin main
```

**Step 2: CloudShell에서 코드 가져오기**

```bash
# 1. AWS Console → CloudShell 열기 (우측 상단 >_ 아이콘)

# 2. GitHub에서 코드 클론
git clone https://github.com/<your-username>/cicd-test.git

# 3. Terraform 디렉토리로 이동
cd cicd-test/terraform/01-jenkins-ec2

# 4. Terraform 버전 확인 (CloudShell에 이미 설치됨)
terraform --version
```

**Step 3: 변수 설정 (CloudShell)**

```bash
# terraform.tfvars 파일 생성
cat > terraform.tfvars << 'EOF'
aws_region     = "ap-northeast-2"
aws_profile    = "default"           # CloudShell은 "default" 사용
instance_type  = "t3.small"
key_name       = "my-jenkins-key"    # 본인의 Key Pair 이름으로 변경!
use_elastic_ip = false
EOF

# 파일 확인
cat terraform.tfvars
```

> ⚠️ **중요**: `key_name`은 반드시 본인이 생성한 EC2 Key Pair 이름으로 변경하세요!

**Step 4: Key Pair 생성 (없는 경우)**

```bash
# CloudShell에서 Key Pair 생성
aws ec2 create-key-pair \
    --key-name my-jenkins-key \
    --query 'KeyMaterial' \
    --output text > my-jenkins-key.pem

# 권한 설정
chmod 400 my-jenkins-key.pem

# 생성 확인
aws ec2 describe-key-pairs --key-names my-jenkins-key
```

**Step 5: Terraform 실행 (CloudShell)**

```bash
# 1. 초기화 (Provider 다운로드)
terraform init

# 2. 실행 계획 확인 (어떤 리소스가 생성되는지 미리 보기)
terraform plan

# 3. 인프라 생성 (yes 입력)
terraform apply
```

**예상 출력:**
```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

instance_id = "i-0abc123def456789"
jenkins_url = "http://3.35.xxx.xxx:8080"
public_ip = "3.35.xxx.xxx"
ssh_command = "ssh -i my-jenkins-key.pem ec2-user@3.35.xxx.xxx"
```

**Step 6: Jenkins 접속 확인**

```bash
# SSH 접속 (CloudShell에서)
ssh -i my-jenkins-key.pem ec2-user@<public_ip>

# user_data 설치 완료 대기 (약 3~5분)
# 진행 상황 확인
tail -f /var/log/cloud-init-output.log

# 설치 완료 후 Jenkins 비밀번호 확인
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Step 7: 리소스 삭제 (학습 완료 후)**

```bash
# CloudShell에서
cd ~/cicd-test/terraform/01-jenkins-ec2
terraform destroy
# yes 입력
```

---

###### 💻 로컬 PC (PowerShell)에서 실행하기

**Terraform 설치:**
```powershell
# Chocolatey로 설치 (관리자 권한 PowerShell)
choco install terraform

# 설치 확인
terraform --version
```

**실행:**
```powershell
cd "d:\02. Study\aws cicd\terraform\01-jenkins-ec2"

# 변수 설정
copy terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: aws_profile, key_name 수정

# Terraform 실행
terraform init
terraform plan
terraform apply
```

---

##### B-2. Terraform 파일 구조

```
terraform/01-jenkins-ec2/
├── main.tf                    # 메인 리소스 정의 (EC2, 보안그룹)
├── variables.tf               # 변수 정의
├── outputs.tf                 # 출력값 정의
├── terraform.tfvars.example   # 변수 값 예시
├── README.md                  # 사용 가이드
└── .gitignore                 # Git 제외 파일
```

**각 파일의 역할:**

| 파일 | 역할 |
|------|------|
| `main.tf` | EC2 인스턴스, 보안 그룹, AMI 조회 등 실제 리소스 정의 |
| `variables.tf` | region, instance_type, key_name 등 변수 선언 |
| `outputs.tf` | 생성 후 출력할 값 (IP, URL, SSH 명령어) |
| `terraform.tfvars` | 변수에 실제 값 할당 (본인 환경에 맞게 수정) |

##### B-3. 주요 코드 설명

**자동 기능들:**

```hcl
# 1. 내 IP 자동 조회 → 보안 그룹에 자동 설정
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# 2. 최신 Amazon Linux 2023 AMI 자동 조회
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  # ...
}

# 3. user_data로 Jenkins 자동 설치
user_data = <<-EOF
  dnf install -y java-17-amazon-corretto
  dnf install -y jenkins
  systemctl start jenkins
  # Docker도 미리 설치 (04장에서 사용)
  dnf install -y docker
EOF
```

> 💡 **Tip**: `user_data`로 Jenkins가 자동 설치되므로, EC2 생성 후 3~5분 대기하면 바로 사용 가능합니다.

##### B-4. Terraform 명령어 정리

| 명령어 | 설명 |
|--------|------|
| `terraform init` | 초기화 (Provider 다운로드) |
| `terraform plan` | 실행 계획 미리보기 (변경사항 확인) |
| `terraform apply` | 인프라 생성/변경 |
| `terraform destroy` | 모든 리소스 삭제 |
| `terraform output` | 출력값 다시 확인 |

##### B-5. 비용 및 정리

```bash
# 학습 완료 후 반드시 삭제!
terraform destroy

# 삭제되는 리소스:
# - EC2 인스턴스
# - 보안 그룹  
# - (선택한 경우) Elastic IP
```

> ⚠️ **비용 주의**: `terraform destroy`를 실행하지 않으면 EC2 비용이 계속 발생합니다!

---

### Step 2: EC2 접속 및 Jenkins 설치

> 💡 **Terraform으로 생성한 경우**: user_data로 Jenkins가 자동 설치됩니다. 3~5분 후 바로 **Step 3: Jenkins 초기 설정**으로 이동하세요.
> 
> 아래 내용은 **Console(UI)로 생성한 경우**에만 필요합니다.

#### 2-1. SSH 접속

```bash
# Windows (PowerShell)
ssh -i "your-key.pem" ec2-user@<EC2-Public-IP>

# 권한 오류 시 (Linux/Mac)
chmod 400 your-key.pem
```

#### 2-2. 시스템 업데이트

```bash
sudo dnf update -y
```

#### 2-3. Java 설치 (Jenkins 필수 요구사항)

```bash
# Amazon Corretto 21 설치 (AL2023.2 이상에서 지원)
sudo dnf install java-21-amazon-corretto -y

# 또는 Corretto 17 설치 (안정적인 LTS 버전)
# sudo dnf install java-17-amazon-corretto -y

# 설치 확인
java -version
```

**예상 출력:**
```
openjdk version "21.0.x"
OpenJDK Runtime Environment Corretto-21.0.x
```

> 💡 **참고**: Amazon Linux 2023.2부터 Corretto 21이 지원됩니다. Jenkins는 Java 17 이상을 권장합니다.

#### 2-4. Jenkins 저장소 추가 및 설치

```bash
# 패키지 업그레이드 (권장)
sudo dnf upgrade -y

# Jenkins 저장소 추가
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Jenkins GPG 키 추가
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Jenkins 설치
sudo dnf install jenkins -y
```

> 📌 **AWS 공식 권장 순서**: update → repo 추가 → GPG 키 → upgrade → Java 설치 → Jenkins 설치

#### 2-5. Jenkins 서비스 시작

```bash
# Jenkins 서비스 활성화 (부팅 시 자동 시작)
sudo systemctl enable jenkins

# Jenkins 서비스 시작
sudo systemctl start jenkins

# 상태 확인
sudo systemctl status jenkins
```

> ⚠️ **주의**: `systemctl enable`과 `systemctl start`의 대소문자에 주의하세요. `Jenkins`가 아니라 `jenkins`입니다.

**예상 출력:**
```
● jenkins.service - Jenkins Continuous Integration Server
     Loaded: loaded
     Active: active (running)
```

---

### Step 3: Jenkins 초기 설정

#### 3-1. 초기 관리자 비밀번호 확인

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

> 📋 출력된 비밀번호를 복사해두세요.

#### 3-2. Jenkins 웹 UI 접속

1. 브라우저에서 `http://<EC2-Public-IP>:8080` 접속
2. 초기 관리자 비밀번호 입력
3. **Install suggested plugins** 선택 (권장 플러그인 자동 설치)

#### 3-3. 관리자 계정 생성

| 항목 | 예시 값 |
|------|---------|
| Username | admin |
| Password | (강력한 비밀번호) |
| Full name | Administrator |
| E-mail | your-email@example.com |

#### 3-4. Jenkins URL 설정

- 기본값 유지: `http://<EC2-Public-IP>:8080/`
- **Save and Finish** 클릭

---

### Step 4: 필수 플러그인 설치

#### 4-1. 플러그인 관리 페이지 이동

`Dashboard` → `Manage Jenkins` → `Plugins` → `Available plugins`

#### 4-2. CI/CD 파이프라인에 필요한 플러그인

| 플러그인 | 용도 |
|----------|------|
| **Pipeline** | Jenkinsfile 기반 파이프라인 (기본 설치됨) |
| **Git** | Git 저장소 연동 (기본 설치됨) |
| **GitHub Integration** | GitHub Webhook 연동 |
| **Docker Pipeline** | Docker 빌드/푸시 |
| **Amazon ECR** | AWS ECR 연동 |
| **Pipeline: AWS Steps** | AWS CLI 명령 실행 |
| **Credentials Binding** | 자격 증명 관리 |
| **Blue Ocean** | 시각화된 파이프라인 UI (선택) |

#### 4-3. 플러그인 설치 방법

1. 검색창에 플러그인 이름 입력
2. 체크박스 선택
3. **Install** 클릭
4. 설치 완료 후 Jenkins 재시작

```bash
# 재시작 명령 (필요 시)
sudo systemctl restart jenkins
```

---

## ✅ 검증 체크리스트

| 항목 | 확인 방법 | 완료 |
|------|----------|------|
| EC2 인스턴스 실행 중 | AWS Console에서 상태 확인 | ☐ |
| Jenkins 서비스 실행 중 | `systemctl status jenkins` | ☐ |
| 웹 UI 접속 가능 | 브라우저에서 8080 포트 접속 | ☐ |
| 관리자 로그인 가능 | 생성한 계정으로 로그인 | ☐ |
| 필수 플러그인 설치됨 | Plugin Manager에서 확인 | ☐ |

---

## 🔧 트러블슈팅

### 문제 1: Jenkins 웹 페이지 접속 불가

**원인**: 보안 그룹에서 8080 포트가 열려있지 않음

**해결**:
```
EC2 Console → Security Groups → Inbound rules → Edit
→ Add rule: Custom TCP, Port 8080, Source: My IP
```

### 문제 2: Jenkins 서비스 시작 실패

**원인**: Java가 설치되지 않았거나 버전 불일치

**해결**:
```bash
# Java 버전 확인
java -version

# 없으면 재설치
sudo dnf install java-17-amazon-corretto -y
sudo systemctl restart jenkins
```

### 문제 3: 초기 비밀번호 파일이 없음

**원인**: Jenkins가 아직 완전히 시작되지 않음

**해결**:
```bash
# 서비스 상태 확인 후 잠시 대기
sudo systemctl status jenkins
sleep 30
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

---

## 💡 팁 & 베스트 프랙티스

### 비용 절약 팁

```bash
# 사용하지 않을 때 EC2 중지 (데이터는 유지됨)
# AWS Console → EC2 → Instance → Stop

# 또는 AWS CLI 사용
aws ec2 stop-instances --instance-ids <instance-id>
```

### Jenkins 백업

```bash
# Jenkins 홈 디렉토리 백업
sudo tar -czvf jenkins-backup.tar.gz /var/lib/jenkins
```

### 보안 강화

1. **HTTPS 설정** (프로덕션 환경에서 필수)
2. **정기적인 플러그인 업데이트**
3. **불필요한 플러그인 제거**

---

## 📚 참고 자료

- [Jenkins 공식 문서](https://www.jenkins.io/doc/)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [Jenkins on AWS Best Practices](https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/)

---

## 📅 다음 단계

**[02. GitHub Webhook 연동](./02_GitHub_Webhook_연동.md)** 에서 Jenkins와 GitHub를 연결하여 코드 푸시 시 자동 빌드가 트리거되도록 설정합니다.

---

> 📝 **작성일**: 2024년  
> 🔄 **최종 수정**: 2026년 11월 (AWS MCP 검증)  
> 👤 **작성자**: [Your Name]
