pipeline {
    agent any
    
    // 환경 변수 정의
    environment {
        APP_NAME = 'cicd-test'
        VERSION = '1.0.0'
        AUTHOR = 'My Name'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "✅ 코드 체크아웃 완료"
            }
        }
        
        stage('Print Info') {
            steps {
                echo "========== 빌드 정보 =========="
                echo "앱 이름: ${APP_NAME}"
                echo "버전: ${VERSION}"
                echo "작성자: ${AUTHOR}"
                echo "빌드 번호: ${BUILD_NUMBER}"
                echo "작업 이름: ${JOB_NAME}"
                echo "==============================="
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
    }
    
    post {
        success {
            echo "✅ ${APP_NAME} v${VERSION} 빌드 성공!"
        }
        failure {
            echo "❌ ${APP_NAME} v${VERSION} 빌드 실패!"
        }
    }
}