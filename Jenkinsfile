pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = '727477309869'
        AWS_REGION = 'ap-northeast-2'
        ECR_REPO_NAME = 'jenkins-cicd-demo'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPO_NAME}"
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // Config Repository
        CONFIG_REPO_URL = 'https://github.com/ssakza/jenkins-cicd-config.git'
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
                
                // Git Credential을 사용한 안전한 클론
                dir('config-repo') {
                    deleteDir()
                }
                
                withCredentials([usernamePassword(
                    credentialsId: 'github-credentials',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    // Jenkins의 checkout step 사용 - 가장 안전한 방법
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: '*/main']],
                        userRemoteConfigs: [[
                            url: "${CONFIG_REPO_URL}",
                            credentialsId: 'github-credentials'
                        ]],
                        extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'config-repo']]
                    ])
                    
                    dir('config-repo') {
                        sh """
                            # 이미지 태그 업데이트
                            sed -i 's/newTag: .*/newTag: "${IMAGE_TAG}"/' overlays/dev/kustomization.yaml
                            
                            # Git 설정
                            git config user.email "jenkins@example.com"
                            git config user.name "Jenkins CI"
                            
                            # 변경사항 확인 및 커밋
                            git add .
                            git diff --cached --quiet || git commit -m "Update image tag to ${IMAGE_TAG}"
                        """
                        
                        // Push - credential helper 사용
                        withCredentials([usernamePassword(
                            credentialsId: 'github-credentials',
                            usernameVariable: 'GIT_USER',
                            passwordVariable: 'GIT_TOKEN'
                        )]) {
                            sh '''
                                # Credential helper 설정 후 push
                                git config credential.helper '!f() { echo "username=${GIT_USER}"; echo "password=${GIT_TOKEN}"; }; f'
                                git push origin HEAD:main
                            '''
                        }
                    }
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
