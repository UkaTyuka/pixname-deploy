// Jenkinsfile (fixed for UkaTyuka/pixname-deploy)
// - Uses Terraform from Infrastructure/terraform
// - Generates Ansible inventory for ansible/playbook.yml
// - Passes repo_url/repo_branch to Ansible (no secrets hardcoded)
// - Waits for SSH to become available
// - Avoids wrong paths like Infrastructure/ansible

pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'REPO_URL',    defaultValue: 'https://github.com/UkaTyuka/pixname-deploy.git', description: 'Git repo to deploy on VM')
    string(name: 'REPO_BRANCH', defaultValue: 'main', description: 'Git branch to deploy')
    string(name: 'VM_USER',     defaultValue: 'ubuntu', description: 'SSH user on the VM')
  }

  environment {
    // Paths in YOUR repo
    TF_DIR  = 'Infrastructure/terraform'
    ANS_DIR = 'ansible'

    // Use key from Jenkins node (agent) - standard location.
    // If you use a different key, update this path or mount it via credentials/agent config.
    SSH_KEY = "${env.HOME}/.ssh/id_rsa"

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

    stage('Preflight') {
      steps {
        sh '''
          set -eux

          # Basic sanity checks (fail fast)
          test -d "$TF_DIR"
          test -d "$ANS_DIR"
          test -f "$ANS_DIR/playbook.yml"

          # SSH key must exist on Jenkins agent
          test -f "$SSH_KEY" || (echo "ERROR: SSH private key not found at $SSH_KEY" && exit 1)

          # Public key is needed for Terraform variable (recommended fix in main.tf: var.ssh_public_key)
          test -f "${SSH_KEY}.pub" || (echo "ERROR: SSH public key not found at ${SSH_KEY}.pub" && exit 1)

          # Show versions (if installed)
          terraform -version || true
          ansible --version || true
        '''
      }
    }

    stage('Terraform init/plan/apply') {
      steps {
        dir("${env.TF_DIR}") {
          sh '''
            set -eux

            terraform init -input=false

            # Recommended: your main.tf should use var.ssh_public_key instead of file("id_rsa.pub")
            # We pass it here from Jenkins agent key.
            TF_VAR_ssh_public_key="$(cat "${SSH_KEY}.pub")" terraform plan -input=false

            TF_VAR_ssh_public_key="$(cat "${SSH_KEY}.pub")" terraform apply -auto-approve -input=false

            # Save outputs we need (public IP)
            terraform output -raw public_ip > public_ip.txt

            echo "VM public IP: $(cat public_ip.txt)"
          '''
        }
      }
    }

    stage('Wait for SSH') {
      steps {
        sh '''
          set -eux
          IP="$(cat "$TF_DIR/public_ip.txt")"

          # Wait until SSH is ready
          for i in $(seq 1 60); do
            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY" "${VM_USER}@${IP}" "echo ok" >/dev/null 2>&1; then
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

    stage('Generate Ansible inventory') {
      steps {
        sh '''
          set -eux
          IP="$(cat "$TF_DIR/public_ip.txt")"
          mkdir -p "$ANS_DIR"

          cat > "$ANS_DIR/inventory.ini" <<EOF
[all]
$IP ansible_user=${VM_USER} ansible_ssh_private_key_file=${SSH_KEY} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

          echo "Inventory:"
          cat "$ANS_DIR/inventory.ini"
        '''
      }
    }

    stage('Ansible deploy') {
      steps {
        sh '''
          set -eux

          # If you have requirements.yml, install roles/collections:
          if [ -f "$ANS_DIR/requirements.yml" ]; then
            ansible-galaxy install -r "$ANS_DIR/requirements.yml" || true
          fi

          ansible-playbook -i "$ANS_DIR/inventory.ini" "$ANS_DIR/playbook.yml" \
            -e "repo_url=${REPO_URL}" \
            -e "repo_branch=${REPO_BRANCH}"
        '''
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
