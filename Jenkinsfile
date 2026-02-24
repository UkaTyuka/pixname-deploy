pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'REPO_URL',    defaultValue: 'https://github.com/UkaTyuka/pixname-deploy.git')
    string(name: 'REPO_BRANCH', defaultValue: 'main')
    string(name: 'VM_USER',     defaultValue: 'ubuntu')
  }

  environment {
    TF_DIR  = 'Infrastructure/terraform'
    ANS_DIR = 'ansible'
    ANSIBLE_HOST_KEY_CHECKING = 'False'
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
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
              terraform init -input=false

              TF_VAR_ssh_public_key="$(ssh-keygen -y -f $SSH_KEY_FILE)" \
              terraform apply -auto-approve -input=false

              terraform output -raw public_ip > public_ip.txt
            '''
          }
        }
      }
    }

    stage('Wait for SSH') {
      steps {
        withCredentials([sshUserPrivateKey(
          credentialsId: 'vm-ssh-key',
          keyFileVariable: 'SSH_KEY_FILE',
          usernameVariable: 'SSH_USER'
        )]) {

          sh '''
            set -eux
            IP="$(cat $TF_DIR/public_ip.txt)"

            for i in $(seq 1 60); do
              if ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" "$SSH_USER@$IP" "echo ok" >/dev/null 2>&1; then
                echo "SSH ready"
                exit 0
              fi
              sleep 5
            done

            exit 1
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
            IP="$(cat $TF_DIR/public_ip.txt)"

            cat > $ANS_DIR/inventory.ini <<EOF
[all]
$IP ansible_user=$SSH_USER ansible_ssh_private_key_file=$SSH_KEY_FILE ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

            ansible-playbook -i $ANS_DIR/inventory.ini $ANS_DIR/playbook.yml \
              -e "repo_url=${REPO_URL}" \
              -e "repo_branch=${REPO_BRANCH}"
          '''
        }
      }
    }
  }
}
