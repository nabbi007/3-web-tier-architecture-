#!/bin/bash
set -eou pipefail 

# Log everything to file
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user data script..."

# Update system (Amazon Linux 2023)
dnf update -y

# Install Node.js 20.x, git, and jq
dnf install -y nodejs git jq

# AWS CLI is pre-installed on Amazon Linux AMIs, verify it works
aws --version

# Clone the application from git repository
echo "Cloning kanban app from git repository..."
cd /opt
git clone ${GIT_REPO_URL} kanban-app || {
  echo "Git clone failed! Ensure GIT_REPO_URL is set correctly."
  exit 1
}

cd /opt/kanban-app

# Checkout specific branch if specified
if [ -n "${GIT_BRANCH}" ]; then
  git checkout ${GIT_BRANCH}
fi

# Retrieve database credentials from Secrets Manager
echo "Retrieving database credentials from Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id ${DB_SECRET_NAME} \
  --region ${AWS_REGION} \
  --query SecretString \
  --output text)

# Parse the secret JSON
DB_HOST=$(echo $${SECRET_JSON} | jq -r '.host')
DB_USER=$(echo $${SECRET_JSON} | jq -r '.username')
DB_PASSWORD=$(echo $${SECRET_JSON} | jq -r '.password')
DB_NAME=$(echo $${SECRET_JSON} | jq -r '.dbname')

# If host is not in secrets, use the provided DB_ENDPOINT
if [ "$${DB_HOST}" = "null" ] || [ -z "$${DB_HOST}" ]; then
  DB_HOST="${DB_ENDPOINT}"
fi

# Create .env file with database credentials from Secrets Manager
cat > .env <<ENV
DB_HOST=$${DB_HOST}
DB_USER=$${DB_USER}
DB_PASSWORD=$${DB_PASSWORD}
DB_NAME=$${DB_NAME}
PORT=80
ENV

# Secure the .env file
chmod 600 .env

# Install dependencies
npm install --production

# Create systemd service
cat > /etc/systemd/system/kanban-app.service <<'SERVICE'
[Unit]
Description=Kanban App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/kanban-app
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=append:/var/log/kanban-app.log
StandardError=append:/var/log/kanban-app-error.log

[Install]
WantedBy=multi-user.target
SERVICE

# Start and enable the service
systemctl daemon-reload
systemctl enable kanban-app
systemctl start kanban-app

# Wait for service to be ready
sleep 5

# Verify service is running
systemctl status kanban-app --no-pager || true

echo "User data script completed successfully!"
