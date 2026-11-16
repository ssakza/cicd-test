pipeline {
    agent any
    
    environment {
        APP_NAME = 'cicd-test'
        VERSION = '1.0.0'
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
            // Stage별 post 액션
            post {
                success {
                    echo "✅ Build 단계 성공!"
                }
                failure {
                    echo "❌ Build 단계 실패!"
                }
            }
        }
        
        stage('Test') {
            steps {
                echo "🧪 테스트 실행 중..."
                sh 'echo "테스트 통과!"'
            }
        }
        
        stage('Deploy') {
            steps {
                echo "🚀 배포 중..."
                echo "배포 완료!"
            }
        }
    }
    
    // 전체 파이프라인 post 액션
    post {
        success {
            echo "========================================"
            echo "✅ 파이프라인 전체 성공!"
            echo "앱: ${APP_NAME}"
            echo "버전: ${VERSION}"
            echo "빌드 번호: ${BUILD_NUMBER}"
            echo "========================================"
        }
        failure {
            echo "========================================"
            echo "❌ 파이프라인 실패!"
            echo "빌드 번호: ${BUILD_NUMBER}"
            echo "로그를 확인하세요."
            echo "========================================"
        }
        always {
            echo "📋 파이프라인 실행 완료 (성공/실패 무관)"
        }
    }
}