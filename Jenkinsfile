pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = '727477309869'
        AWS_REGION = 'ap-northeast-2'
        ECR_REPO_NAME = 'jenkins-cicd-demo'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPO_NAME}"
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // Config Repository (본인 GitHub 사용자명으로 변경!)
        CONFIG_REPO = 'github.com/ssakza/jenkins-cicd-config.git'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "📥 코드 체크아웃 완료"
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

        stage('Push to ECR') {
            steps {
                echo "📤 ECR에 이미지 푸시 중..."
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
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
                        # Config 저장소 클론 (credential helper 사용)
                        rm -rf config-repo
                        
                        # GIT_ASKPASS를 사용하여 토큰의 특수문자 문제 회피
                        export GIT_ASKPASS_SCRIPT=\$(mktemp)
                        echo '#!/bin/bash' > \$GIT_ASKPASS_SCRIPT
                        echo 'echo \$GIT_TOKEN' >> \$GIT_ASKPASS_SCRIPT
                        chmod +x \$GIT_ASKPASS_SCRIPT
                        
                        GIT_ASKPASS=\$GIT_ASKPASS_SCRIPT git clone https://${GIT_USER}@github.com/ssakza/jenkins-cicd-config.git config-repo
                        rm -f \$GIT_ASKPASS_SCRIPT
                        
                        cd config-repo
                        
                        # 이미지 태그 업데이트
                        sed -i 's/newTag: .*/newTag: "${IMAGE_TAG}"/' overlays/dev/kustomization.yaml
                        
                        # 변경사항 커밋 및 푸시
                        git config user.email "jenkins@example.com"
                        git config user.name "Jenkins CI"
                        git add .
                        git diff --cached --quiet || git commit -m "Update image tag to ${IMAGE_TAG}"
                        
                        # Push도 GIT_ASKPASS 사용
                        export GIT_ASKPASS_SCRIPT=\$(mktemp)
                        echo '#!/bin/bash' > \$GIT_ASKPASS_SCRIPT
                        echo 'echo \$GIT_TOKEN' >> \$GIT_ASKPASS_SCRIPT
                        chmod +x \$GIT_ASKPASS_SCRIPT
                        GIT_ASKPASS=\$GIT_ASKPASS_SCRIPT git push origin main
                        rm -f \$GIT_ASKPASS_SCRIPT
                    """
                }
                echo "✅ Config Repository 업데이트 완료!"
                echo "🔄 ArgoCD가 자동으로 배포를 시작합니다."
            }
        }
    }

    post {
        success {
            echo """
            ========================================
            ✅ CI 완료!
            📦 Image: ${IMAGE_NAME}:${IMAGE_TAG}
            📝 Config Repo 업데이트됨
            🔄 ArgoCD가 자동 배포 중...
            ========================================
            """
        }
        failure {
            echo "❌ CI 실패! 로그를 확인하세요."
        }
        always {
            sh """
                docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true
                docker rmi ${IMAGE_NAME}:latest || true
                rm -rf config-repo || true
            """
        }
    }
}