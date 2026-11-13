# ECS Fargate 배포 자동화

## 🤔 ECS와 Fargate란?

### ECS(Elastic Container Service) 정의

**ECS**는 Docker 컨테이너를 AWS에서 쉽게 실행하고 관리할 수 있게 해주는 **컨테이너 오케스트레이션 서비스**입니다.

```
[비유: 레스토랑]

컨테이너 = 요리사 (실제 일하는 사람)
ECS = 레스토랑 매니저 (요리사 배치, 교대, 휴식 관리)

매니저가 하는 일:
- "3번 테이블 손님 많아, 요리사 더 투입해" (Auto Scaling)
- "1번 요리사 아파, 2번이 대신해" (Health Check & Recovery)
- "점심시간 끝, 요리사 줄여" (Scale Down)
```

### EC2 vs Fargate

| 항목 | EC2 시작 유형 | Fargate 시작 유형 |
|------|--------------|-------------------|
| 서버 관리 | 직접 관리 필요 | AWS가 관리 (서버리스) |
| 비용 | 서버 상시 비용 | 사용한 만큼만 |
| 스케일링 | 서버 단위 | 컨테이너 단위 |
| 보안 패치 | 직접 적용 | AWS가 적용 |
| 적합한 상황 | 세밀한 제어 필요 시 | 빠른 시작, 관리 최소화 |

### 왜 Fargate를 선택하는가?

**전통 방식 (EC2에 직접 배포):**
```
서버 구매 → OS 설치 → 보안 패치 → 런타임 설치 → 앱 배포 → 모니터링 설정
    ↓           ↓           ↓           ↓           ↓           ↓
  비용 발생   시간 소요    귀찮음      버전 충돌    장애 가능    복잡함
```

**Fargate 방식:**
```
Docker 이미지 → ECS에 배포 → 끝!
                    ↓
           AWS가 나머지 다 해줌
```

### 이 실습의 목적

**ECS Fargate 배포를 배우면:**
- 서버 관리 없이 컨테이너를 운영할 수 있습니다
- ALB로 트래픽을 분산할 수 있습니다
- 자동 스케일링으로 부하에 대응할 수 있습니다
- Jenkins에서 원클릭 배포가 가능해집니다

### 실습 후 기대 효과

```
[실습 전]
ECR에 이미지 저장됨 → ???

[실습 후]
코드 푸시 → 빌드 → ECR 푸시 → ECS 자동 배포 → 사용자 접속 가능!
                                    ↓
                         문제 시 자동 롤백, 자동 복구
```

### CI/CD 전체 그림에서의 위치

```
+----------+     +----------+     +---------+     +------------+
|  GitHub  | --> |  Jenkins | --> |   ECR   | --> | ECS Fargate|
+----------+     +----------+     +---------+     +------------+
   소스코드        빌드/테스트       이미지 저장      실제 서비스 운영
                                                   (이번 실습!)
```

---

## 📋 개요

| 항목 | 내용 |
|------|------|
| 목적 | Jenkins 파이프라인에서 ECR 이미지를 ECS Fargate로 자동 배포 |
| 선행 조건 | Docker 이미지 ECR 푸시 완료 (04장 참고) |
| 예상 소요 시간 | 2~3시간 |
| 난이도 | ★★★★☆ (중상급) |

---

## 🎯 학습 목표

- [ ] ECS 클러스터 및 Fargate 서비스 생성
- [ ] Task Definition 작성
- [ ] ALB(Application Load Balancer) 연동
- [ ] Jenkins 파이프라인에서 ECS 배포 자동화
- [ ] Blue/Green 또는 Rolling 배포 전략 이해

---

## 🏗️ 아키텍처

```
                          +-------------------------------------+
                          |             AWS VPC                 |
+--------+   +--------+   |                                     |
| GitHub |-->| Jenkins|   |   [Public Subnets]                  |
+--------+   +---+----+   |   +-----------------------------+   |
                 |        |   | Application Load Balancer   |   |
                 | Build  |   |         (Port 80)           |   |
                 v        |   +-------------+---------------+   |
            +--------+    |                 |                   |
            |  ECR   |    |   [Private Subnets]                 |
            +---+----+    |                 v                   |
                |         |   +-----------------------------+   |
                | Pull    |   |    ECS Fargate Cluster      |   |
                +---------|-->|  +-------+    +-------+     |   |
                          |   |  |Task 1 |    |Task 2 |     |   |
                          |   |  +-------+    +-------+     |   |
                          |   +-----------------------------+   |
                          |                                     |
                          +-------------------------------------+
```

---

## 📝 실습 단계

### Step 1: VPC 및 네트워크 설정

#### 1-1. VPC 생성 (기존 VPC 사용 가능)

AWS Console → VPC → **Create VPC**

| 항목 | 값 |
|------|-----|
| Name | jenkins-cicd-vpc |
| IPv4 CIDR | 10.0.0.0/16 |
| Tenancy | Default |

#### 1-2. 서브넷 생성

**Public Subnets (ALB용)**

| 이름 | AZ | CIDR |
|------|-----|------|
| public-subnet-1 | ap-northeast-2a | 10.0.1.0/24 |
| public-subnet-2 | ap-northeast-2c | 10.0.2.0/24 |

**Private Subnets (ECS Task용)**

| 이름 | AZ | CIDR |
|------|-----|------|
| private-subnet-1 | ap-northeast-2a | 10.0.11.0/24 |
| private-subnet-2 | ap-northeast-2c | 10.0.12.0/24 |

#### 1-3. Internet Gateway & NAT Gateway

```
1. Internet Gateway 생성 및 VPC 연결
2. NAT Gateway 생성 (Public Subnet에 배치)
3. Route Table 설정:
   - Public RT: 0.0.0.0/0 → Internet Gateway
   - Private RT: 0.0.0.0/0 → NAT Gateway
```

> 💰 **비용 팁**: NAT Gateway는 시간당 비용이 발생합니다. 학습 후 삭제하거나, Public Subnet에 Task를 배치하는 방법도 있습니다.

---

### Step 2: ECS 클러스터 생성

#### 2-1. AWS Console에서 생성

ECS Console → **Create Cluster**

| 항목 | 값 |
|------|-----|
| Cluster name | jenkins-cicd-cluster |
| Infrastructure | AWS Fargate (serverless) |

#### 2-2. AWS CLI로 생성

```bash
aws ecs create-cluster \
    --cluster-name jenkins-cicd-cluster \
    --capacity-providers FARGATE FARGATE_SPOT \
    --default-capacity-provider-strategy \
        capacityProvider=FARGATE,weight=1 \
        capacityProvider=FARGATE_SPOT,weight=1 \
    --region ap-northeast-2
```

---

### Step 3: Task Definition 생성

#### 3-1. Task Definition JSON

**`task-definition.json`**

```json
{
    "family": "jenkins-cicd-demo",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "256",
    "memory": "512",
    "executionRoleArn": "arn:aws:iam::<AWS_ACCOUNT_ID>:role/ecsTaskExecutionRole",
    "runtimePlatform": {
        "cpuArchitecture": "X86_64",
        "operatingSystemFamily": "LINUX"
    },
    "containerDefinitions": [
        {
            "name": "app",
            "image": "<AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/jenkins-cicd-demo:latest",
            "essential": true,
            "portMappings": [
                {
                    "containerPort": 3000,
                    "hostPort": 3000,
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "NODE_ENV",
                    "value": "production"
                },
                {
                    "name": "PORT",
                    "value": "3000"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/jenkins-cicd-demo",
                    "awslogs-region": "ap-northeast-2",
                    "awslogs-stream-prefix": "ecs",
                    "awslogs-create-group": "true"
                }
            },
            "healthCheck": {
                "command": ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1"],
                "interval": 30,
                "timeout": 5,
                "retries": 3,
                "startPeriod": 60
            }
        }
    ]
}
```

> 📌 **참고**: `runtimePlatform`은 Fargate 1.4.0 이상에서 지원되며, ARM64 아키텍처를 사용하려면 `"cpuArchitecture": "ARM64"`로 변경하세요 (Graviton 프로세서 사용 시 비용 절감).

#### 3-2. IAM Role 생성: ecsTaskExecutionRole

**신뢰 관계 (Trust Policy)**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

**연결할 정책**
- `AmazonECSTaskExecutionRolePolicy` (AWS 관리형)

#### 3-3. CloudWatch Logs 그룹 생성

```bash
aws logs create-log-group \
    --log-group-name /ecs/jenkins-cicd-demo \
    --region ap-northeast-2
```

#### 3-4. Task Definition 등록

```bash
aws ecs register-task-definition \
    --cli-input-json file://task-definition.json \
    --region ap-northeast-2
```

---

### Step 4: Application Load Balancer 생성

#### 4-1. Security Group 생성

**ALB Security Group**

| Type | Protocol | Port | Source | 설명 |
|------|----------|------|--------|------|
| HTTP | TCP | 80 | 0.0.0.0/0 | 외부 접근 |

**ECS Task Security Group**

| Type | Protocol | Port | Source | 설명 |
|------|----------|------|--------|------|
| Custom TCP | TCP | 3000 | ALB SG | ALB에서만 접근 |

#### 4-2. Target Group 생성

EC2 Console → Target Groups → **Create target group**

| 항목 | 값 |
|------|-----|
| Target type | IP |
| Target group name | jenkins-cicd-demo-tg |
| Protocol | HTTP |
| Port | 3000 |
| VPC | jenkins-cicd-vpc |
| Health check path | /health |

#### 4-3. ALB 생성

EC2 Console → Load Balancers → **Create Application Load Balancer**

| 항목 | 값 |
|------|-----|
| Name | jenkins-cicd-demo-alb |
| Scheme | Internet-facing |
| IP address type | IPv4 |
| VPC | jenkins-cicd-vpc |
| Subnets | public-subnet-1, public-subnet-2 |
| Security group | ALB Security Group |
| Listener | HTTP:80 → Target Group |

---

### Step 5: ECS Service 생성

#### 5-1. AWS Console에서 생성

ECS Console → Cluster → **Create Service**

| 항목 | 값 |
|------|-----|
| Launch type | FARGATE |
| Task Definition | jenkins-cicd-demo |
| Service name | jenkins-cicd-demo-service |
| Desired tasks | 2 |
| Deployment type | Rolling update |

**Networking**

| 항목 | 값 |
|------|-----|
| VPC | jenkins-cicd-vpc |
| Subnets | private-subnet-1, private-subnet-2 |
| Security group | ECS Task SG |
| Auto-assign public IP | DISABLED |

**Load Balancing**

| 항목 | 값 |
|------|-----|
| Load balancer type | Application Load Balancer |
| Load balancer | jenkins-cicd-demo-alb |
| Container name:port | app:3000 |
| Target group | jenkins-cicd-demo-tg |

#### 5-2. AWS CLI로 생성

```bash
aws ecs create-service \
    --cluster jenkins-cicd-cluster \
    --service-name jenkins-cicd-demo-service \
    --task-definition jenkins-cicd-demo \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-xxxxx,subnet-yyyyy],securityGroups=[sg-xxxxx],assignPublicIp=DISABLED}" \
    --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:ap-northeast-2:<ACCOUNT_ID>:targetgroup/jenkins-cicd-demo-tg/xxxxx,containerName=app,containerPort=3000" \
    --region ap-northeast-2
```

---

### Step 6: Jenkins ECS 배포 파이프라인

#### 6-1. Jenkins IAM 권한 추가

기존 `JenkinsECRPolicy`에 ECS 권한 추가:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecs:DescribeServices",
                "ecs:DescribeTaskDefinition",
                "ecs:DescribeTasks",
                "ecs:ListTasks",
                "ecs:RegisterTaskDefinition",
                "ecs:UpdateService"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "arn:aws:iam::<AWS_ACCOUNT_ID>:role/ecsTaskExecutionRole"
        }
    ]
}
```

#### 6-2. 완성된 Jenkinsfile (빌드 + 배포)

```groovy
pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = '<YOUR_AWS_ACCOUNT_ID>'
        AWS_REGION = 'ap-northeast-2'
        ECR_REPO_NAME = 'jenkins-cicd-demo'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPO_NAME}"
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        ECS_CLUSTER = 'jenkins-cicd-cluster'
        ECS_SERVICE = 'jenkins-cicd-demo-service'
        TASK_FAMILY = 'jenkins-cicd-demo'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "📥 코드 체크아웃 완료"
            }
        }

        stage('Test') {
            steps {
                echo "🧪 테스트 실행 중..."
                sh 'npm install'
                sh 'npm test'
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                echo "🐳 Docker 이미지 빌드 및 ECR 푸시..."
                sh """
                    # ECR 로그인
                    aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    
                    # 빌드 및 태그
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                    
                    # 푸시
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                """
            }
        }

        stage('Update Task Definition') {
            steps {
                echo "📝 Task Definition 업데이트 중..."
                script {
                    // 현재 Task Definition 조회
                    def taskDef = sh(
                        script: """
                            aws ecs describe-task-definition \
                                --task-definition ${TASK_FAMILY} \
                                --region ${AWS_REGION} \
                                --query 'taskDefinition' \
                                --output json
                        """,
                        returnStdout: true
                    ).trim()
                    
                    // 새 이미지로 업데이트
                    def newTaskDef = readJSON text: taskDef
                    newTaskDef.containerDefinitions[0].image = "${IMAGE_NAME}:${IMAGE_TAG}"
                    
                    // 불필요한 필드 제거
                    newTaskDef.remove('taskDefinitionArn')
                    newTaskDef.remove('revision')
                    newTaskDef.remove('status')
                    newTaskDef.remove('requiresAttributes')
                    newTaskDef.remove('compatibilities')
                    newTaskDef.remove('registeredAt')
                    newTaskDef.remove('registeredBy')
                    
                    // 새 Task Definition 등록
                    writeJSON file: 'new-task-def.json', json: newTaskDef
                    
                    sh """
                        aws ecs register-task-definition \
                            --cli-input-json file://new-task-def.json \
                            --region ${AWS_REGION}
                    """
                }
            }
        }

        stage('Deploy to ECS') {
            steps {
                echo "🚀 ECS 서비스 업데이트 중..."
                sh """
                    aws ecs update-service \
                        --cluster ${ECS_CLUSTER} \
                        --service ${ECS_SERVICE} \
                        --task-definition ${TASK_FAMILY} \
                        --force-new-deployment \
                        --region ${AWS_REGION}
                """
            }
        }

        stage('Wait for Deployment') {
            steps {
                echo "⏳ 배포 완료 대기 중..."
                sh """
                    aws ecs wait services-stable \
                        --cluster ${ECS_CLUSTER} \
                        --services ${ECS_SERVICE} \
                        --region ${AWS_REGION}
                """
                echo "✅ 배포 완료!"
            }
        }
    }

    post {
        success {
            echo """
            ✅ 배포 성공!
            📦 Image: ${IMAGE_NAME}:${IMAGE_TAG}
            🌐 Service: ${ECS_SERVICE}
            """
        }
        failure {
            echo "❌ 배포 실패!"
            // 롤백 로직 추가 가능
        }
        always {
            // 정리
            sh """
                docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true
                docker rmi ${IMAGE_NAME}:latest || true
                docker logout ${ECR_REGISTRY} || true
                rm -f new-task-def.json || true
            """
        }
    }
}
```

---

### Step 7: 배포 검증

#### 7-1. ALB DNS로 접속 테스트

```bash
# ALB DNS 확인
aws elbv2 describe-load-balancers \
    --names jenkins-cicd-demo-alb \
    --query 'LoadBalancers[0].DNSName' \
    --output text

# 접속 테스트
curl http://<ALB_DNS_NAME>/
curl http://<ALB_DNS_NAME>/health
```

#### 7-2. ECS 서비스 상태 확인

```bash
# 서비스 상태
aws ecs describe-services \
    --cluster jenkins-cicd-cluster \
    --services jenkins-cicd-demo-service \
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# 태스크 목록
aws ecs list-tasks \
    --cluster jenkins-cicd-cluster \
    --service-name jenkins-cicd-demo-service
```

---

## ✅ 검증 체크리스트

| 항목 | 확인 방법 | 완료 |
|------|----------|------|
| ECS 클러스터 생성됨 | AWS Console에서 확인 | ☐ |
| Task Definition 등록됨 | `aws ecs list-task-definitions` | ☐ |
| ALB 생성 및 헬스체크 통과 | Target Group 상태 확인 | ☐ |
| ECS Service 실행 중 | Desired = Running count | ☐ |
| ALB 엔드포인트 접속 가능 | curl 테스트 | ☐ |
| Jenkins 배포 자동화 동작 | Push 후 배포 확인 | ☐ |

---

## 🔧 트러블슈팅

### 문제 1: Task가 PENDING 상태로 머무름

**원인**: 리소스 부족 또는 네트워크 설정 문제

**해결**:
```bash
# Task 상태 상세 확인
aws ecs describe-tasks \
    --cluster jenkins-cicd-cluster \
    --tasks <TASK_ARN>

# 일반적인 원인:
# 1. 서브넷에 가용 IP 없음
# 2. NAT Gateway 없음 (Private Subnet의 경우)
# 3. Security Group 문제
```

### 문제 2: Target Group 헬스체크 실패

**원인**: 애플리케이션 미응답 또는 포트 설정 오류

**해결**:
```
1. Task 로그 확인 (CloudWatch Logs)
2. Security Group에서 3000 포트 열려있는지 확인
3. Health check path (/health) 존재하는지 확인
4. Health check 타이밍 조정 (interval, startPeriod)
```

### 문제 3: "services-stable" 타임아웃

**원인**: 새 Task가 정상 시작되지 않음

**해결**:
```bash
# 이벤트 로그 확인
aws ecs describe-services \
    --cluster jenkins-cicd-cluster \
    --services jenkins-cicd-demo-service \
    --query 'services[0].events[:5]'
```

### 문제 4: ECR 이미지 Pull 실패

**원인**: Task Execution Role 권한 부족

**해결**:
```
1. ecsTaskExecutionRole에 AmazonECSTaskExecutionRolePolicy 연결 확인
2. ECR 리포지토리 정책 확인
```

---

## 💡 팁 & 베스트 프랙티스

### 배포 전략 선택

| 전략 | 설명 | 적합한 상황 |
|------|------|-------------|
| Rolling Update | 점진적 교체 | 일반적인 배포 |
| Blue/Green | 완전한 환경 교체 | 무중단, 빠른 롤백 필요 |
| Canary | 일부 트래픽만 새 버전 | 신중한 검증 필요 |

### Auto Scaling 설정

```bash
# 서비스 Auto Scaling 등록
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id service/jenkins-cicd-cluster/jenkins-cicd-demo-service \
    --min-capacity 1 \
    --max-capacity 4

# CPU 기반 스케일링 정책
aws application-autoscaling put-scaling-policy \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id service/jenkins-cicd-cluster/jenkins-cicd-demo-service \
    --policy-name cpu-scaling \
    --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration \
        "TargetValue=70,PredefinedMetricSpecification={PredefinedMetricType=ECSServiceAverageCPUUtilization}"
```

### 비용 최적화

```
1. FARGATE_SPOT 용량 공급자 활용 (최대 70% 절약)
2. 개발 환경은 최소 Task 수 (1개)
3. 학습 후 불필요한 리소스 즉시 삭제
4. NAT Gateway 대신 Public Subnet + Public IP 고려
```

---

## 📚 참고 자료

- [Amazon ECS Developer Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/)
- [ECS Fargate Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)

---

## 📅 다음 단계

**[06. GitOps와 ArgoCD (선택)](./06_GitOps_ArgoCD_연동.md)** 에서 EKS와 ArgoCD를 활용한 GitOps 스타일 배포를 학습합니다.

---

> 📝 **작성일**: 2024년  
> 🔄 **최종 수정**: 2026년 11월 (AWS MCP 검증)  
> 👤 **작성자**: [Your Name]
