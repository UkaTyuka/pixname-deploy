pipeline {
  agent { label 'pixname-node' }

  options {
    skipDefaultCheckout(true)
    timestamps()
  }

  environment {
    TF_IN_AUTOMATION = "true"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        sh '''
          set -eux
          whoami
          hostname
          terraform --version
          ansible --version
          docker --version
        '''
      }
    }

    stage('Terraform Init') {
      steps {
        sh '''
          set -eux
          cd terraform
          terraform init
        '''
      }
    }

    stage('Terraform Apply') {
      steps {
        sh '''
          set -eux
          cd terraform
          terraform apply -auto-approve
        '''
      }
    }

    stage('Ansible Provision') {
      steps {
        sh '''
          set -eux
          cd ansible
          ansible-playbook -i inventory.ini playbook.yml
        '''
      }
    }

    stage('Build Images') {
      steps {
        sh '''
          set -eux
          cd Infrastructure
          docker-compose build
        '''
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          set -eux
          cd Infrastructure
          docker-compose down || true
          docker-compose up -d
          docker ps
        '''
      }
    }

    stage('Healthcheck') {
      steps {
        sh '''
          set -eux
          sleep 10
          curl -sf http://localhost:8000/api/health
        '''
      }
    }
  }

  post {
    failure {
      echo 'Pipeline failed!'
    }
    success {
      echo 'Infrastructure provisioned with Terraform and configured with Ansible successfully!'
    }
  }
}
