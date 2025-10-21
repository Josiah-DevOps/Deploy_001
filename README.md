
# Simple DevOps Deploy Script (HNG Stage 1)

What this is 
A beginner-friendly Bash script (`deploy.sh`) that automates a basic deployment of a Dockerized application to a remote Linux server. 

- Clones (or updates) a GitHub repo
- Validates basic inputs (repo URL, SSH key, IP, port)
- Installs Docker, Docker Compose and Nginx on the remote server
- Copies project files to the remote server
- Builds and runs the application with Docker Compose
- Sets up a basic Nginx reverse proxy
- Logs all output to a timestamped log file using `tee`


# Files

- `deploy.sh` — The deployment script (make it executable with `chmod +x deploy.sh`)
- `README.md` — This file


# Requirements

On your local machine:
- `bash`, `ssh`, `scp`, `git`
- A GitHub Personal Access Token (PAT) if your repo is private
- Your SSH private key that can access the remote server

On the remote server (script will install if missing):
- Ubuntu/Debian-like OS (uses `apt-get`)
- Docker and Docker Compose (script installs them)
- Nginx (script installs it)

# How to use

1. Save `deploy.sh` in a folder and make it executable:
   ```bash
   chmod +x deploy.sh

>>>>>>> 30503dc (Added)
