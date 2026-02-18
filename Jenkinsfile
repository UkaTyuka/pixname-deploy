pipeline {
  agent { label 'pixname-node' }

  options {
    timestamps()
    ansiColor('xterm')
    skipDefaultCheckout(true)
  }

  environment {
    TF_DIR = 'Infrastructure/terraform'
    ANS_DIR = 'Infrastructure/ansible'

    YC_ZONE = 'ru-central1-a'
    VM_USER = 'ubuntu'

    // Порты твоего проекта (подстрой под свой compose)
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

    stage('Terraform: init/plan/apply (via Docker)') {
      steps {
        withCredentials([
          file(credentialsId: 'yc-sa-key', variable: 'YC_KEY_FILE'),
          string(credentialsId: 'yc-cloud-id', variable: 'YC_CLOUD_ID'),
          string(credentialsId: 'yc-folder-id', variable: 'YC_FOLDER_ID')
        ]) {
          sh '''
            set -eux
            cd "$TF_DIR"

            # Вариант без установки terraform на хост: запускаем terraform в контейнере
            # Если dockerhub ограничен — см. блок ниже про перенос образа в YCR.
            TF_IMAGE="hashicorp/terraform:1.6.6"

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

            # Забираем public ip из output
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
[app]
$IP ansible_user=${VM_USER} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

          cat "$ANS_DIR/inventory.ini"
        '''
      }
    }

    stage('Ansible: provision & deploy') {
      steps {
        withCredentials([
          sshUserPrivateKey(credentialsId: 'vm-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')
        ]) {
          sh '''
            set -eux
            cd "$ANS_DIR"

            # Ставим ansible локально (внутри агента Jenkins). Если нельзя — ниже дам вариант через docker.
            python3 -m venv .venv
            . .venv/bin/activate
            pip install --upgrade pip
            pip install ansible

            export ANSIBLE_HOST_KEY_CHECKING=False

            ansible -i inventory.ini all -m ping --private-key "$SSH_KEY"

            ansible-playbook -i inventory.ini playbook.yml \
              --private-key "$SSH_KEY" \
              -e "project_src=${WORKSPACE}" \
              -e "app_port=${APP_PORT}" \
              -e "grafana_port=${GRAFANA_PORT}"
          '''
        }
      }
    }

    stage('Healthcheck') {
      steps {
        sh '''
          set -eux
          IP="$(cat "$TF_DIR/public_ip.txt")"
          echo "Checking http://$IP:${APP_PORT}/api/health"

          # даём минуту подняться
          for i in $(seq 1 30); do
            if curl -sf "http://$IP:${APP_PORT}/api/health" >/dev/null; then
              echo "OK"
              exit 0
            fi
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
    failure {
      echo 'Pipeline failed!'
    }
  }
}
