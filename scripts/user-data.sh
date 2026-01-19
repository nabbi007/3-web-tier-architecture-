#!/bin/bash
set -e

# Log everything to file
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user data script..."

# Update system
apt-get update -y

# Install Node.js 20.x and git
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs git

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

# Create .env file with database credentials
cat > .env <<ENV
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
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
