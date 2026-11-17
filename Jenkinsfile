pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = '727477309869'
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
                echo "📤 ECR로 이미지 푸시 중..."
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                """
            }
        }

        stage('Deploy to ECS') {
            steps {
                echo "🚀 ECS 배포 중..."
                sh """
                    # 새 Task Definition 등록 (이미지 태그 업데이트)
                    TASK_DEF=\$(aws ecs describe-task-definition --task-definition ${TASK_FAMILY} --region ${AWS_REGION})
                    
                    NEW_TASK_DEF=\$(echo \$TASK_DEF | jq --arg IMAGE "${IMAGE_NAME}:${IMAGE_TAG}" '.taskDefinition | .containerDefinitions[0].image = \$IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')
                    
                    aws ecs register-task-definition --cli-input-json "\$NEW_TASK_DEF" --region ${AWS_REGION}
                    
                    # ECS Service 업데이트
                    aws ecs update-service \\
                        --cluster ${ECS_CLUSTER} \\
                        --service ${ECS_SERVICE} \\
                        --task-definition ${TASK_FAMILY} \\
                        --force-new-deployment \\
                        --region ${AWS_REGION}
                """
            }
        }

        stage('Wait for Deployment') {
            steps {
                echo "⏳ 배포 완료 대기 중 (최대 5분)..."
                sh """
                    aws ecs wait services-stable \\
                        --cluster ${ECS_CLUSTER} \\
                        --services ${ECS_SERVICE} \\
                        --region ${AWS_REGION}
                """
                echo "✅ 배포 완료!"
            }
        }
    }

    post {
        success {
            echo """
            ========================================
            ✅ 배포 성공!
            📦 Image: ${IMAGE_NAME}:${IMAGE_TAG}
            🌐 Cluster: ${ECS_CLUSTER}
            🚀 Service: ${ECS_SERVICE}
            ========================================
            """
        }
        failure {
            echo "❌ 배포 실패! 로그를 확인하세요."
        }
        always {
            sh """
                docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true
                docker rmi ${IMAGE_NAME}:latest || true
            """
        }
    }
}