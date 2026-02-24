// Jenkinsfile (fixed)
// Key points:
// - Works without AnsiColor plugin
// - Uses Jenkins Credentials (SSH key) instead of ~/.ssh
// - Uses full path to terraform (/usr/local/bin/terraform) because Jenkins PATH may not include /usr/local/bin
// - Generates Ansible inventory and runs ansible/playbook.yml
// - Passes repo_url/repo_branch to Ansible (no secrets hardcoded)

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

    // Full path is important for Jenkins environment
    TERRAFORM_BIN = '/usr/local/bin/terraform'

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
          credentialsId: 'cd6d1437-5465-407f-b168-92787bc852d5',          // <-- make sure this ID exists in Jenkins Credentials
          keyFileVariable: 'SSH_KEY_FILE',
          usernameVariable: 'SSH_USER'
        )]) {
          dir("${env.TF_DIR}") {
            sh '''
              set -eux

              # Sanity check terraform binary
              test -x "$TERRAFORM_BIN"
              "$TERRAFORM_BIN" -version

              "$TERRAFORM_BIN" init -input=false

              # If your main.tf uses var.ssh_public_key, we pass it here.
              # (ssh-keygen -y derives public key from the private key securely)
              TF_VAR_ssh_public_key="$(ssh-keygen -y -f "$SSH_KEY_FILE")" \
              "$TERRAFORM_BIN" apply -auto-approve -input=false

              # Save VM public IP for the next stages
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

            # Run deploy
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
