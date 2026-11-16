pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = '727477309869'
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
                echo "✅ 코드 체크아웃 완료"
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "🐳 Docker 이미지 빌드 중..."
                echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest"
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
                sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker push ${IMAGE_NAME}:latest"
            }
        }

        stage('Cleanup') {
            steps {
                echo "🧹 로컬 이미지 정리 중..."
                sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
                sh "docker rmi ${IMAGE_NAME}:latest || true"
            }
        }
    }

    post {
        success {
            echo "========================================"
            echo "✅ ECR 푸시 성공!"
            echo "📦 Image: ${IMAGE_NAME}:${IMAGE_TAG}"
            echo "========================================"
        }
        failure {
            echo "❌ 빌드 실패!"
        }
    }
}