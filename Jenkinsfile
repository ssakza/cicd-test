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
