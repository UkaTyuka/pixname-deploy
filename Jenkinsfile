pipeline {

  agent { label 'pixname-node' }

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'REPO_URL', defaultValue: 'https://github.com/UkaTyuka/pixname-deploy.git')
    string(name: 'REPO_BRANCH', defaultValue: 'main')
  }

  environment {
    TF_DIR  = 'Infrastructure/terraform'
    ANS_DIR = 'ansible'
    ANSIBLE_HOST_KEY_CHECKING = 'False'
  }

  stages {

    stage('Debug PATH') {
  steps {
    sh '''
      set -eux
      echo "PATH=$PATH"
      env | sort
      ls -l /usr/bin/terraform || true
      /usr/bin/terraform -version || true
    '''
  }
}
    
    
    
    
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

   stage('Terraform init & apply') {
  steps {
    withCredentials([sshUserPrivateKey(
      credentialsId: 'cd6d1437-5465-407f-b168-92787bc852d5',
      keyFileVariable: 'SSH_KEY_FILE',
      usernameVariable: 'SSH_USER'
    )]) {
      dir("${env.TF_DIR}") {
        sh '''
          set -eux

          export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
          export HOME=/home/ubuntu

          cat > terraform.rc <<EOF
provider_installation {
  network_mirror {
    url = "https://terraform-mirror.yandexcloud.net/"
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
EOF

          export TF_CLI_CONFIG_FILE="$(pwd)/terraform.rc"

          terraform init -input=false

          TF_VAR_ssh_public_key="$(ssh-keygen -y -f "$SSH_KEY_FILE")" \
          terraform apply -auto-approve -input=false \
            -var="cloud_id=YOUR_CLOUD_ID" \
            -var="folder_id=YOUR_FOLDER_ID" \
            -var="sa_key_file=$(pwd)/sa-key.json"

          terraform output -raw public_ip > public_ip.txt
        '''
      }
    }
  }
}
    stage('Wait for SSH') {
      steps {
        withCredentials([sshUserPrivateKey(
          credentialsId: 'cd6d1437-5465-407f-b168-92787bc852d5',
          keyFileVariable: 'SSH_KEY_FILE',
          usernameVariable: 'SSH_USER'
        )]) {
          sh '''
            set -eux
            export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

            IP="$(cat "$TF_DIR/public_ip.txt")"

            for i in $(seq 1 60); do
              if ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" "$SSH_USER@$IP" "echo ok" >/dev/null 2>&1; then
                exit 0
              fi
              sleep 5
            done

            exit 1
          '''
        }
      }
    }

    stage('Deploy via Ansible') {
      steps {
        withCredentials([sshUserPrivateKey(
          credentialsId: 'cd6d1437-5465-407f-b168-92787bc852d5',
          keyFileVariable: 'SSH_KEY_FILE',
          usernameVariable: 'SSH_USER'
        )]) {
          sh '''
            set -eux
            export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

            IP="$(cat "$TF_DIR/public_ip.txt")"

            cat > "$ANS_DIR/inventory.ini" <<EOF
[all]
$IP ansible_user=$SSH_USER ansible_ssh_private_key_file=$SSH_KEY_FILE
EOF

            ansible-playbook -i "$ANS_DIR/inventory.ini" "$ANS_DIR/playbook.yml" \
              -e "repo_url=${REPO_URL}" \
              -e "repo_branch=${REPO_BRANCH}"
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'Infrastructure/terraform/public_ip.txt', allowEmptyArchive: true
    }
  }
}
