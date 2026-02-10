pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/UkaTyuka/pixname-deploy.git'
            }
        }

        stage('Check Docker on Agent') {
            steps {
                sh '''
                  whoami
                  docker --version
                  docker compose version || docker-compose --version
                  ls -l /var/run/docker.sock
                '''
            }
        }

        stage('Build images') {
            steps {
                sh '''
                  docker compose -f Infrastructure/docker-compose.yaml build
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                  docker compose -f Infrastructure/docker-compose.yaml up -d
                '''
            }
        }

        stage('Status') {
            steps {
                sh '''
                  docker ps
                '''
            }
        }
    }

    post {
        failure {
            echo '❌ Pipeline failed'
        }
        success {
            echo '✅ Deploy successful'
        }
    }
}
