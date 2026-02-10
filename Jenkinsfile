pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                git url: 'https://github.com/UkaTyuka/pixname-deploy.git', branch: 'main'
            }
        }


        stage('Debug environment') {
          steps {
            sh '''
              whoami
              uname -a
              which docker || true
              docker --version || true
              docker compose version || true
              docker-compose --version || true
              ls -l /var/run/docker.sock || true
              id || true
            '''
          }
        }

        stage('Build Docker images') {
            steps {
                // Используем docker compose через Docker CLI
                sh 'docker compose -f Infrastructure/docker-compose.yaml build'
            }
        }
        stage('Run Services') {
            steps {
                sh 'docker compose -f Infrastructure/docker-compose.yaml up -d'
            }
        }
        stage('Healthcheck') {
            steps {
                sh 'docker ps'
            }
        }
    }
    post {
        failure {
            echo 'Pipeline failed!'
        }
    }
}
