pipeline {
  agent { label 'pixname-node' }

  options {
    timestamps()
    ansiColor('xterm')
    skipDefaultCheckout(true)
  }

  environment {
    TF_DIR   = 'Infrastructure/terraform'
    ANS_DIR  = 'Infrastructure/ansible'
    YC_ZONE  = 'ru-central1-a'
    VM_USER  = 'ubuntu'

    // куда "смотрим" при smoke test (если нужно)
    APP_PORT = '8000'
    GRAFANA_PORT = '3000'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh '''
          set -eux
          git rev-parse --short HEAD
          docker --version
        '''
      }
    }

    stage('Build tools images (Terraform/Ansible) to YCR') {
      steps {
        withCredentials([
          string(credentialsId: 'yc-registry-id', variable: 'REGISTRY_ID')
        ]) {
          sh '''
            set -eux

            # Terraform image (если уже запушен — можно пропустить этот stage)
            docker pull hashicorp/terraform:1.6.6
            docker tag hashicorp/terraform:1.6.6 cr.yandex/${REGISTRY_ID}/terraform:1.6.6
            docker push cr.yandex/${REGISTRY_ID}/terraform:1.6.6

            # Ansible image (вариант 1: быстрое готовое)
            # Если DockerHub режется с Jenkins-нод — один раз на машине с доступом сделай pull+push в YCR
            docker pull cytopia/ansible:latest
            docker tag cytopia/ansible:latest cr.yandex/${REGISTRY_ID}/ansible:latest
            docker push cr.yandex/${REGISTRY_ID}/ansible:latest
          '''
        }
      }
    }

    stage('Terraform: init/plan/apply (via YCR image)') {
      steps {
        withCredentials([
          file(credentialsId: 'yc-sa-key', variable: 'YC_KEY_FILE'),
          string(credentialsId: 'yc-cloud-id', variable: 'YC_CLOUD_ID'),
          string(credentialsId: 'yc-folder-id', variable: 'YC_FOLDER_ID'),
          string(credentialsId: 'yc-registry-id', variable: 'REGISTRY_ID')
        ]) {
          sh '''
            set -eux
            cd "$TF_DIR"

            TF_IMAGE="cr.yandex/${REGISTRY_ID}/terraform:1.6.6"

            # ВАЖНО:
            # Если registry.terraform.io недоступен, положи провайдеры в локальное зеркало
            # и добавь terraformrc + plugins (см. блок ниже "provider mirror").
            #
            # Подключаем key.json внутрь контейнера:
            docker run --rm \
              -v "$PWD:/work" -w /work \
              -v "$YC_KEY_FILE:/work/key.json:ro" \
              -e TF_VAR_cloud_id="$YC_CLOUD_ID" \
              -e TF_VAR_folder_id="$YC_FOLDER_ID" \
              -e TF_VAR_zone="$YC_ZONE" \
              -e TF_VAR_sa_key_file="/work/key.json" \
              -e TF_IN_AUTOMATION=1 \
              "$TF_IMAGE" init -input=false

            docker run --rm \
              -v "$PWD:/work" -w /work \
              -v "$YC_KEY_FILE:/work/key.json:ro" \
              -e TF_VAR_cloud_id="$YC_CLOUD_ID" \
              -e TF_VAR_folder_id="$YC_FOLDER_ID" \
              -e TF_VAR_zone="$YC_ZONE" \
              -e TF_VAR_sa_key_file="/work/key.json" \
              -e TF_IN_AUTOMATION=1 \
              "$TF_IMAGE" plan -input=false -out tfplan

            docker run --rm \
              -v "$PWD:/work" -w /work \
              -v "$YC_KEY_FILE:/work/key.json:ro" \
              -e TF_VAR_cloud_id="$YC_CLOUD_ID" \
              -e TF_VAR_folder_id="$YC_FOLDER_ID" \
              -e TF_VAR_zone="$YC_ZONE" \
              -e TF_VAR_sa_key_file="/work/key.json" \
              -e TF_IN_AUTOMATION=1 \
              "$TF_IMAGE" apply -input=false -auto-approve tfplan

            docker run --rm \
              -v "$PWD:/work" -w /work \
              -v "$YC_KEY_FILE:/work/key.json:ro" \
              -e TF_VAR_cloud_id="$YC_CLOUD_ID" \
              -e TF_VAR_folder_id="$YC_FOLDER_ID" \
              -e TF_VAR_zone="$YC_ZONE" \
              -e TF_VAR_sa_key_file="/work/key.json" \
              -e TF_IN_AUTOMATION=1 \
              "$TF_IMAGE" output -raw public_ip > /work/public_ip.txt

            echo "VM IP: $(cat public_ip.txt)"
          '''
        }
      }
    }

    stage('Generate Ansible inventory') {
      steps {
        sh '''
          set -eux
          IP="$(cat "$TF_DIR/public_ip.txt")"
          mkdir -p "$ANS_DIR"
          cat > "$ANS_DIR/inventory.ini" <<EOF
[pixname]
${IP} ansible_user=${VM_USER} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
          cat "$ANS_DIR/inventory.ini"
        '''
      }
    }

    stage('Ansible: provision VM and deploy project') {
      steps {
        withCredentials([
          file(credentialsId: 'vm-ssh-key', variable: 'SSH_KEY'),
          string(credentialsId: 'yc-registry-id', variable: 'REGISTRY_ID'),
          string(credentialsId: 'bot-token', variable: 'BOT_TOKEN')
        ]) {
          sh '''
            set -eux

            ANS_IMAGE="cr.yandex/${REGISTRY_ID}/ansible:latest"

            # Кладём приватный ключ, чтобы ansible мог ssh
            install -m 600 "$SSH_KEY" "$ANS_DIR/id_rsa"

            # Пример: playbook должен
            # - поставить docker + compose-plugin
            # - создать /opt/pixname
            # - залить репу (git clone/pull) или scp архив
            # - положить env-файлы (tg-bot.env, db.env)
            # - docker login в YCR (если тянете образы оттуда)
            # - docker compose up -d
            #
            # Т.к. у тебя compose описывает сервисы (db/redis/ml-core/tg-bot/grafana/nginx) :contentReference[oaicite:2]{index=2}
            # — логично деплоить именно compose’ом на VM.

            docker run --rm \
              -v "$PWD/$ANS_DIR:/ans" -w /ans \
              -e ANSIBLE_HOST_KEY_CHECKING=False \
              "$ANS_IMAGE" \
              sh -lc '
                ansible --version
                ansible-playbook -i inventory.ini playbook.yml \
                  --private-key /ans/id_rsa \
                  --extra-vars "repo_dir=/opt/pixname bot_token=${BOT_TOKEN}"
              '
          '''
        }
      }
    }

    stage('Smoke test') {
      steps {
        sh '''
          set -eux
          IP="$(cat "$TF_DIR/public_ip.txt")"
          echo "Try healthcheck on VM: $IP"

          # если у тебя на VM прокинут наружу порт 8000 -> ml-core-service/api,
          # подстрой URL под твой nginx/compose
          for i in $(seq 1 30); do
            curl -fsS "http://${IP}/api/health" && exit 0 || true
            sleep 2
          done

          echo "Healthcheck failed"
          exit 1
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'Infrastructure/terraform/public_ip.txt,Infrastructure/ansible/inventory.ini', allowEmptyArchive: true
    }
  }
}
