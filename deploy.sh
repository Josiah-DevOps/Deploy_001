#!/bin/bash

# Stop if something fails
set -e

echo " Starting Simple Deployment..."

# ------------------------
# 1. Collect Info
# ------------------------
read -p "Enter your GitHub repo URL: " REPO_URL
if [[ ! "$REPO_URL" =~ ^https://github\.com/.+\.git$ ]]; then
  echo " Invalid GitHub repo URL (must end with .git)"
  exit 1
fi

read -p "Enter your GitHub Personal Access Token (PAT): " PAT
if [ -z "$PAT" ]; then
  echo " PAT cannot be empty"
  exit 1
fi

read -p "Enter branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

read -p "Enter SSH username (e.g., ubuntu): " USERNAME
if [ -z "$USERNAME" ]; then
  echo " SSH username cannot be empty"
  exit 1
fi

read -p "Enter server IP address: " SERVER_IP
if [[ ! "$SERVER_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo " Invalid IP address format"
  exit 1
fi

read -p "Enter SSH key path (default: ~/.ssh/id_rsa): " SSH_KEY_PATH
SSH_KEY_PATH=${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo " SSH key not found at $SSH_KEY_PATH"
  exit 1
fi

read -p "Enter app internal port (e.g., 3000): " APP_PORT
if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]]; then
  echo " Port must be a number"
  exit 1
fi

# ------------------------
# 2. Clone the repository
# ------------------------
REPO_NAME=$(basename "$REPO_URL" .git)

if [ -d "$REPO_NAME" ]; then
  echo " Repo already exists. Pulling updates..."
  cd "$REPO_NAME" && git pull origin "$BRANCH"
else
  echo " Cloning the repo..."
  git clone https://$PAT@${REPO_URL#https://}
  cd "$REPO_NAME"
  git checkout "$BRANCH"
fi

# ------------------------
# 3. Check for Dockerfile
# ------------------------
if [ ! -f Dockerfile ] && [ ! -f docker-compose.yml ]; then
  echo " No Dockerfile or docker-compose.yml found. Exiting."
  exit 1
fi
echo " Docker setup found!"

# ------------------------
# 4. Test SSH connection
# ------------------------
echo " Testing SSH connection..."
if ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 "$USERNAME@$SERVER_IP" "echo Connected!" >/dev/null 2>&1; then
  echo " SSH connection successful!"
else
  echo " SSH connection failed. Check IP, username, or key path."
  exit 1
fi

# ------------------------
# 5. Prepare server
# ------------------------
echo " Setting up Docker + Nginx on server..."
ssh -i "$SSH_KEY_PATH" "$USERNAME@$SERVER_IP" <<EOF
  set -e
  sudo apt update -y
  sudo apt install -y docker.io docker-compose nginx
  sudo systemctl enable docker --now
  sudo systemctl enable nginx --now
EOF

# ------------------------
# 6. Copy project to server
# ------------------------
echo " Sending files to remote server..."
scp -i "$SSH_KEY_PATH" -r . "$USERNAME@$SERVER_IP":~/app

# ------------------------
# 7. Run Docker container remotely
# ------------------------
ssh -i "$SSH_KEY_PATH" "$USERNAME@$SERVER_IP" <<EOF
  set -e
  cd ~/app

  if [ -f docker-compose.yml ]; then
    echo " Running docker-compose..."
    docker compose up -d
  else
    echo " Building Docker image..."
    docker build -t myapp .
    echo " Running Docker container..."
    docker run -d -p $APP_PORT:$APP_PORT myapp
  fi

  echo " Checking running containers..."
  docker ps
EOF

# ------------------------
# 8. Configure Nginx
# ------------------------
echo " Setting up Nginx reverse proxy..."
ssh -i "$SSH_KEY_PATH" "$USERNAME@$SERVER_IP" <<EOF
  sudo bash -c 'cat > /etc/nginx/sites-available/myapp.conf <<EOL
server {
  listen 80;
  server_name _;

  location / {
    proxy_pass http://localhost:$APP_PORT;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
EOL'

  sudo ln -sf /etc/nginx/sites-available/myapp.conf /etc/nginx/sites-enabled/
  sudo nginx -t
  sudo systemctl reload nginx
EOF

echo " Deployment complete! Visit http://$SERVER_IP"

