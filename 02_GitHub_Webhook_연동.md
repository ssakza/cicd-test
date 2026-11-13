# GitHub Webhook 연동

## 🤔 Webhook이란?

### Webhook 정의

**Webhook**은 특정 이벤트가 발생했을 때 다른 시스템에 자동으로 알림을 보내는 방식입니다.

쉽게 말해, **"뭔가 일어나면 나한테 알려줘"** 입니다.

```
[비유: 택배 알림]

일반 방식 (Polling):
나: 택배 왔나? → 택배함 확인 → 없음
나: 택배 왔나? → 택배함 확인 → 없음  (반복...)
나: 택배 왔나? → 택배함 확인 → 있음!

Webhook 방식:
택배 도착 → 알림 발송 → 나: 확인!
```

### GitHub Webhook의 동작

| 이벤트 | GitHub 동작 | Jenkins 반응 |
|--------|-------------|--------------|
| Push | "코드가 푸시됐어!" → Jenkins에 알림 | 자동 빌드 시작 |
| Pull Request | "PR이 생성됐어!" → Jenkins에 알림 | PR 브랜치 빌드 |
| Tag | "태그가 생성됐어!" → Jenkins에 알림 | 릴리스 빌드 |

### 왜 Webhook이 필요한가?

**Webhook 없이 (Polling 방식):**
```
Jenkins: GitHub 바뀌었나? (매 1분마다 확인)
GitHub: 아니요
Jenkins: 바뀌었나?
GitHub: 아니요
... (100번 반복) ...
Jenkins: 바뀌었나?
GitHub: 네!
Jenkins: 빌드 시작! (하지만 이미 1분 지연)
```

**Webhook 사용 시:**
```
[개발자가 Push]
GitHub: Jenkins야, 코드 바뀌었어!
Jenkins: 알겠어, 바로 빌드 시작!
```

### 이 실습의 목적

**GitHub과 Jenkins를 연결**하면:
- 코드 푸시 → 자동 빌드가 가능해집니다
- 수동으로 Jenkins에서 "빌드 시작"을 누를 필요가 없습니다
- 진정한 CI(지속적 통합)의 시작점입니다

### 실습 후 기대 효과

```
[실습 전]
개발자: git push
개발자: Jenkins 접속
개발자: Build Now 클릭
개발자: 결과 대기...

[실습 후]
개발자: git push
(끝. 알아서 빌드되고 결과 알림 옴)
```

---

## 📋 개요

| 항목 | 내용 |
|------|------|
| 목적 | GitHub 저장소와 Jenkins를 연동하여 코드 푸시 시 자동 빌드 트리거 |
| 선행 조건 | Jenkins 서버 설치 완료 (01장 참고) |
| 예상 소요 시간 | 30분 ~ 1시간 |
| 난이도 | ★★☆☆☆ (초급~중급) |

---

## 🎯 학습 목표

- [ ] GitHub Personal Access Token 생성
- [ ] Jenkins에 GitHub 자격 증명 등록
- [ ] GitHub Webhook 설정
- [ ] 자동 빌드 트리거 테스트

---

## 🏗️ 아키텍처

```
+------------+                              +------------+
|            |   Webhook (Push Event)       |            |
|   GitHub   | ---------------------------> |  Jenkins   |
|            |                              |   (EC2)    |
|            | <--------------------------- |            |
+------------+   Build Status Update        +------------+

[Flow]
1. Developer pushes code
2. GitHub sends webhook to Jenkins
3. Jenkins triggers build
4. Jenkins updates commit status
```

---

## 📝 실습 단계

### Step 1: GitHub Personal Access Token 생성

#### 1-1. GitHub 설정 페이지 이동

1. GitHub 로그인
2. 우측 상단 프로필 아이콘 클릭
3. `Settings` → `Developer settings` → `Personal access tokens` → `Tokens (classic)`

#### 1-2. 새 토큰 생성

1. **Generate new token (classic)** 클릭
2. 토큰 정보 입력:

| 항목 | 값 |
|------|-----|
| Note | jenkins-integration |
| Expiration | 90 days (또는 필요에 따라) |

3. 권한(Scopes) 선택:

| Scope | 설명 | 필수 |
|-------|------|------|
| `repo` | 전체 저장소 접근 | ✅ |
| `admin:repo_hook` | Webhook 관리 | ✅ |
| `admin:org_hook` | 조직 Webhook (필요시) | ☐ |

4. **Generate token** 클릭
5. ⚠️ **토큰을 안전한 곳에 복사해두세요!** (다시 볼 수 없음)

---

### Step 2: Jenkins에 자격 증명 등록

#### 2-1. Jenkins Credentials 페이지 이동

`Dashboard` → `Manage Jenkins` → `Credentials` → `System` → `Global credentials`

#### 2-2. GitHub Token 등록

1. **Add Credentials** 클릭
2. 설정값 입력:

| 항목 | 값 |
|------|-----|
| Kind | Secret text |
| Scope | Global |
| Secret | (GitHub Personal Access Token 붙여넣기) |
| ID | github-token |
| Description | GitHub Personal Access Token |

3. **Create** 클릭

#### 2-3. GitHub 계정 정보 등록 (Username/Password 방식)

1. **Add Credentials** 다시 클릭
2. 설정값 입력:

| 항목 | 값 |
|------|-----|
| Kind | Username with password |
| Scope | Global |
| Username | (GitHub 사용자명) |
| Password | (GitHub Personal Access Token) |
| ID | github-credentials |
| Description | GitHub Username and Token |

3. **Create** 클릭

---

### Step 3: Jenkins GitHub 서버 설정

#### 3-1. GitHub 서버 구성

`Dashboard` → `Manage Jenkins` → `System` → **GitHub** 섹션으로 스크롤

#### 3-2. GitHub Server 추가

1. **Add GitHub Server** → **GitHub Server** 클릭
2. 설정값 입력:

| 항목 | 값 |
|------|-----|
| Name | GitHub |
| API URL | https://api.github.com |
| Credentials | github-token (Secret text) |

3. **Test connection** 클릭 → "Credentials verified" 확인
4. ☑️ **Manage hooks** 체크
5. 페이지 하단 **Save** 클릭

---

### Step 4: 테스트용 GitHub 저장소 생성

#### 4-1. 새 저장소 생성

1. GitHub에서 **New repository** 클릭
2. 설정:

| 항목 | 값 |
|------|-----|
| Repository name | jenkins-cicd-demo |
| Visibility | Public (또는 Private) |
| Initialize | ☑️ Add a README file |

3. **Create repository** 클릭

#### 4-2. 샘플 프로젝트 파일 추가

저장소에 아래 파일들을 추가합니다.

**`Jenkinsfile`** (저장소 루트에 생성)

```groovy
pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "✅ 코드 체크아웃 완료"
            }
        }
        
        stage('Build') {
            steps {
                echo "🔨 빌드 단계 실행 중..."
                sh 'echo "Hello from Jenkins!"'
                sh 'ls -la'
            }
        }
        
        stage('Test') {
            steps {
                echo "🧪 테스트 단계 실행 중..."
                sh 'echo "테스트 통과!"'
            }
        }
        
        stage('Deploy') {
            steps {
                echo "🚀 배포 단계 (현재는 스킵)"
                echo "배포 준비 완료!"
            }
        }
    }
    
    post {
        success {
            echo "✅ 파이프라인 성공!"
        }
        failure {
            echo "❌ 파이프라인 실패!"
        }
        always {
            echo "📋 파이프라인 실행 완료"
        }
    }
}
```

---

### Step 5: Jenkins Pipeline Job 생성

#### 5-1. 새 Item 생성

1. `Dashboard` → **New Item** 클릭
2. 설정:

| 항목 | 값 |
|------|-----|
| Enter an item name | jenkins-cicd-demo |
| Type | Pipeline |

3. **OK** 클릭

#### 5-2. 일반 설정

| 항목 | 설정 |
|------|------|
| ☑️ GitHub project | Project url: `https://github.com/<username>/jenkins-cicd-demo` |

#### 5-3. Build Triggers 설정

| 항목 | 설정 |
|------|------|
| ☑️ GitHub hook trigger for GITScm polling | 체크 |

#### 5-4. Pipeline 설정

| 항목 | 값 |
|------|-----|
| Definition | Pipeline script from SCM |
| SCM | Git |
| Repository URL | `https://github.com/<username>/jenkins-cicd-demo.git` |
| Credentials | github-credentials |
| Branch Specifier | `*/main` |
| Script Path | Jenkinsfile |

5. **Save** 클릭

---

### Step 6: GitHub Webhook 수동 설정 (자동 생성 실패 시)

#### 6-1. GitHub 저장소 Webhook 설정

1. GitHub 저장소 → `Settings` → `Webhooks` → **Add webhook**
2. 설정값:

| 항목 | 값 |
|------|-----|
| Payload URL | `http://<Jenkins-EC2-IP>:8080/github-webhook/` |
| Content type | application/json |
| Secret | (비워두거나 설정) |
| Events | ☑️ Just the push event |
| Active | ☑️ |

3. **Add webhook** 클릭

#### 6-2. Webhook 테스트

- Webhook 목록에서 방금 생성한 항목 클릭
- **Recent Deliveries** 탭에서 ping 이벤트 확인
- ✅ 녹색 체크마크가 보이면 성공

---

### Step 7: 자동 빌드 테스트

#### 7-1. 코드 수정 및 푸시

```bash
# 로컬에서 저장소 클론
git clone https://github.com/<username>/jenkins-cicd-demo.git
cd jenkins-cicd-demo

# 파일 수정
echo "# Updated at $(date)" >> README.md

# 커밋 및 푸시
git add .
git commit -m "Test automatic build trigger"
git push origin main
```

#### 7-2. Jenkins 빌드 확인

1. Jenkins Dashboard → `jenkins-cicd-demo` Job 클릭
2. 새로운 빌드가 자동으로 시작되는지 확인
3. 빌드 번호 클릭 → **Console Output**에서 로그 확인

---

## ✅ 검증 체크리스트

| 항목 | 확인 방법 | 완료 |
|------|----------|------|
| GitHub Token 생성됨 | GitHub Settings에서 확인 | ☐ |
| Jenkins Credentials 등록됨 | Manage Jenkins → Credentials | ☐ |
| GitHub 연결 테스트 성공 | System → GitHub → Test connection | ☐ |
| Webhook 등록됨 | GitHub 저장소 Settings → Webhooks | ☐ |
| 자동 빌드 트리거 작동 | Push 후 Jenkins 빌드 시작 | ☐ |

---

## 🔧 트러블슈팅

### 문제 1: Webhook 전송 실패 (Status 403 또는 Connection refused)

**원인**: Jenkins 서버가 외부에서 접근 불가

**해결**:
```
1. EC2 보안 그룹에서 8080 포트가 0.0.0.0/0 (또는 GitHub IP 대역)에 열려있는지 확인
2. GitHub Webhook IP 대역: https://api.github.com/meta 에서 hooks 확인
```

> ⚠️ 학습 목적으로 임시로 0.0.0.0/0을 열 수 있지만, 실습 후 반드시 제한하세요.

### 문제 2: Webhook은 성공하지만 빌드가 시작 안 됨

**원인**: Branch 이름 불일치 또는 Trigger 설정 누락

**해결**:
```
1. Job 설정에서 "GitHub hook trigger for GITScm polling" 체크 확인
2. Branch Specifier가 실제 브랜치 이름과 일치하는지 확인 (main vs master)
```

### 문제 3: Credentials 인증 실패

**원인**: Token 권한 부족 또는 만료

**해결**:
```
1. GitHub에서 Token의 권한(repo, admin:repo_hook) 확인
2. Token 만료 여부 확인
3. 새 Token 생성 후 Jenkins Credentials 업데이트
```

### 문제 4: "Crumb" 또는 CSRF 오류

**원인**: Jenkins CSRF 보호 설정

**해결**:
```
Manage Jenkins → Security → CSRF Protection
→ "Enable proxy compatibility" 체크
→ Save 후 Webhook 재시도
```

---

## 💡 팁 & 베스트 프랙티스

### Webhook 보안 강화

```
1. Webhook Secret 설정으로 요청 검증
2. Jenkins에서 GitHub plugin이 Secret 검증하도록 구성
3. HTTPS 사용 (Let's Encrypt + Nginx reverse proxy)
```

### 다중 브랜치 파이프라인

**Multibranch Pipeline**을 사용하면:
- 모든 브랜치를 자동 감지
- PR 빌드 자동 실행
- 브랜치별 독립적인 빌드 이력

### GitHub Actions와의 비교

| 항목 | Jenkins + Webhook | GitHub Actions |
|------|-------------------|----------------|
| 인프라 | 직접 관리 | GitHub 관리형 |
| 비용 | EC2 비용 | 무료 티어 있음 |
| 유연성 | 매우 높음 | 제한적 |
| 학습 가치 | CI/CD 전체 이해 | GitHub 생태계 학습 |

---

## 📚 참고 자료

- [Jenkins GitHub Plugin 문서](https://plugins.jenkins.io/github/)
- [GitHub Webhooks 문서](https://docs.github.com/en/webhooks)
- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

---

## 📅 다음 단계

**[03. Jenkinsfile 작성 (Pipeline as Code)](./03_Jenkinsfile_작성_Pipeline_as_Code.md)** 에서 실제 애플리케이션 빌드/테스트를 위한 Jenkinsfile을 작성합니다.

---

> 📝 **작성일**: 2024년  
> 🔄 **최종 수정**: 2026년 11월 (AWS MCP 검증)  
> 👤 **작성자**: [Your Name]
