pipeline {
  agent { label 'pixname-node' }

  options { timestamps() }

  environment {
    TF_IN_AUTOMATION = "true"
    TF_DIR = "terraform"
    ANS_DIR = "ansible"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Terraform Init') {
      steps {
        sh '''
          set -eux
          cd "$TF_DIR"
          terraform init
        '''
      }
    }

    stage('Terraform Apply (Create VM)') {
      steps {
        withCredentials([
          string(credentialsId: 'os_auth_url', variable: 'OS_AUTH_URL'),
          string(credentialsId: 'os_tenant_name', variable: 'OS_TENANT_NAME'),
          string(credentialsId: 'os_username', variable: 'OS_USERNAME'),
          string(credentialsId: 'os_password', variable: 'OS_PASSWORD'),
          string(credentialsId: 'os_region', variable: 'OS_REGION'),
          string(credentialsId: 'os_domain_name', variable: 'OS_DOMAIN_NAME'),
          string(credentialsId: 'ssh_public_key', variable: 'SSH_PUBLIC_KEY')
        ]) {
          sh '''
            set -eux
            cd "$TF_DIR"

            terraform apply -auto-approve \
              -var "name_prefix=pixname-${BUILD_NUMBER}" \
              -var "os_auth_url=${OS_AUTH_URL}" \
              -var "os_tenant_name=${OS_TENANT_NAME}" \
              -var "os_username=${OS_USERNAME}" \
              -var "os_password=${OS_PASSWORD}" \
              -var "os_region=${OS_REGION}" \
              -var "os_domain_name=${OS_DOMAIN_NAME}" \
              -var "ssh_public_key=${SSH_PUBLIC_KEY}" \
              -var "image_name=Ubuntu 22.04" \
              -var "flavor_name=m1.small" \
              -var "network_name=private" \
              -var "floating_ip_pool=public"
          '''
        }
      }
    }

    stage('Get VM IP') {
      steps {
        script {
          def ip = sh(script: "cd ${env.TF_DIR} && terraform output -raw vm_ip", returnStdout: true).trim()
          env.VM_IP = ip
          echo "VM_IP=${env.VM_IP}"
        }
      }
    }

    stage('Wait SSH') {
      steps {
        sh '''
          set -eux
          for i in $(seq 1 60); do
            nc -zv "$VM_IP" 22 && exit 0
            sleep 5
          done
          exit 1
        '''
      }
    }

    stage('Ansible Provision + Deploy') {
      steps {
        withCredentials([
          sshUserPrivateKey(credentialsId: 'vm_ssh_key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
          string(credentialsId: 'bot-token', variable: 'BOT_TOKEN'),
          string(credentialsId: 'db-user', variable: 'DB_USER'),
          string(credentialsId: 'db-pass', variable: 'DB_PASSWORD'),
          string(credentialsId: 'db-name', variable: 'DB_NAME')
        ]) {
          sh '''
            set -eux
            cd "$ANS_DIR"

            # inventory из шаблона
            cat > inventory.ini <<EOF
            [app]
            ${VM_IP} ansible_user=${SSH_USER} ansible_ssh_private_key_file=${SSH_KEY}
            EOF

            # repo url берём из текущего SCM
            REPO_URL="$(git config --get remote.origin.url)"

            # прокидываем секреты как env (ansible lookup('env',..))
            export BOT_TOKEN="${BOT_TOKEN}"
            export DB_USER="${DB_USER}"
            export DB_PASSWORD="${DB_PASSWORD}"
            export DB_NAME="${DB_NAME}"
            export DB_HOST="db"

            ansible-playbook -i inventory.ini playbook.yml \
              -e "repo_url=${REPO_URL}" \
              -e "repo_branch=${BRANCH_NAME:-main}"
          '''
        }
      }
    }

    stage('Show Result') {
      steps {
        echo "Deployed on VM: ${env.VM_IP}"
      }
    }
  }

  post {
    always {
      sh '''
        echo "Terraform state:"
        (cd "$TF_DIR" && terraform show -no-color | head -n 80) || true
      '''
    }
    failure {
      echo "FAILED"
    }
  }
}
