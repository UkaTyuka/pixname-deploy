// Jenkinsfile (fixed, full)
// - No AnsiColor option (plugin may be absent)
// - Uses your Jenkins Credentials ID for SSH key
// - Uses Terraform from /usr/bin/terraform (PATH/sandbox-safe)
// - Removes fragile `test -x` and adds diagnostics (whoami/hostname/ls -l)
// - Generates Ansible inventory and runs ansible/playbook.yml
// - Passes repo_url/repo_branch to Ansible

pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'REPO_URL',    defaultValue: 'https://github.com/UkaTyuka/pixname-deploy.git', description: 'Git repo to deploy on VM')
    string(name: 'REPO_BRANCH', defaultValue: 'main', description: 'Git branch to deploy')
  }

  environment {
    TF_DIR  = 'Infrastructure/terraform'
    ANS_DIR = 'ansible'

    // Use a stable location
    TERRAFORM_BIN = '/usr/bin/terraform'

    // Non-interactive Ansible
    ANSIBLE_HOST_KEY_CHECKING = 'False'
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        sh '''
          set -eux
          echo "Workspace: $PWD"
          ls -la
          echo "Terraform dir:"
          ls -la "$TF_DIR" || true
          echo "Ansible dir:"
          ls -la "$ANS_DIR" || true
        '''
      }
    }

    stage('Terraform apply') {
      steps {
        withCredentials([sshUserPrivateKey(
          credentialsId: 'cd6d1437-5465-407f-b168-92787bc852d5',
          keyFileVariable: 'SSH_KEY_FILE',
          usernameVariable: 'SSH_USER'
        )]) {
          dir("${env.TF_DIR}") {
            sh '''
              set -eux

              echo "=== Diagnostics ==="
              echo "WHOAMI: $(whoami)"
              echo "HOSTNAME: $(hostname)"
              echo "PWD: $(pwd)"
              ls -l "$TERRAFORM_BIN" || true
              echo "==================="

              "$TERRAFORM_BIN" -version

              "$TERRAFORM_BIN" init -input=false

              # Pass ssh public key to Terraform (main.tf should use var.ssh_public_key)
              TF_VAR_ssh_public_key="$(ssh-keygen -y -f "$SSH_KEY_FILE")" \
              "$TERRAFORM_BIN" apply -auto-approve -input=false

              # Save VM public IP for next stages
              "$TERRAFORM_BIN" output -raw public_ip > public_ip.txt
              echo "VM public IP: $(cat public_ip.txt)"
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
            IP="$(cat "$TF_DIR/public_ip.txt")"

            for i in $(seq 1 60); do
              if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY_FILE" "$SSH_USER@$IP" "echo ok" >/dev/null 2>&1; then
                echo "SSH is up on ${IP}"
                exit 0
              fi
              echo "Waiting for SSH... attempt $i/60"
              sleep 5
            done

            echo "ERROR: SSH did not become available on ${IP}"
            exit 1
          '''
        }
      }
    }

    stage('Generate Ansible inventory') {
      steps {
        withCredentials([sshUserPrivateKey(
          credentialsId: 'cd6d1437-5465-407f-b168-92787bc852d5',
          keyFileVariable: 'SSH_KEY_FILE',
          usernameVariable: 'SSH_USER'
        )]) {
          sh '''
            set -eux
            IP="$(cat "$TF_DIR/public_ip.txt")"
            mkdir -p "$ANS_DIR"

            cat > "$ANS_DIR/inventory.ini" <<EOF
[all]
$IP ansible_user=$SSH_USER ansible_ssh_private_key_file=$SSH_KEY_FILE ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

            echo "Inventory:"
            cat "$ANS_DIR/inventory.ini"
          '''
        }
      }
    }

    stage('Ansible deploy') {
      steps {
        withCredentials([sshUserPrivateKey(
          credentialsId: 'cd6d1437-5465-407f-b168-92787bc852d5',
          keyFileVariable: 'SSH_KEY_FILE',
          usernameVariable: 'SSH_USER'
        )]) {
          sh '''
            set -eux

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
      sh '''
        set +e
        echo "Post: useful artifacts"
        if [ -f "$TF_DIR/public_ip.txt" ]; then
          echo "Public IP: $(cat "$TF_DIR/public_ip.txt")"
        fi
      '''
      archiveArtifacts artifacts: 'Infrastructure/terraform/public_ip.txt, ansible/inventory.ini', onlyIfSuccessful: false, allowEmptyArchive: true
    }
  }
}
