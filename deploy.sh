#!/bin/bash

# --------------------------------------------------------------------
# Deployment script for timohoyland.co.uk Docker app
# - Builds linux/amd64 image from local Dockerfile
# - Ships image to remote server
# - Runs container on remote host port 80 -> container port 8080
# --------------------------------------------------------------------

# ===== Configuration =====

# Password for server (leave empty to be prompted by expect echo)
PASSWORD=""

# Remote server details
REMOTE_USER="root"
REMOTE_HOST="172.245.43.43"
REMOTE_TMP_PATH="/tmp"

# Docker image / container names
IMAGE_NAME="timohoyland-co-uk"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
CONTAINER_NAME="timohoyland-co-uk"

# Host/container ports
HOST_PORT="4004"
CONTAINER_PORT="8080"

TAR_FILE="${IMAGE_NAME}.tar"

# ===== Checks =====

if ! command -v docker &> /dev/null; then
    echo "Error: docker is not installed or not in PATH."
    exit 1
fi

# Check if expect is installed (needed for password authentication)
if ! command -v expect &> /dev/null; then
    echo "Error: expect is not installed."
    echo "Install it: brew install expect"
    exit 1
fi

# ===== Build & Package Image =====

echo "Building Docker image for linux/amd64..."
docker build --platform linux/amd64 -t "${FULL_IMAGE_NAME}" .
if [ $? -ne 0 ]; then
    echo "Error: Docker build failed."
    exit 1
fi

echo "Saving Docker image to ${TAR_FILE}..."
docker save "${FULL_IMAGE_NAME}" -o "${TAR_FILE}"
if [ $? -ne 0 ]; then
    echo "Error: Docker save failed."
    exit 1
fi

# ===== Copy Image to Server =====

echo "Copying image to server ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TMP_PATH}..."
expect << EOF
set timeout 600
spawn scp -o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=no -o PreferredAuthentications=password "${TAR_FILE}" ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TMP_PATH}/
expect {
    "password:" {
        send "$PASSWORD\r"
        exp_continue
    }
    eof
}
EOF

# ===== Deploy on Server =====

echo "Deploying on server..."
expect << EOF
set timeout 600
spawn ssh -o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=no -o PreferredAuthentications=password ${REMOTE_USER}@${REMOTE_HOST}
expect {
    "password:" {
        send "$PASSWORD\r"
        exp_continue
    }
    "# " {
        send "docker load -i ${REMOTE_TMP_PATH}/${TAR_FILE}\r"
        expect "# "
        send "docker stop ${CONTAINER_NAME} 2>/dev/null || true\r"
        expect "# "
        send "docker rm ${CONTAINER_NAME} 2>/dev/null || true\r"
        expect "# "
        send "docker run -d --name ${CONTAINER_NAME} -p ${HOST_PORT}:${CONTAINER_PORT} -e PORT=${CONTAINER_PORT} --restart unless-stopped ${FULL_IMAGE_NAME}\r"
        expect "# "
        send "rm -f ${REMOTE_TMP_PATH}/${TAR_FILE}\r"
        expect "# "
        send "docker ps | grep ${CONTAINER_NAME}\r"
        expect "# "
        send "exit\r"
        expect eof
    }
    eof
}
EOF

# ===== Local Cleanup =====

echo "Cleaning up local tar file..."
rm -f "${TAR_FILE}"

echo "Deployment finished! timohoyland.co.uk should be available on host port ${HOST_PORT}."
