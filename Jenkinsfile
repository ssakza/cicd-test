pipeline {
    agent any
    
    environment {
        APP_NAME = 'cicd-test'
        VERSION = '1.0.0'
    }
    
    options {
        timeout(time: 30, unit: 'MINUTES')  // 전체 타임아웃
        disableConcurrentBuilds()            // 동시 빌드 방지
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
                sh 'echo "모든 테스트 통과!"'
            }
        }
        
        stage('Deploy') {
            steps {
                echo "🚀 배포 중..."
                echo "배포 완료!"
            }
        }
    }
    
    post {
        success {
            echo "========================================"
            echo "✅ 빌드 성공!"
            echo "앱: ${APP_NAME} v${VERSION}"
            echo "빌드: #${BUILD_NUMBER}"
            echo "========================================"
        }
        failure {
            echo "========================================"
            echo "❌ 빌드 실패!"
            echo "로그를 확인하세요: ${BUILD_URL}console"
            echo "========================================"
        }
        always {
            echo "📋 파이프라인 완료"
        }
    }
}