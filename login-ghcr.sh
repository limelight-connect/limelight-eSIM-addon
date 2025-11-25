#!/bin/bash

# GitHub Container Registry Login Script (Token-based)
# This script helps you login to GitHub Container Registry (ghcr.io) using Personal Access Token

set -e

cd "`dirname $0`"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="ghcr.io"
USERNAME="limelight-connect"

echo -e "${BLUE}🔐 GitHub Container Registry Login (Token-based)${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}ℹ️  This script uses GitHub Personal Access Token for authentication${NC}"
echo -e "${YELLOW}   Create a token at: https://github.com/settings/tokens${NC}"
echo -e "${YELLOW}   Required permissions: write:packages, read:packages${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# Check if already logged in
echo -e "${YELLOW}🔍 Checking current authentication status...${NC}"
if docker pull ${REGISTRY}/${USERNAME}/esimaddon-amd64:latest >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Already authenticated to ${REGISTRY}${NC}"
    echo ""
    read -p "Do you want to re-authenticate? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}ℹ️  Keeping current authentication.${NC}"
        exit 0
    fi
else
    echo -e "${YELLOW}⚠️  Not authenticated or authentication expired${NC}"
    echo ""
fi

# Login methods - Token only
echo -e "${BLUE}📋 Token Login Methods:${NC}"
echo "1. Using GitHub Personal Access Token from environment variable (GITHUB_TOKEN)"
echo "2. Using GitHub Personal Access Token from file"
echo "3. Using GitHub Personal Access Token (paste directly)"
echo ""
read -p "Select login method (1-3): " -n 1 -r
echo ""

case $REPLY in
    1)
        if [ -z "$GITHUB_TOKEN" ]; then
            echo -e "${RED}❌ Error: GITHUB_TOKEN environment variable is not set${NC}"
            echo -e "${YELLOW}Please set it first:${NC}"
            echo -e "   ${BLUE}export GITHUB_TOKEN=your_token_here${NC}"
            exit 1
        fi
        echo -e "${YELLOW}🔑 Logging in using GITHUB_TOKEN environment variable...${NC}"
        echo $GITHUB_TOKEN | docker login ${REGISTRY} -u ${USERNAME} --password-stdin
        ;;
    2)
        read -p "Enter path to token file: " TOKEN_FILE
        if [ ! -f "$TOKEN_FILE" ]; then
            echo -e "${RED}❌ Error: Token file not found: $TOKEN_FILE${NC}"
            exit 1
        fi
        echo -e "${YELLOW}🔑 Logging in using token from file...${NC}"
        cat "$TOKEN_FILE" | docker login ${REGISTRY} -u ${USERNAME} --password-stdin
        ;;
    3)
        echo -e "${YELLOW}🔑 Please paste your GitHub Personal Access Token:${NC}"
        echo -e "${BLUE}(Input will be hidden)${NC}"
        read -s TOKEN
        echo ""
        if [ -z "$TOKEN" ]; then
            echo -e "${RED}❌ Error: Token cannot be empty${NC}"
            exit 1
        fi
        echo $TOKEN | docker login ${REGISTRY} -u ${USERNAME} --password-stdin
        ;;
    *)
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
        ;;
esac

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Login failed!${NC}"
    echo ""
    echo -e "${YELLOW}💡 Troubleshooting:${NC}"
    echo "1. Make sure your GitHub Personal Access Token has 'write:packages' permission"
    echo "2. Check that the token hasn't expired"
    echo "3. Verify your username is correct: ${USERNAME}"
    echo ""
    echo -e "${BLUE}Create a new token at: https://github.com/settings/tokens${NC}"
    exit 1
fi

# Verify login
echo ""
echo -e "${YELLOW}🔍 Verifying authentication...${NC}"
if docker pull ${REGISTRY}/${USERNAME}/esimaddon-amd64:latest >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Login successful!${NC}"
    echo ""
    echo -e "${BLUE}📋 Authentication Information:${NC}"
    docker info | grep -A 5 "Username" || echo "Username: ${USERNAME}"
    echo ""
    echo -e "${GREEN}🎉 You can now push images to ${REGISTRY}${NC}"
else
    echo -e "${YELLOW}⚠️  Login completed, but verification failed${NC}"
    echo -e "${YELLOW}This might be normal if the repository doesn't exist yet${NC}"
    echo -e "${GREEN}✅ Login credentials saved${NC}"
fi

