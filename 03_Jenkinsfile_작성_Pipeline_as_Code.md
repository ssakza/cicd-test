# Jenkinsfile 작성 (Pipeline as Code)

## 🤔 Pipeline as Code란?

### 정의

**Pipeline as Code**는 CI/CD 파이프라인을 **코드 파일로 정의**하는 방식입니다.

Jenkins에서는 이 파일을 **Jenkinsfile**이라고 부릅니다.

### 왜 코드로 관리하는가?

**UI로 설정할 때 (전통 방식):**
```
문제점:
- "어? 누가 빌드 설정 바꿨어?" → 추적 불가
- "다른 프로젝트에도 같은 설정 적용해줘" → 수동으로 다시 클릭
- "지난주 설정으로 되돌려줘" → 백업 없으면 불가능
```

**Jenkinsfile로 관리할 때:**
```
장점:
- Git에 저장 → 누가, 언제, 왜 바꿨는지 추적 가능
- 다른 프로젝트에 복사 → 동일한 파이프라인 재사용
- git revert → 이전 설정으로 롤백
- 코드 리뷰 → 파이프라인 변경도 리뷰 가능
```

### Jenkinsfile 예시 (쉬운 버전)

```groovy
pipeline {
    agent any                    // 어디서 실행할지 (아무 서버나)
    
    stages {
        stage('Build') {         // 1단계: 빌드
            steps {
                echo '빌드 중...'
                sh 'npm install'
            }
        }
        stage('Test') {          // 2단계: 테스트
            steps {
                echo '테스트 중...'
                sh 'npm test'
            }
        }
        stage('Deploy') {        // 3단계: 배포
            steps {
                echo '배포 중...'
            }
        }
    }
}
```

### 이 실습의 목적

**Jenkinsfile 작성법을 배우면:**
- 파이프라인을 소스코드처럼 관리할 수 있습니다
- 복잡한 빌드/테스트/배포 과정을 정의할 수 있습니다
- 조건부 실행, 병렬 처리 등 고급 기능을 사용할 수 있습니다

### 실습 후 기대 효과

| 상황 | 전통 방식 | Jenkinsfile |
|------|----------|-------------|
| 파이프라인 수정 | Jenkins UI 접속 → 설정 변경 | 코드 수정 → git push |
| 변경 이력 확인 | ??? | git log |
| 다른 프로젝트 적용 | 처음부터 다시 클릭 | 파일 복사 |
| 롤백 | 기억에 의존 | git revert |

---

## 📋 개요

| 항목 | 내용 |
|------|------|
| 목적 | Jenkinsfile을 활용한 선언적 파이프라인 작성 방법 학습 |
| 선행 조건 | Jenkins 설치 및 GitHub 연동 완료 (01~02장 참고) |
| 예상 소요 시간 | 2~3시간 |
| 난이도 | ★★★☆☆ (중급) |

---

## 🎯 학습 목표

- [ ] Jenkinsfile 기본 문법 이해
- [ ] 선언적(Declarative) vs 스크립트(Scripted) 파이프라인 차이 이해
- [ ] 다양한 Stage 및 Step 구성
- [ ] 환경 변수, 조건부 실행, 병렬 처리 구현
- [ ] Post 액션 및 알림 설정

---

## 🏗️ 파이프라인 흐름

```
+----------+   +----------+   +----------+   +----------+   +----------+
| Checkout |-->|  Build   |-->|   Test   |-->|   Scan   |-->|  Deploy  |
+----------+   +----------+   +----------+   +----------+   +----------+
     |              |              |              |              |
     v              v              v              v              v
 Git Clone      Compile        Unit Test     Security       Push to
               Package        Integration    Quality       ECR/ECS
                                             Analysis
```

---

## 📝 Jenkinsfile 기본 구조

### 선언적 파이프라인 (Declarative Pipeline)

```groovy
pipeline {
    agent any                          // 실행 환경

    environment {                      // 환경 변수
        APP_NAME = 'my-application'
    }

    options {                          // 파이프라인 옵션
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {                           // 단계 정의
        stage('Stage Name') {
            steps {
                // 실행할 명령
            }
        }
    }

    post {                             // 후처리 액션
        always {
            // 항상 실행
        }
        success {
            // 성공 시 실행
        }
        failure {
            // 실패 시 실행
        }
    }
}
```

---

## 📝 실습 단계

### Step 1: 기본 Jenkinsfile 작성

#### 1-1. 최소 구조

```groovy
pipeline {
    agent any

    stages {
        stage('Hello') {
            steps {
                echo 'Hello, Jenkins Pipeline!'
            }
        }
    }
}
```

#### 1-2. GitHub 저장소에 Jenkinsfile 추가

1. 이전에 생성한 `jenkins-cicd-demo` 저장소 열기
2. 루트 경로에 `Jenkinsfile` 파일 생성 (또는 기존 파일 수정)

---

### Step 2: 실제 애플리케이션 빌드 파이프라인

#### 2-1. Node.js 애플리케이션용 Jenkinsfile

```groovy
pipeline {
    agent any

    tools {
        nodejs 'NodeJS-18'  // Jenkins에서 설정한 Node.js 이름
    }

    environment {
        APP_NAME = 'nodejs-demo-app'
        BUILD_NUMBER_ENV = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "📥 코드 체크아웃 완료"
                sh 'ls -la'
            }
        }

        stage('Install Dependencies') {
            steps {
                echo "📦 의존성 설치 중..."
                sh 'npm ci'  // package-lock.json 기반 설치
            }
        }

        stage('Lint') {
            steps {
                echo "🔍 코드 린트 검사 중..."
                sh 'npm run lint || true'  // 린트 실패해도 계속 진행
            }
        }

        stage('Test') {
            steps {
                echo "🧪 테스트 실행 중..."
                sh 'npm test'
            }
            post {
                always {
                    // JUnit 테스트 리포트 수집 (있는 경우)
                    junit allowEmptyResults: true, testResults: '**/test-results/*.xml'
                }
            }
        }

        stage('Build') {
            steps {
                echo "🔨 애플리케이션 빌드 중..."
                sh 'npm run build'
            }
        }

        stage('Archive Artifacts') {
            steps {
                echo "📁 아티팩트 저장 중..."
                archiveArtifacts artifacts: 'dist/**/*', fingerprint: true
            }
        }
    }

    post {
        success {
            echo "✅ 빌드 성공! Build #${BUILD_NUMBER}"
        }
        failure {
            echo "❌ 빌드 실패! Build #${BUILD_NUMBER}"
        }
        always {
            echo "🧹 워크스페이스 정리 중..."
            cleanWs()
        }
    }
}
```

#### 2-2. Spring Boot (Java) 애플리케이션용 Jenkinsfile

```groovy
pipeline {
    agent any

    tools {
        jdk 'JDK-17'
        maven 'Maven-3.9'
    }

    environment {
        APP_NAME = 'spring-boot-demo'
        JAVA_HOME = tool('JDK-17')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "📥 코드 체크아웃 완료"
            }
        }

        stage('Build') {
            steps {
                echo "🔨 Maven 빌드 중..."
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Unit Test') {
            steps {
                echo "🧪 단위 테스트 실행 중..."
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Integration Test') {
            steps {
                echo "🔗 통합 테스트 실행 중..."
                sh 'mvn verify -DskipUnitTests'
            }
        }

        stage('Code Quality') {
            steps {
                echo "📊 코드 품질 분석 중..."
                // SonarQube 연동 시
                // withSonarQubeEnv('SonarQube') {
                //     sh 'mvn sonar:sonar'
                // }
                sh 'mvn checkstyle:check || true'
            }
        }

        stage('Package') {
            steps {
                echo "📦 JAR 패키징..."
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }
    }

    post {
        success {
            echo "✅ 빌드 성공!"
        }
        failure {
            echo "❌ 빌드 실패!"
        }
    }
}
```

---

### Step 3: 고급 파이프라인 기법

#### 3-1. 환경별 배포 (Multi-Environment)

```groovy
pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: '배포할 환경을 선택하세요'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: '테스트 스킵 여부'
        )
    }

    environment {
        APP_NAME = 'multi-env-app'
        // 환경별 설정
        DEV_URL = 'dev.example.com'
        STAGING_URL = 'staging.example.com'
        PROD_URL = 'www.example.com'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo "🔨 Building for ${params.ENVIRONMENT} environment"
                sh 'npm ci && npm run build'
            }
        }

        stage('Test') {
            when {
                expression { return !params.SKIP_TESTS }
            }
            steps {
                echo "🧪 Running tests..."
                sh 'npm test'
            }
        }

        stage('Deploy to Dev') {
            when {
                expression { params.ENVIRONMENT == 'dev' }
            }
            steps {
                echo "🚀 Deploying to Development: ${DEV_URL}"
                // 배포 스크립트
            }
        }

        stage('Deploy to Staging') {
            when {
                expression { params.ENVIRONMENT == 'staging' }
            }
            steps {
                echo "🚀 Deploying to Staging: ${STAGING_URL}"
                // 승인 없이 배포
            }
        }

        stage('Approval') {
            when {
                expression { params.ENVIRONMENT == 'prod' }
            }
            steps {
                script {
                    input message: '프로덕션 배포를 승인하시겠습니까?',
                          ok: '배포 승인',
                          submitter: 'admin,devops'
                }
            }
        }

        stage('Deploy to Production') {
            when {
                expression { params.ENVIRONMENT == 'prod' }
            }
            steps {
                echo "🚀 Deploying to Production: ${PROD_URL}"
                // 프로덕션 배포 스크립트
            }
        }
    }
}
```

#### 3-2. 병렬 실행 (Parallel Execution)

```groovy
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                echo "🔨 Building application..."
            }
        }

        stage('Parallel Tests') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        echo "🧪 Running unit tests..."
                        sh 'npm run test:unit'
                    }
                }
                stage('Integration Tests') {
                    steps {
                        echo "🔗 Running integration tests..."
                        sh 'npm run test:integration'
                    }
                }
                stage('E2E Tests') {
                    steps {
                        echo "🌐 Running E2E tests..."
                        sh 'npm run test:e2e'
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                echo "🚀 Deploying..."
            }
        }
    }
}
```

#### 3-3. 조건부 실행 (when 지시어)

```groovy
pipeline {
    agent any

    stages {
        stage('Build Feature Branch') {
            when {
                branch 'feature/*'
            }
            steps {
                echo "🔨 Building feature branch: ${BRANCH_NAME}"
            }
        }

        stage('Build Main Branch') {
            when {
                branch 'main'
            }
            steps {
                echo "🔨 Building main branch"
            }
        }

        stage('Deploy on Tag') {
            when {
                tag pattern: "v\\d+\\.\\d+\\.\\d+", comparator: "REGEXP"
            }
            steps {
                echo "🏷️ Deploying tagged version: ${TAG_NAME}"
            }
        }

        stage('Weekend Build') {
            when {
                expression {
                    def today = new Date()
                    return today[Calendar.DAY_OF_WEEK] in [Calendar.SATURDAY, Calendar.SUNDAY]
                }
            }
            steps {
                echo "📅 Weekend build - running extended tests"
            }
        }
    }
}
```

---

### Step 4: 자격 증명 및 보안

#### 4-1. Credentials 사용하기

```groovy
pipeline {
    agent any

    environment {
        // Jenkins Credentials에서 가져오기
        AWS_CREDENTIALS = credentials('aws-credentials')
        DOCKER_CREDENTIALS = credentials('docker-hub-credentials')
        // Secret text
        API_KEY = credentials('api-key-secret')
    }

    stages {
        stage('Use Credentials') {
            steps {
                // Username/Password 타입
                sh '''
                    echo "AWS Access Key: ${AWS_CREDENTIALS_USR}"
                    # AWS_CREDENTIALS_PSW 는 로그에 마스킹됨
                '''
                
                // withCredentials 블록 사용
                withCredentials([
                    usernamePassword(
                        credentialsId: 'github-credentials',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_TOKEN'
                    )
                ]) {
                    sh 'git clone https://${GIT_USER}:${GIT_TOKEN}@github.com/org/repo.git'
                }
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-hub-credentials',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh 'echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER} --password-stdin'
                }
            }
        }
    }
}
```

---

### Step 5: 에러 처리 및 재시도

#### 5-1. try-catch 및 retry

```groovy
pipeline {
    agent any

    stages {
        stage('Flaky Test') {
            steps {
                retry(3) {
                    echo "Attempting flaky operation..."
                    sh 'exit $((RANDOM % 2))'  // 랜덤 실패
                }
            }
        }

        stage('With Timeout') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    sh 'npm run long-running-task'
                }
            }
        }

        stage('Error Handling') {
            steps {
                script {
                    try {
                        sh 'command-that-might-fail'
                    } catch (Exception e) {
                        echo "Command failed: ${e.message}"
                        // 실패해도 계속 진행
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }
}
```

---

### Step 6: 알림 설정

#### 6-1. Slack 알림

```groovy
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                echo "Building..."
            }
        }
    }

    post {
        success {
            slackSend(
                channel: '#ci-cd-alerts',
                color: 'good',
                message: "✅ *빌드 성공*\nJob: ${JOB_NAME}\nBuild: #${BUILD_NUMBER}\n<${BUILD_URL}|상세 보기>"
            )
        }
        failure {
            slackSend(
                channel: '#ci-cd-alerts',
                color: 'danger',
                message: "❌ *빌드 실패*\nJob: ${JOB_NAME}\nBuild: #${BUILD_NUMBER}\n<${BUILD_URL}|상세 보기>"
            )
        }
    }
}
```

#### 6-2. 이메일 알림

```groovy
post {
    failure {
        emailext(
            subject: "Jenkins Build Failed: ${JOB_NAME} #${BUILD_NUMBER}",
            body: """
                <h2>빌드 실패 알림</h2>
                <p>Job: ${JOB_NAME}</p>
                <p>Build Number: ${BUILD_NUMBER}</p>
                <p>Build URL: <a href="${BUILD_URL}">${BUILD_URL}</a></p>
                <p>Console Output: <a href="${BUILD_URL}console">${BUILD_URL}console</a></p>
            """,
            mimeType: 'text/html',
            to: 'dev-team@example.com',
            recipientProviders: [requestor(), developers()]
        )
    }
}
```

---

## ✅ 검증 체크리스트

| 항목 | 확인 방법 | 완료 |
|------|----------|------|
| 기본 파이프라인 실행 | Jenkins에서 빌드 성공 | ☐ |
| 여러 Stage 순차 실행 | Console Output에서 확인 | ☐ |
| 병렬 실행 동작 | Stage 뷰에서 병렬 표시 확인 | ☐ |
| 조건부 실행 (when) | 조건에 따라 스킵되는지 확인 | ☐ |
| Credentials 마스킹 | 로그에서 비밀번호 숨김 확인 | ☐ |
| Post 액션 실행 | 성공/실패 시 후처리 확인 | ☐ |

---

## 🔧 트러블슈팅

### 문제 1: "No such DSL method" 오류

**원인**: 필요한 플러그인 미설치

**해결**:
```
Manage Jenkins → Plugins → Available
→ 해당 기능 플러그인 검색 및 설치
예: Pipeline: AWS Steps, Slack Notification 등
```

### 문제 2: "Scripts not permitted to use method" 오류

**원인**: Script Security 제한

**해결**:
```
Manage Jenkins → Script Approval
→ 대기 중인 스크립트 승인
```

### 문제 3: 환경 변수가 null로 나옴

**원인**: 잘못된 문법 또는 스코프 문제

**해결**:
```groovy
// 잘못된 예
environment {
    MY_VAR = "${OTHER_VAR}"  // OTHER_VAR가 아직 정의 안됨
}

// 올바른 예
environment {
    OTHER_VAR = 'value'
    MY_VAR = "${OTHER_VAR}"
}
```

---

## 💡 팁 & 베스트 프랙티스

### Jenkinsfile 작성 원칙

1. **버전 관리**: Jenkinsfile은 항상 Git에 저장
2. **재사용**: 공통 로직은 Shared Library로 분리
3. **환경 분리**: 환경별 설정은 환경 변수로 관리
4. **비밀 관리**: 절대 코드에 비밀값 하드코딩 금지
5. **빠른 실패**: 중요한 검증은 앞 단계에 배치

### 디버깅 팁

```groovy
stage('Debug') {
    steps {
        // 환경 변수 전체 출력
        sh 'printenv | sort'
        
        // 현재 디렉토리 구조
        sh 'pwd && ls -la'
        
        // Jenkins 빌드 정보
        echo "WORKSPACE: ${WORKSPACE}"
        echo "BUILD_NUMBER: ${BUILD_NUMBER}"
        echo "JOB_NAME: ${JOB_NAME}"
    }
}
```

---

## 📚 참고 자료

- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/)
- [Jenkins Shared Libraries](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)

---

## 📅 다음 단계

**[04. Docker 이미지 빌드 및 ECR 푸시](./04_Docker_ECR_빌드_푸시.md)** 에서 Jenkins 파이프라인에 Docker 빌드와 AWS ECR 푸시를 추가합니다.

---

> 📝 **작성일**: 2024년  
> 🔄 **최종 수정**: 2026년 11월 (AWS MCP 검증)  
> 👤 **작성자**: [Your Name]
