# Docker 이미지 빌드 및 ECR 푸시

## 🤔 왜 Docker와 ECR을 사용하는가?

### Docker란?

**Docker**는 애플리케이션을 **컨테이너**라는 격리된 환경에서 실행하는 기술입니다.

```
[비유: 이사]

전통 방식 (물리 서버):
"이 프로그램 실행하려면 Java 8, Node 14, Python 3.8이 필요해요"
"근데 다른 프로그램은 Java 11, Node 16이 필요한데요?"
→ 충돌 발생!

Docker 방식 (컨테이너):
각 프로그램이 자기만의 "방"(컨테이너)에서 실행
→ 서로 영향 없음!
```

### "내 PC에서는 됐는데" 문제 해결

| 상황 | 원인 | Docker 해결 |
|------|------|-------------|
| 개발 PC에서 잘 됨 | 개발자 PC 환경 | 동일한 컨테이너 사용 |
| 테스트 서버에서 실패 | 라이브러리 버전 다름 | 컨테이너에 포함 |
| 운영 서버에서 오류 | OS 설정 다름 | 컨테이너로 통일 |

### ECR(Elastic Container Registry)란?

**ECR**은 Docker 이미지를 저장하는 **AWS의 이미지 저장소**입니다.

```
[비유: 창고]

Docker 이미지 = 택배 상자 (앱 + 실행환경이 담긴 패키지)
ECR = AWS 물류 창고 (상자를 보관하고 필요할 때 꺼내줌)
ECS/EKS = 배송지 (실제로 상자를 열어서 사용하는 곳)
```

### 왜 ECR을 사용하는가?

| 옵션 | 장점 | 단점 |
|------|------|------|
| Docker Hub | 무료 플랜 있음 | 속도 느림, 보안 제한 |
| **AWS ECR** | AWS 서비스와 통합, 빠름 | AWS 계정 필요 |
| 자체 Registry | 완전한 통제 | 직접 관리 필요 |

### 이 실습의 목적

**Docker 빌드 + ECR 푸시를 배우면:**
- 애플리케이션을 컨테이너로 패키징할 수 있습니다
- 어디서든 동일하게 실행되는 이미지를 만들 수 있습니다
- AWS 서비스(ECS, EKS)에 배포할 준비가 완료됩니다

### 실습 후 기대 효과

```
[실습 전]
코드 푸시 → Jenkins 빌드 → (끝)

[실습 후]
코드 푸시 → Jenkins 빌드 → Docker 이미지 생성 → ECR에 저장
                                                    ↓
                                        어디서든 이 이미지로 실행 가능!
```

---

## 📋 개요

| 항목 | 내용 |
|------|------|
| 목적 | Jenkins에서 Docker 이미지를 빌드하고 AWS ECR에 푸시하는 파이프라인 구성 |
| 선행 조건 | Jenkins 설치 및 Jenkinsfile 작성 완료 (01~03장 참고) |
| 예상 소요 시간 | 2시간 |
| 난이도 | ★★★☆☆ (중급) |

---

## 🎯 학습 목표

- [ ] EC2에 Docker 설치 및 설정
- [ ] AWS ECR 저장소 생성
- [ ] Jenkins에 AWS 자격 증명 등록
- [ ] Docker 빌드 및 ECR 푸시 파이프라인 작성

---

## 🏗️ 아키텍처

```
+----------+     +-----------------+     +-----------+
|  GitHub  |---->|     Jenkins     |---->|  AWS ECR  |
|          |     |  (EC2 + Docker) |     |           |
+----------+     +-----------------+     +-----------+
     |                   |                     |
     v                   v                     v
 1.Push Code      2.Build Docker          3.Push to ECR
                    Image
```

---

## 📝 실습 단계

### Step 1: EC2에 Docker 설치

#### 1-1. Jenkins EC2에 SSH 접속

```bash
ssh -i "your-key.pem" ec2-user@<Jenkins-EC2-IP>
```

#### 1-2. Docker 설치

```bash
# Docker 설치
sudo dnf install docker -y

# Docker 서비스 시작 및 자동 시작 설정
sudo systemctl start docker
sudo systemctl enable docker

# 설치 확인
docker --version
```

#### 1-3. Jenkins 사용자에게 Docker 권한 부여

```bash
# jenkins 사용자를 docker 그룹에 추가
sudo usermod -aG docker jenkins

# 변경 사항 적용을 위해 Jenkins 재시작
sudo systemctl restart jenkins

# 권한 확인 (jenkins 사용자로 전환 후)
sudo -u jenkins docker ps
```

> ⚠️ **주의**: 권한 변경 후 반드시 Jenkins 재시작 필요

---

### Step 2: AWS ECR 저장소 생성

#### 2-1. AWS Console에서 생성

1. AWS Console → ECR (Elastic Container Registry) 이동
2. **Create repository** 클릭
3. 설정:

| 항목 | 값 |
|------|-----|
| Visibility | Private |
| Repository name | jenkins-cicd-demo |
| Tag immutability | Disabled (학습용) |
| Scan on push | Enabled (권장) |

4. **Create repository** 클릭

#### 2-2. AWS CLI로 생성 (대안)

```bash
aws ecr create-repository \
    --repository-name jenkins-cicd-demo \
    --image-scanning-configuration scanOnPush=true \
    --region ap-northeast-2
```

#### 2-3. ECR URI 확인

생성된 저장소의 URI를 메모해두세요:
```
<AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/jenkins-cicd-demo
```

---

### Step 3: IAM 설정

#### 3-1. Jenkins용 IAM 정책 생성

**정책 이름**: `JenkinsECRPolicy`

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage"
            ],
            "Resource": "arn:aws:ecr:ap-northeast-2:<AWS_ACCOUNT_ID>:repository/jenkins-cicd-demo"
        }
    ]
}
```

#### 3-2. IAM 사용자/역할 설정

**옵션 A: EC2 IAM Role 사용 (권장)**

1. EC2 Console → Jenkins 인스턴스 선택
2. Actions → Security → Modify IAM role
3. 새 역할 생성 또는 기존 역할에 `JenkinsECRPolicy` 연결

**옵션 B: IAM Access Key 사용**

1. IAM → Users → 새 사용자 생성 (예: `jenkins-ecr-user`)
2. `JenkinsECRPolicy` 정책 연결
3. Access Key 생성 및 저장

---

### Step 4: Jenkins 자격 증명 등록

#### 4-1. AWS Credentials 플러그인 설치

`Manage Jenkins` → `Plugins` → `Available plugins`
- **AWS Credentials** 검색 및 설치
- **Amazon ECR** 플러그인 설치
- **Docker Pipeline** 플러그인 설치

#### 4-2. AWS 자격 증명 등록 (Access Key 방식 사용 시)

`Manage Jenkins` → `Credentials` → `System` → `Global credentials`

1. **Add Credentials** 클릭
2. 설정:

| 항목 | 값 |
|------|-----|
| Kind | AWS Credentials |
| ID | aws-ecr-credentials |
| Description | AWS ECR Access Credentials |
| Access Key ID | (IAM Access Key ID) |
| Secret Access Key | (IAM Secret Access Key) |

3. **Create** 클릭

---

### Step 5: 샘플 애플리케이션 Dockerfile 작성

#### 5-1. Node.js 샘플 애플리케이션 구조

```
jenkins-cicd-demo/
├── Dockerfile
├── Jenkinsfile
├── package.json
├── src/
│   └── index.js
└── .dockerignore
```

#### 5-2. 파일 내용

**`package.json`**

```json
{
  "name": "jenkins-cicd-demo",
  "version": "1.0.0",
  "description": "Jenkins CI/CD Demo Application",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "test": "echo \"Running tests...\" && exit 0"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

**`src/index.js`**

```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.json({
        message: 'Hello from Jenkins CI/CD Demo!',
        version: process.env.APP_VERSION || '1.0.0',
        timestamp: new Date().toISOString()
    });
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
```

**`Dockerfile`**

```dockerfile
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# 의존성 파일 복사
COPY package*.json ./

# 프로덕션 의존성만 설치
RUN npm ci --only=production

# 소스 코드 복사
COPY src/ ./src/

# Production stage
FROM node:18-alpine

WORKDIR /app

# 빌드 스테이지에서 필요한 파일만 복사
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY --from=builder /app/package*.json ./

# 보안: 루트가 아닌 사용자로 실행
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
USER nodejs

# 포트 노출
EXPOSE 3000

# 헬스체크
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# 애플리케이션 실행
CMD ["node", "src/index.js"]
```

**`.dockerignore`**

```
node_modules
npm-debug.log
Dockerfile
.dockerignore
.git
.gitignore
README.md
Jenkinsfile
*.md
```

---

### Step 6: ECR 푸시 Jenkinsfile 작성

#### 6-1. 완성된 Jenkinsfile

```groovy
pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = '<YOUR_AWS_ACCOUNT_ID>'  // 실제 계정 ID로 변경
        AWS_REGION = 'ap-northeast-2'
        ECR_REPO_NAME = 'jenkins-cicd-demo'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPO_NAME}"
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "📥 코드 체크아웃 완료"
            }
        }

        stage('Run Tests') {
            steps {
                echo "🧪 테스트 실행 중..."
                sh 'npm install'
                sh 'npm test'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "🐳 Docker 이미지 빌드 중..."
                sh """
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                """
            }
        }

        stage('ECR Login') {
            steps {
                echo "🔐 ECR 로그인 중..."
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${ECR_REGISTRY}
                """
            }
        }

        stage('Push to ECR') {
            steps {
                echo "📤 ECR에 이미지 푸시 중..."
                sh """
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                """
            }
        }

        stage('Cleanup') {
            steps {
                echo "🧹 로컬 이미지 정리 중..."
                sh """
                    docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true
                    docker rmi ${IMAGE_NAME}:latest || true
                """
            }
        }
    }

    post {
        success {
            echo """
            ✅ 빌드 및 ECR 푸시 성공!
            📦 Image: ${IMAGE_NAME}:${IMAGE_TAG}
            """
        }
        failure {
            echo "❌ 빌드 실패!"
        }
        always {
            // Docker logout
            sh 'docker logout ${ECR_REGISTRY} || true'
        }
    }
}
```

#### 6-2. IAM Role 사용 시 (EC2 Instance Profile)

EC2에 IAM Role이 연결되어 있으면 별도의 자격 증명 없이 ECR 로그인 가능:

```groovy
stage('ECR Login') {
    steps {
        echo "🔐 ECR 로그인 중... (IAM Role 사용)"
        sh """
            aws ecr get-login-password --region ${AWS_REGION} | \
            docker login --username AWS --password-stdin ${ECR_REGISTRY}
        """
    }
}
```

#### 6-3. Access Key 사용 시 (withCredentials)

```groovy
stage('ECR Login') {
    steps {
        echo "🔐 ECR 로그인 중..."
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', 
                          credentialsId: 'aws-ecr-credentials']]) {
            sh """
                aws ecr get-login-password --region ${AWS_REGION} | \
                docker login --username AWS --password-stdin ${ECR_REGISTRY}
            """
        }
    }
}
```

---

### Step 7: 파이프라인 실행 및 검증

#### 7-1. 수동 빌드 실행

1. Jenkins Dashboard → `jenkins-cicd-demo` Job
2. **Build Now** 클릭
3. 빌드 진행 상황 모니터링

#### 7-2. ECR에서 이미지 확인

```bash
# AWS CLI로 확인
aws ecr describe-images \
    --repository-name jenkins-cicd-demo \
    --region ap-northeast-2

# 이미지 목록 조회
aws ecr list-images \
    --repository-name jenkins-cicd-demo \
    --region ap-northeast-2
```

#### 7-3. 이미지 Pull 테스트

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
    docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 Pull
docker pull <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/jenkins-cicd-demo:latest

# 로컬 실행 테스트
docker run -d -p 3000:3000 <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/jenkins-cicd-demo:latest

# 접속 테스트
curl http://localhost:3000
```

---

## ✅ 검증 체크리스트

| 항목 | 확인 방법 | 완료 |
|------|----------|------|
| Docker 설치됨 | `docker --version` | ☐ |
| Jenkins가 Docker 실행 가능 | `sudo -u jenkins docker ps` | ☐ |
| ECR 저장소 생성됨 | AWS Console에서 확인 | ☐ |
| IAM 권한 설정됨 | ECR 푸시 가능 | ☐ |
| Docker 빌드 성공 | Jenkins 콘솔 로그 | ☐ |
| ECR 푸시 성공 | ECR 콘솔에서 이미지 확인 | ☐ |
| 이미지 Pull 가능 | 로컬에서 Pull 테스트 | ☐ |

---

## 🔧 트러블슈팅

### 문제 1: "permission denied while trying to connect to the Docker daemon socket"

**원인**: Jenkins 사용자에게 Docker 권한 없음

**해결**:
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
# Jenkins 재시작 후 다시 시도
```

### 문제 2: "no basic auth credentials" ECR 로그인 실패

**원인**: AWS 자격 증명 문제

**해결**:
```bash
# EC2에서 IAM Role 확인
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# 또는 AWS CLI 구성 확인
aws sts get-caller-identity
```

### 문제 3: "unauthorized: authentication required" ECR 푸시 실패

**원인**: ECR 토큰 만료 (12시간 유효)

**해결**:
```bash
# 토큰 재발급
aws ecr get-login-password --region ap-northeast-2 | \
    docker login --username AWS --password-stdin <ECR_REGISTRY>
```

### 문제 4: 빌드 시 "no space left on device"

**원인**: Docker 이미지/컨테이너가 디스크 공간 차지

**해결**:
```bash
# 미사용 Docker 리소스 정리
docker system prune -af

# 특정 기간 이상 된 이미지 삭제
docker image prune -a --filter "until=24h"
```

---

## 💡 팁 & 베스트 프랙티스

### 이미지 태깅 전략

```groovy
environment {
    // Git commit SHA 사용
    GIT_SHORT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    
    // 브랜치명 + 빌드번호
    IMAGE_TAG = "${BRANCH_NAME}-${BUILD_NUMBER}"
    
    // Semantic Versioning (태그 기반)
    // VERSION = sh(script: 'git describe --tags --abbrev=0', returnStdout: true).trim()
}
```

### ECR 수명 주기 정책

> ⚠️ **중요**: 오래된 이미지를 방치하면 보안 취약점이 있는 소프트웨어가 실수로 배포될 수 있습니다. ECR 수명 주기 정책을 설정하여 자동으로 정리하세요.

```json
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
```

**수명 주기 정책 적용:**

```bash
aws ecr put-lifecycle-policy \
    --repository-name jenkins-cicd-demo \
    --lifecycle-policy-text file://lifecycle-policy.json \
    --region ap-northeast-2
```

> 💡 **팁**: 정책 적용 전 `aws ecr get-lifecycle-policy-preview`로 어떤 이미지가 삭제될지 미리 확인하세요. 이미지는 정책 조건 충족 후 **24시간 이내**에 만료됩니다.

### 멀티 스테이지 빌드 최적화

```dockerfile
# 캐시 활용을 위해 자주 변경되지 않는 레이어를 먼저 배치
COPY package*.json ./
RUN npm ci --only=production

# 자주 변경되는 소스코드는 마지막에 복사
COPY src/ ./src/
```

---

## 📚 참고 자료

- [AWS ECR User Guide](https://docs.aws.amazon.com/AmazonECR/latest/userguide/)
- [Docker Multi-stage Builds](https://docs.docker.com/develop/develop-images/multistage-build/)
- [Jenkins Docker Pipeline](https://www.jenkins.io/doc/book/pipeline/docker/)

---

## 📅 다음 단계

**[05. ECS Fargate 배포 자동화](./05_ECS_Fargate_배포_자동화.md)** 에서 ECR에 푸시된 이미지를 ECS Fargate로 자동 배포합니다.

---

> 📝 **작성일**: 2024년  
> 🔄 **최종 수정**: 2026년 11월 (AWS MCP 검증)  
> 👤 **작성자**: [Your Name]
