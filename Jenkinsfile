pipeline {
    agent any
    
    environment {
        APP_NAME = 'cicd-test'
        VERSION = '1.0.0'
        DEPLOY_ENV = 'dev'  // 배포 환경: dev, staging, prod
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "✅ 코드 체크아웃 완료"
            }
        }
        
        stage('Build') {
            steps {
                echo "🔨 ${APP_NAME} v${VERSION} 빌드 중..."
                sh 'ls -la'
            }
        }
        
        stage('Test') {
            steps {
                echo "🧪 테스트 실행 중..."
                sh 'echo "테스트 통과!"'
            }
        }
        
        stage('Deploy to Dev') {
            when {
                environment name: 'DEPLOY_ENV', value: 'dev'
            }
            steps {
                echo "🚀 개발 환경에 배포 중..."
                echo "개발 서버 배포 완료!"
            }
        }
        
        stage('Deploy to Staging') {
            when {
                environment name: 'DEPLOY_ENV', value: 'staging'
            }
            steps {
                echo "🚀 스테이징 환경에 배포 중..."
                echo "스테이징 서버 배포 완료!"
            }
        }
        
        stage('Deploy to Prod') {
            when {
                environment name: 'DEPLOY_ENV', value: 'prod'
            }
            steps {
                echo "🚀 운영 환경에 배포 중..."
                echo "운영 서버 배포 완료!"
            }
        }
    }
    
    post {
        success {
            echo "✅ 빌드 성공! 배포 환경: ${DEPLOY_ENV}"
        }
        failure {
            echo "❌ 빌드 실패!"
        }
    }
}