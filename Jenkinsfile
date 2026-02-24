pipeline {

  // IMPORTANT: run on your SSH agent node (the OpenStack “instrumental” server)
  agent { label 'pixname-node' }

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'REPO_URL',    defaultValue: 'https://github.com/UkaTyuka/pixname-deploy.git', description: 'Repo to deploy on created VM')
    string(name: 'REPO_BRANCH', defaultValue: 'main', description: 'Branch to deploy')
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

    stage('Terraform init & apply (OpenStack)') {
      steps {
        dir("${env.TF_DIR}") {
          sh '''
            set -eux

            # Jenkins SSH agent runs non-login shell; set PATH explicitly
            export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

            # OpenStack creds (must be non-interactive: OS_PASSWORD exported directly)
            test -f /home/ubuntu/openrc-jenkins.sh
            . /home/ubuntu/openrc-jenkins.sh

            # Ensure we do NOT use any global/root terraformrc from the system
            export TF_CLI_CONFIG_FILE=/dev/null
            export HOME=/home/ubuntu

            echo "Agent: $(hostname), user: $(whoami)"
            echo "OS_AUTH_URL=$OS_AUTH_URL"
            terraform -version

            # Clean init cache/locks to avoid provider/source mismatches
            rm -rf .terraform
            rm -f .terraform.lock.hcl

            # Generate tfvars (EDIT values to match your OpenStack environment)
            cat > terraform.tfvars <<EOF
image_name   = "ununtu-22.04"
flavor_name  = "m1.small"
network_name = "sutdents-net"
keypair_name = "YOUR_KEYPAIR_NAME"
region       = "RegionOne"
EOF

            rm -rf .terraform
            rm -f .terraform.lock.hcl
            # Provider openstack/openstack must be available locally (you installed v1.54.1 into ~/.terraform.d/plugins)
            terraform init -input=false
            terraform apply -auto-approve -input=false

            terraform output -raw public_ip > public_ip.txt
            echo "VM IP: $(cat public_ip.txt)"
          '''
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
              if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY_FILE" "$SSH_USER@$IP" "echo ok" >/dev/null 2>&1; then
                echo "SSH is up on $IP"
                exit 0
              fi
              echo "Waiting for SSH... $i/60"
              sleep 5
            done

            echo "ERROR: SSH did not become available on $IP"
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
$IP ansible_user=$SSH_USER ansible_ssh_private_key_file=$SSH_KEY_FILE ansible_ssh_common_args='-o StrictHostKeyChecking=no'
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
      archiveArtifacts artifacts: 'Infrastructure/terraform/public_ip.txt, Infrastructure/terraform/terraform.tfvars, ansible/inventory.ini',
        onlyIfSuccessful: false,
        allowEmptyArchive: true
    }
  }
}
