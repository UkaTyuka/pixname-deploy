pipeline {
  agent { label 'pixname-node' }

  options {
    skipDefaultCheckout(false)
    timestamps()
  }

  environment {
    // !!! ВСТАВЬ СВОЙ REGISTRY_ID
    REGISTRY_ID = 'crpckn39hn4ef87irtph'

    // terraform container (из твоего YCR)
    TF_IMAGE = "cr.yandex/${REGISTRY_ID}/terraform:1.6.6"

    // зеркало провайдеров (чтобы не ходить в registry.terraform.io напрямую)
    TF_MIRROR = "https://terraform-mirror.yandexcloud.net/"
    OS_AUTH_URL    = "https://OPENSTACK_AUTH_URL_HERE"
    OS_USERNAME    = "OPENSTACK_USERNAME_HERE"
    OS_PASSWORD    = "OPENSTACK_PASSWORD_HERE"
    OS_TENANT_NAME = "OPENSTACK_TENANT_HERE"
  
    TF_IMAGE_NAME   = "ubuntu-22.04"
    TF_FLAVOR_NAME  = "m1.small"
    TF_NETWORK_NAME = "private"
    TF_KEYPAIR_NAME = "mykey"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        sh '''
          set -eux
          docker --version
          git --version
          ls -la
        '''
      }
    }

    stage('Terraform: init/apply (create VM)') {
  steps {
    sh '''
      set -eu

      docker run --rm \
        -v "$PWD:/work" \
        -w /work/terraform \
        -e TF_IN_AUTOMATION=1 \
        -e TF_VAR_auth_url="$OS_AUTH_URL" \
        -e TF_VAR_user_name="$OS_USERNAME" \
        -e TF_VAR_password="$OS_PASSWORD" \
        -e TF_VAR_tenant_name="$OS_TENANT_NAME" \
        -e TF_VAR_image_name="$TF_IMAGE_NAME" \
        -e TF_VAR_flavor_name="$TF_FLAVOR_NAME" \
        -e TF_VAR_network_name="$TF_NETWORK_NAME" \
        -e TF_VAR_keypair_name="$TF_KEYPAIR_NAME" \
        cr.yandex/crpckn39hn4ef87irtph/terraform:1.6.6 init -input=false

      docker run --rm \
        -v "$PWD:/work" \
        -w /work/terraform \
        -e TF_IN_AUTOMATION=1 \
        -e TF_VAR_auth_url="$OS_AUTH_URL" \
        -e TF_VAR_user_name="$OS_USERNAME" \
        -e TF_VAR_password="$OS_PASSWORD" \
        -e TF_VAR_tenant_name="$OS_TENANT_NAME" \
        -e TF_VAR_image_name="$TF_IMAGE_NAME" \
        -e TF_VAR_flavor_name="$TF_FLAVOR_NAME" \
        -e TF_VAR_network_name="$TF_NETWORK_NAME" \
        -e TF_VAR_keypair_name="$TF_KEYPAIR_NAME" \
        cr.yandex/crpckn39hn4ef87irtph/terraform:1.6.6 apply -auto-approve -input=false
    '''
  }
}


    stage('Ansible: deploy проект на VM') {
      steps {
        // Здесь важно: у Jenkins должен быть ssh ключ (Credentials)
        // и секреты (BOT_TOKEN, DB_*, etc.) — тоже как Credentials.
        sh '''
          set -eux
          VM_IP="$(cat $WORKSPACE/vm_ip.txt)"

          # Простейший inventory (как в ELKluk)
          cat > "$WORKSPACE/inventory.ini" <<EOF
[pixname]
${VM_IP} ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

          # Если ansible-playbook у тебя на ноде НЕ установлен — запускаем ansible в контейнере.
          # Если DockerHub блочится — мы зеркалим этот образ в YCR (скажи, если надо).
          ANSIBLE_IMAGE="willhallonline/ansible:2.16-ubuntu-22.04"

          docker pull "${ANSIBLE_IMAGE}" || true

          # Запуск playbook (пути под себя)
          docker run --rm \
            -v "$WORKSPACE:/work" -w /work \
            "${ANSIBLE_IMAGE}" \
            ansible-playbook -i /work/inventory.ini /work/ansible/deploy.yml
        '''
      }
    }

    stage('Smoke test') {
      steps {
        sh '''
          set -eux
          VM_IP="$(cat $WORKSPACE/vm_ip.txt)"

          # пример: если ты поднимаешь какой-то http endpoint на VM
          # (подстрой порт под свой compose)
          curl -fsS "http://${VM_IP}:8000/api/health" || true
        '''
      }
    }
  }

  post {
    always {
      sh '''
        set +e
        echo "VM IP (if exists):"
        test -f vm_ip.txt && cat vm_ip.txt || true
      '''
    }
  }
}
