# GitOps와 ArgoCD 연동 (선택)

## 🤔 GitOps란?

### GitOps 정의

**GitOps**는 Git 저장소를 **인프라와 애플리케이션의 단일 진실 공급원(Single Source of Truth)**으로 사용하는 운영 방식입니다.

쉽게 말해, **"Git에 있는 대로 서버 상태가 유지되어야 한다"** 입니다.

### 전통 배포 vs GitOps 배포

**전통 방식 (Push 기반):**
```
개발자 → Jenkins "이거 배포해" → 서버에 Push

문제점:
- Jenkins가 서버 접근 권한 필요 (보안 위험)
- 서버 상태를 직접 변경 (누가 뭘 바꿨는지 추적 어려움)
- 서버가 장애나면? → 수동으로 복구
```

**GitOps 방식 (Pull 기반):**
```
개발자 → Git에 설정 변경 → ArgoCD가 감지 → 서버에 적용

장점:
- Git만 보면 서버 상태를 알 수 있음
- 변경 이력 = Git 히스토리
- 서버가 이상해지면? → Git 상태로 자동 복구
```

### GitOps를 왜 사용하는가?

| 상황 | 전통 방식 | GitOps |
|------|----------|--------|
| "지금 운영 서버 설정이 뭐야?" | SSH 접속해서 확인 | Git 보면 됨 |
| "누가 언제 배포했어?" | 로그 뒤져야 함 | git log |
| "어제 설정으로 롤백해줘" | 백업 있으면... | git revert |
| "서버 설정이 이상해졌어" | 수동 복구 | 자동 복구 |

### ArgoCD란?

**ArgoCD**는 Kubernetes를 위한 **GitOps 배포 도구**입니다.

```
[ArgoCD의 역할]

Git Repository          ArgoCD              Kubernetes
+-------------+       +--------+          +------------+
| 원하는 상태  | ----> | 비교   | -------> | 실제 상태   |
| (YAML 파일) |       | & 동기화|          | (클러스터)  |
+-------------+       +--------+          +------------+
                          |
                          v
                     다르면 자동 수정!
```

### Jenkins vs ArgoCD 역할 분리

| 역할 | 담당 도구 | 하는 일 |
|------|----------|---------|
| **CI** (빌드) | Jenkins | 코드 빌드, 테스트, 이미지 생성 |
| **CD** (배포) | ArgoCD | 이미지를 클러스터에 배포 |

```
코드 변경 → Jenkins(빌드) → ECR(이미지) → Git(설정 업데이트) → ArgoCD(배포) → EKS(실행)
```

### 이 실습의 목적

**GitOps + ArgoCD를 배우면:**
- 인프라를 코드로 완전히 관리할 수 있습니다
- 배포 상태를 항상 Git과 동기화할 수 있습니다
- 문제 발생 시 자동 복구가 가능합니다
- Kubernetes 배포의 베스트 프랙티스를 익힙니다

### 실습 후 기대 효과

```
[실습 전]
Jenkins가 빌드도 하고 배포도 함 → 복잡함, 권한 관리 어려움

[실습 후]
Jenkins: 빌드만 담당 → 단순해짐
ArgoCD: 배포만 담당 → Git이 진실의 원천
                    → 서버 상태 = Git 상태
                    → 드리프트 발생 시 자동 복구
```

---

## 📋 개요

| 항목 | 내용 |
|------|------|
| 목적 | Jenkins (CI) + ArgoCD (CD)를 활용한 GitOps 스타일 배포 구현 |
| 선행 조건 | ECS 배포 완료 (05장 참고), EKS에 대한 기본 이해 |
| 예상 소요 시간 | 4~6시간 |
| 난이도 | ★★★★★ (고급) |
| 예상 비용 | 월 $70+ (EKS 클러스터 비용) |

---

## 🎯 학습 목표

- [ ] GitOps 개념 및 원칙 이해
- [ ] EKS 클러스터 생성
- [ ] ArgoCD 설치 및 설정
- [ ] Jenkins CI + ArgoCD CD 파이프라인 구축
- [ ] 애플리케이션 자동 동기화 구현

---

## 🏗️ GitOps 아키텍처

```
+----------------------------------------------------------------------+
|                          GitOps Workflow                              |
|                                                                       |
|  +--------+    +--------+    +--------+    +-------------------+      |
|  | GitHub |--->| Jenkins|--->|  ECR   |    |    Config Repo    |      |
|  |(Source)|    |  (CI)  |    |(Image) |    | (Kubernetes YAML) |      |
|  +--------+    +--------+    +---+----+    +---------+---------+      |
|      |                           |                   |                |
|      | 1.Push Code               | 3.Update          |                |
|      |                           |   Image Tag       |                |
|      |         2.Build &         v                   v                |
|      |           Push Image  +---------------------------+            |
|      |                       |          ArgoCD           |            |
|      |                       |  (Continuous Deployment)  |            |
|      |                       |                           |            |
|      |                       |  - Monitors Config Repo   |            |
|      |                       |  - Syncs to EKS           |            |
|      |                       |  - Self-healing           |            |
|      |                       +-----------+---------------+            |
|      |                                   |                            |
|      |                                   | 4.Deploy                   |
|      |                                   v                            |
|      |                            +------------+                      |
|      |                            |    EKS     |                      |
|      |                            |  Cluster   |                      |
|      |                            +------------+                      |
+----------------------------------------------------------------------+
```

---

## 📝 GitOps 핵심 원칙

### GitOps 4가지 원칙

| 원칙 | 설명 |
|------|------|
| **선언적 (Declarative)** | 시스템 상태를 선언적으로 정의 |
| **버전 관리 (Versioned)** | Git이 Single Source of Truth |
| **자동 적용 (Automated)** | 승인된 변경사항 자동 배포 |
| **자동 복구 (Self-healing)** | 실제 상태가 선언된 상태와 다르면 자동 복구 |

### CI vs CD 분리

```
┌─────────────────┐    ┌─────────────────┐
│     Jenkins     │    │     ArgoCD      │
│      (CI)       │    │      (CD)       │
├─────────────────┤    ├─────────────────┤
│ • Code checkout │    │ • Config sync   │
│ • Build         │    │ • Deploy        │
│ • Test          │    │ • Rollback      │
│ • Image push    │    │ • Self-healing  │
│ • Update config │    │ • Drift detect  │
└─────────────────┘    └─────────────────┘
```

---

## 📝 실습 단계

### Step 1: EKS 클러스터 생성

#### 1-1. eksctl 설치

```bash
# Windows (PowerShell)
choco install eksctl

# 또는 수동 설치
curl -LO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Windows_amd64.zip"
```

#### 1-2. EKS 클러스터 생성

**`eks-cluster.yaml`**

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: jenkins-cicd-eks
  region: ap-northeast-2
  version: "1.28"

vpc:
  cidr: 10.10.0.0/16
  nat:
    gateway: Single  # 비용 절약: HighlyAvailable 대신 Single

managedNodeGroups:
  - name: worker-nodes
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 3
    volumeSize: 30
    ssh:
      allow: false
    iam:
      withAddonPolicies:
        imageBuilder: true
        albIngress: true
        cloudWatch: true

iam:
  withOIDC: true

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator"]
```

```bash
# 클러스터 생성 (15~20분 소요)
eksctl create cluster -f eks-cluster.yaml

# kubeconfig 업데이트
aws eks update-kubeconfig --name jenkins-cicd-eks --region ap-northeast-2

# 연결 확인
kubectl get nodes
```

> ⚠️ **비용 주의**: EKS 클러스터는 시간당 $0.10 + EC2 비용이 발생합니다. 학습 후 반드시 삭제하세요.

---

### Step 2: ArgoCD 설치

#### 2-1. ArgoCD 네임스페이스 및 설치

```bash
# 네임스페이스 생성
kubectl create namespace argocd

# ArgoCD 설치
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 설치 확인
kubectl get pods -n argocd
```

#### 2-2. ArgoCD 서버 외부 노출

**방법 1: LoadBalancer (AWS ELB)**

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# External IP 확인 (몇 분 소요)
kubectl get svc argocd-server -n argocd
```

**방법 2: Port Forward (로컬 테스트용)**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# 브라우저에서 https://localhost:8080 접속
```

#### 2-3. ArgoCD 초기 비밀번호 확인

```bash
# 초기 admin 비밀번호
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 출력된 비밀번호로 로그인
# Username: admin
# Password: (위 명령어 출력값)
```

#### 2-4. ArgoCD CLI 설치

```bash
# Windows
choco install argocd-cli

# 로그인
argocd login <ARGOCD_SERVER> --username admin --password <PASSWORD>

# 비밀번호 변경 (권장)
argocd account update-password
```

---

### Step 3: Config Repository 구성

#### 3-1. 새 GitHub 저장소 생성

저장소 이름: `jenkins-cicd-config`

#### 3-2. Kubernetes 매니페스트 작성

**디렉토리 구조**

```
jenkins-cicd-config/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── kustomization.yaml
│   └── hpa.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patch-replicas.yaml
    └── prod/
        ├── kustomization.yaml
        └── patch-replicas.yaml
```

**`base/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-cicd-demo
  labels:
    app: jenkins-cicd-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: jenkins-cicd-demo
  template:
    metadata:
      labels:
        app: jenkins-cicd-demo
    spec:
      containers:
        - name: app
          image: <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/jenkins-cicd-demo:latest
          ports:
            - containerPort: 3000
          env:
            - name: NODE_ENV
              value: "production"
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
```

**`base/service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: jenkins-cicd-demo
spec:
  type: LoadBalancer
  selector:
    app: jenkins-cicd-demo
  ports:
    - port: 80
      targetPort: 3000
      protocol: TCP
```

**`base/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app.kubernetes.io/name: jenkins-cicd-demo
```

**`overlays/dev/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

resources:
  - ../../base

patches:
  - path: patch-replicas.yaml

images:
  - name: <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/jenkins-cicd-demo
    newTag: latest
```

**`overlays/dev/patch-replicas.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-cicd-demo
spec:
  replicas: 1
```

---

### Step 4: ArgoCD Application 생성

#### 4-1. GitHub 저장소 연결

```bash
# Private 저장소인 경우 자격 증명 추가
argocd repo add https://github.com/<username>/jenkins-cicd-config.git \
    --username <github-username> \
    --password <github-token>
```

#### 4-2. Application 생성

**`argocd-application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jenkins-cicd-demo-dev
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/<username>/jenkins-cicd-config.git
    targetRevision: main
    path: overlays/dev
  
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  
  syncPolicy:
    automated:
      prune: true       # 불필요한 리소스 자동 삭제
      selfHeal: true    # 드리프트 자동 복구
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl apply -f argocd-application.yaml
```

#### 4-3. ArgoCD UI에서 확인

1. ArgoCD 웹 UI 접속
2. Applications 목록에서 `jenkins-cicd-demo-dev` 확인
3. Sync 상태 확인

---

### Step 5: Jenkins CI 파이프라인 수정

#### 5-1. Jenkins가 Config Repo를 업데이트하도록 수정

**완성된 GitOps Jenkinsfile**

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
        
        // Config Repository
        CONFIG_REPO = 'https://github.com/<username>/jenkins-cicd-config.git'
        CONFIG_REPO_BRANCH = 'main'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "📥 소스 코드 체크아웃 완료"
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
                    aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                """
            }
        }

        stage('Update Config Repository') {
            steps {
                echo "📝 Config Repository 업데이트 중..."
                withCredentials([usernamePassword(
                    credentialsId: 'github-credentials',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    sh """
                        # Config 저장소 클론
                        rm -rf config-repo
                        git clone https://${GIT_USER}:${GIT_TOKEN}@github.com/<username>/jenkins-cicd-config.git config-repo
                        cd config-repo
                        
                        # 이미지 태그 업데이트 (kustomization.yaml)
                        sed -i 's/newTag: .*/newTag: "${IMAGE_TAG}"/' overlays/dev/kustomization.yaml
                        
                        # 변경사항 커밋 및 푸시
                        git config user.email "jenkins@example.com"
                        git config user.name "Jenkins CI"
                        git add .
                        git diff --cached --quiet || git commit -m "Update image tag to ${IMAGE_TAG}"
                        git push origin ${CONFIG_REPO_BRANCH}
                    """
                }
            }
        }
    }

    post {
        success {
            echo """
            ✅ CI 완료!
            📦 Image: ${IMAGE_NAME}:${IMAGE_TAG}
            🔄 ArgoCD가 자동으로 배포를 시작합니다.
            """
        }
        failure {
            echo "❌ CI 실패!"
        }
        always {
            sh """
                docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true
                docker logout ${ECR_REGISTRY} || true
                rm -rf config-repo || true
            """
        }
    }
}
```

---

### Step 6: ECR Pull Secret 설정 (EKS)

#### 6-1. ECR Pull Secret 자동 갱신

EKS에서 ECR 이미지를 Pull하려면 자격 증명이 필요합니다.

**방법 1: IAM Role for Service Account (IRSA) - 권장**

```bash
# OIDC Provider 확인
eksctl utils associate-iam-oidc-provider --cluster jenkins-cicd-eks --approve

# Service Account 생성
eksctl create iamserviceaccount \
    --name ecr-pull-sa \
    --namespace dev \
    --cluster jenkins-cicd-eks \
    --attach-policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly \
    --approve
```

**Deployment에 Service Account 추가**

```yaml
spec:
  template:
    spec:
      serviceAccountName: ecr-pull-sa
      containers:
        - name: app
          ...
```

**방법 2: ImagePullSecret 수동 생성**

```bash
# ECR 토큰 획득 및 Secret 생성
kubectl create secret docker-registry ecr-secret \
    --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-2.amazonaws.com \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password --region ap-northeast-2) \
    -n dev
```

---

### Step 7: 전체 워크플로우 테스트

#### 7-1. 소스 코드 변경 및 푸시

```bash
# 소스 저장소에서
cd jenkins-cicd-demo
echo "// Updated" >> src/index.js
git add .
git commit -m "Feature: update app"
git push origin main
```

#### 7-2. 파이프라인 실행 확인

1. **Jenkins** → 자동 빌드 시작 확인
2. **ECR** → 새 이미지 태그 확인
3. **Config Repo** → kustomization.yaml 업데이트 확인
4. **ArgoCD** → 자동 Sync 및 배포 확인

#### 7-3. 배포 상태 확인

```bash
# 애플리케이션 상태
kubectl get pods -n dev

# 서비스 엔드포인트
kubectl get svc -n dev

# ArgoCD CLI로 확인
argocd app get jenkins-cicd-demo-dev
```

---

## ✅ 검증 체크리스트

| 항목 | 확인 방법 | 완료 |
|------|----------|------|
| EKS 클러스터 실행 중 | `kubectl get nodes` | ☐ |
| ArgoCD 설치됨 | ArgoCD UI 접속 | ☐ |
| Application 생성됨 | ArgoCD에서 앱 확인 | ☐ |
| Jenkins CI 동작 | 빌드 로그 확인 | ☐ |
| Config Repo 업데이트 | GitHub 커밋 히스토리 | ☐ |
| ArgoCD 자동 Sync | Sync 상태 확인 | ☐ |
| 애플리케이션 접근 가능 | LoadBalancer IP로 접속 | ☐ |

---

## 🔧 트러블슈팅

### 문제 1: ArgoCD Sync 실패 - "ImagePullBackOff"

**원인**: ECR 이미지 Pull 권한 없음

**해결**:
```bash
# IRSA 설정 또는 ImagePullSecret 확인
kubectl describe pod <POD_NAME> -n dev
```

### 문제 2: ArgoCD가 변경사항을 감지 못함

**원인**: 동기화 주기 또는 Webhook 미설정

**해결**:
```bash
# 수동 Sync
argocd app sync jenkins-cicd-demo-dev

# 또는 Webhook 설정 (ArgoCD UI → Settings → Repositories)
```

### 문제 3: "OutOfSync" 상태 지속

**원인**: 리소스 드리프트 또는 설정 오류

**해결**:
```bash
# 상세 차이점 확인
argocd app diff jenkins-cicd-demo-dev

# 강제 Sync
argocd app sync jenkins-cicd-demo-dev --force
```

---

## 💡 팁 & 베스트 프랙티스

### GitOps 디렉토리 구조 권장

```
config-repo/
├── apps/                  # 애플리케이션별 설정
│   ├── app1/
│   └── app2/
├── infrastructure/        # 클러스터 인프라 설정
│   ├── monitoring/
│   └── logging/
└── projects/              # ArgoCD 프로젝트 정의
```

### 보안 베스트 프랙티스

1. **Sealed Secrets** 또는 **External Secrets Operator** 사용
2. **RBAC** 기반 접근 제어
3. **이미지 서명** 및 **보안 스캔** 적용

### 롤백 방법

```bash
# Git Revert로 롤백
cd config-repo
git revert HEAD
git push origin main

# 또는 ArgoCD로 특정 리비전 배포
argocd app history jenkins-cicd-demo-dev
argocd app rollback jenkins-cicd-demo-dev <REVISION>
```

---

## 🧹 리소스 정리 (중요!)

학습 완료 후 반드시 리소스를 삭제하여 비용을 절약하세요.

```bash
# ArgoCD Application 삭제
argocd app delete jenkins-cicd-demo-dev

# EKS 클러스터 삭제 (가장 큰 비용)
eksctl delete cluster --name jenkins-cicd-eks --region ap-northeast-2

# ECR 이미지 삭제
aws ecr batch-delete-image \
    --repository-name jenkins-cicd-demo \
    --image-ids "$(aws ecr list-images --repository-name jenkins-cicd-demo --query 'imageIds[*]' --output json)"

# ECR 저장소 삭제
aws ecr delete-repository --repository-name jenkins-cicd-demo --force
```

---

## 📚 참고 자료

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://www.gitops.tech/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kustomize Documentation](https://kustomize.io/)

---

## 📅 학습 완료!

축하합니다! 🎉 Jenkins + AWS를 활용한 CI/CD 파이프라인 전체 과정을 완료했습니다.

### 학습 경로 요약

```
01. Jenkins EC2 설치
       ↓
02. GitHub Webhook 연동
       ↓
03. Jenkinsfile 작성
       ↓
04. Docker + ECR 빌드/푸시
       ↓
05. ECS Fargate 배포
       ↓
06. GitOps + ArgoCD (선택)
```

### 다음 학습 추천

- **Terraform으로 인프라 코드화**
- **GitHub Actions vs Jenkins 비교**
- **Kubernetes 심화 학습**
- **모니터링 (Prometheus + Grafana)**

---

> 📝 **작성일**: 2024년  
> 🔄 **최종 수정**: 2026년 11월 (AWS MCP 검증)  
> 👤 **작성자**: [Your Name]
