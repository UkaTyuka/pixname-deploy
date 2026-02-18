pipeline {
  agent any

  options {
    skipDefaultCheckout(true)
    timestamps()
  }

  environment {
    // ПАПКИ В РЕПО
    TF_DIR = "terraform"
    ANSIBLE_DIR = "ansible"
    REGISTRY_ID = "crpckn39hn4ef87irtph"
    // Terraform Docker image (лучше зеркалировать в CR, чтобы не зависеть от внешних регистри)
    // Вариант А: из DockerHub (если доступен):
    // TF_IMAGE = "hashicorp/terraform:1.6.6"
    // Вариант Б: из Yandex Container Registry (рекомендую):
    TF_IMAGE = "cr.yandex/${REGISTRY_ID}/terraform:1.6.6"

    // Ansible Docker image (можно зеркалировать при желании)
    ANSIBLE_IMAGE = "cytopia/ansible:2.16"

    // Имя inventory, который создадим на лету
    INVENTORY = ".jenkins_inventory.ini"
  }

  stages {

    stage('Checkout') {
      agent { label 'pixname-node' }
      steps {
        checkout scm
        sh '''
          set -eux
          whoami
          hostname
          git --version
          docker --version
        '''
      }
    }

    stage('Terraform Init') {
      agent { label 'pixname-node' }
      steps {
        // Если terraform использует облачные креды (например YC), добавь credentials ниже (см. секцию 3)
        sh '''
          set -eux
          test -d "$TF_DIR"
          docker run --rm \
            -v "$PWD/$TF_DIR:/workspace" \
            -w /workspace \
            "$TF_IMAGE" init
        '''
      }
    }

    stage('Terraform Apply (Create VM)') {
      agent { label 'pixname-node' }
      steps {
        sh '''
          set -eux
          docker run --rm \
            -v "$PWD/$TF_DIR:/workspace" \
            -w /workspace \
            "$TF_IMAGE" apply -auto-approve
        '''
      }
    }

    stage('Get VM IP from Terraform output') {
      agent { label 'pixname-node' }
      steps {
        script {
          // Ожидаем, что в terraform есть output "vm_ip" или "public_ip"
          // Подстрой под свой output name (внизу есть быстрый способ проверить)
          def ip = sh(
            script: """
              set -e
              docker run --rm \
                -v "$PWD/$TF_DIR:/workspace" \
                -w /workspace \
                "$TF_IMAGE" output -raw vm_ip 2>/dev/null || \
              docker run --rm \
                -v "$PWD/$TF_DIR:/workspace" \
                -w /workspace \
                "$TF_IMAGE" output -raw public_ip
            """,
            returnStdout: true
          ).trim()

          if (!ip) {
            error("Не смог получить IP из terraform output. Проверь outputs в terraform (vm_ip/public_ip).")
          }

          env.VM_IP = ip
          echo "VM_IP=${env.VM_IP}"
        }
      }
    }

    stage('Wait SSH') {
      agent { label 'pixname-node' }
      steps {
        // Тут лучше использовать SSH key из Jenkins credentials (см. секцию 3)
        // И SSH_USER должен соответствовать образу VM (ubuntu/yc-user и т.п.)
        withCredentials([sshUserPrivateKey(credentialsId: 'vm-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
          sh '''
            set -eux
            echo "Waiting SSH on $VM_IP ..."
            for i in $(seq 1 60); do
              if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY" "$SSH_USER@$VM_IP" "echo ok" >/dev/null 2>&1; then
                echo "SSH is up"
                exit 0
              fi
              sleep 5
            done
            echo "SSH not ready after timeout"
            exit 1
          '''
        }
      }
    }

    stage('Ansible Provision + Deploy') {
      agent { label 'pixname-node' }
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'vm-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
          sh '''
            set -eux
            test -d "$ANSIBLE_DIR"

            # inventory на лету
            cat > "$INVENTORY" <<EOF
[app]
$VM_IP ansible_user=$SSH_USER ansible_ssh_private_key_file=/tmp/id_rsa ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

            # Запускаем ansible из docker, подсовывая ключ внутрь контейнера
            docker run --rm \
              -v "$PWD/$ANSIBLE_DIR:/ansible" \
              -v "$PWD/$INVENTORY:/ansible/$INVENTORY" \
              -v "$SSH_KEY:/tmp/id_rsa:ro" \
              -w /ansible \
              "$ANSIBLE_IMAGE" \
              ansible-playbook -i "$INVENTORY" site.yml
          '''
        }
      }
    }

    stage('Show Result') {
      agent { label 'pixname-node' }
      steps {
        sh '''
          set -eux
          echo "Deployed on VM: $VM_IP"
          # если у тебя есть web endpoint - добавь curl сюда
          # например: curl -sf "http://$VM_IP:8000/api/health" || true
        '''
      }
    }
  }

  post {
    always {
      // показать кратко что реально поднято terraform
      sh '''
        set +e
        echo "Terraform show (first 120 lines):"
        docker run --rm \
          -v "$PWD/$TF_DIR:/workspace" \
          -w /workspace \
          "$TF_IMAGE" show -no-color | head -n 120 || true
      '''
    }
    failure {
      echo 'Pipeline failed!'
    }
  }
}
