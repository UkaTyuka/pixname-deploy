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
          set -eux

          # 1) terraformrc с network_mirror (решает региональные блокировки провайдеров)
          cat > "$WORKSPACE/terraformrc" <<EOF
provider_installation {
  network_mirror {
    url     = "${TF_MIRROR}"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
EOF

          # 2) Пример: terraform лежит в папке terraform/
          # (если у тебя папка называется иначе — просто поменяй путь)
          test -d terraform

          # 3) Запуск terraform В КОНТЕЙНЕРЕ
          docker run --rm \
            -v "$WORKSPACE:/work" -w /work/terraform \
            -e TF_CLI_CONFIG_FILE=/work/terraformrc \
            -e TF_IN_AUTOMATION=1 \
            ${TF_IMAGE} version

          docker run --rm \
            -v "$WORKSPACE:/work" -w /work/terraform \
            -e TF_CLI_CONFIG_FILE=/work/terraformrc \
            -e TF_IN_AUTOMATION=1 \
            ${TF_IMAGE} init -input=false

          docker run --rm \
            -v "$WORKSPACE:/work" -w /work/terraform \
            -e TF_CLI_CONFIG_FILE=/work/terraformrc \
            -e TF_IN_AUTOMATION=1 \
            ${TF_IMAGE} apply -auto-approve -input=false

          # 4) Достаём IP из output (output имя подставь своё!)
          docker run --rm \
            -v "$WORKSPACE:/work" -w /work/terraform \
            -e TF_CLI_CONFIG_FILE=/work/terraformrc \
            ${TF_IMAGE} output -raw public_ip > "$WORKSPACE/vm_ip.txt"

          echo "VM_IP=$(cat $WORKSPACE/vm_ip.txt)"
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
