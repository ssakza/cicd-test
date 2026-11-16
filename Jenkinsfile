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
                echo "🔨 빌드 중..."
                sh 'ls -la'
            }
        }
        
        stage('Test - May Fail') {
            steps {
                echo "🧪 테스트 실행 중..."
                // catchError: 에러가 나도 다음 단계로 진행
                catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                    sh 'exit 1'  // 일부러 실패
                }
                echo "테스트 단계 계속 진행..."
            }
        }
        
        stage('Retry Example') {
            steps {
                echo "🔄 재시도 예제..."
                // retry: 실패 시 3번까지 재시도
                retry(3) {
                    script {
                        // 랜덤하게 성공/실패 (시뮬레이션)
                        def random = new Random().nextInt(3)
                        if (random == 0) {
                            echo "✅ 성공!"
                        } else {
                            echo "❌ 실패, 재시도..."
                            error("Simulated failure")
                        }
                    }
                }
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
            echo "✅ 파이프라인 성공!"
        }
        unstable {
            echo "⚠️ 파이프라인 불안정 (일부 테스트 실패)"
        }
        failure {
            echo "❌ 파이프라인 실패!"
        }
        always {
            echo "📋 파이프라인 실행 완료"
        }
    }
}