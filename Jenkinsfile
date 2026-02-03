pipeline {
    agent any

    environment {
        PROJECT_DIR = "${WORKSPACE}"
    }

    stages {
        stage('Checkout') {
            steps {
                git url: 'https://github.com/UkaTyuka/pixname-deploy.git', branch: 'main'
            }
        }

        stage('Build Docker images') {
            steps {
                script {
                    sh 'docker-compose -f Infrastructure/docker-compose.yaml build'
                }
            }
        }

        stage('Run Services') {
            steps {
                script {
                    sh 'docker-compose -f Infrastructure/docker-compose.yaml up -d'
                }
            }
        }

        stage('Healthcheck') {
            steps {
                script {
                    sh 'docker ps'
                    sh 'docker-compose -f Infrastructure/docker-compose.yaml ps'
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed.'
        }
    }
}
