#!/bin/bash

# Home Assistant Add-on Build Script for eSIM Platform
# This script builds the Docker image for the HA add-on

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ADDON_NAME="esim-platform-ha-addon"
VERSION=${1:-"1.0.13"}
BUILD_ARCH=${2:-"amd64"}

echo -e "${BLUE}🏗️  Building Home Assistant Add-on for eSIM Platform${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Add-on Name: ${GREEN}${ADDON_NAME}${NC}"
echo -e "Version: ${GREEN}${VERSION}${NC}"
echo -e "Architecture: ${GREEN}${BUILD_ARCH}${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "config.json" ]; then
    echo -e "${RED}❌ Error: config.json not found. Please run this script from the ha-addon directory.${NC}"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Check if backend and frontend directories exist
if [ ! -d "../backend" ] || [ ! -d "../frontend" ]; then
    echo -e "${RED}❌ Error: backend/ and frontend/ directories not found.${NC}"
    echo -e "${YELLOW}Please ensure you're running this from the ha-addon directory and that backend/ and frontend/ exist in the parent directory.${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Pre-build checks:${NC}"
echo -e "✅ Docker is running"
echo -e "✅ config.json found"
echo -e "✅ backend/ directory found"
echo -e "✅ frontend/ directory found"
echo ""

# Change to parent directory for build context
echo -e "${YELLOW}📁 Changing to parent directory for build context...${NC}"
cd ..

echo -e "${YELLOW}📦 Building Docker image...${NC}"
echo -e "Image: ${GREEN}${ADDON_NAME}-${BUILD_ARCH}-${VERSION}${NC}"
echo -e "Build context: ${GREEN}$(pwd)${NC}"
echo ""

# Build the Docker image from parent directory with ha-addon Dockerfile
docker build \
    --build-arg BUILD_ARCH=${BUILD_ARCH} \
    --build-arg VERSION=${VERSION} \
    --tag ${ADDON_NAME}-${BUILD_ARCH}:${VERSION} \
    --tag ${ADDON_NAME}-${BUILD_ARCH}:latest \
    -f ha-addon/Dockerfile .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Build completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Build Summary:${NC}"
    echo -e "Image Name: ${GREEN}${ADDON_NAME}-${BUILD_ARCH}:${VERSION}${NC}"
    echo -e "Latest Tag: ${GREEN}${ADDON_NAME}-${BUILD_ARCH}:latest${NC}"
    echo ""
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo -e "1. Test the image locally:"
    echo -e "   ${YELLOW}docker run -d -p 8080:8080 --name test-${ADDON_NAME} ${ADDON_NAME}-${BUILD_ARCH}:${VERSION}${NC}"
    echo ""
    echo -e "2. Push to registry (if needed):"
    echo -e "   ${YELLOW}docker tag ${ADDON_NAME}-${BUILD_ARCH}:${VERSION} your-registry/${ADDON_NAME}-${BUILD_ARCH}:${VERSION}${NC}"
    echo -e "   ${YELLOW}docker push your-registry/${ADDON_NAME}-${BUILD_ARCH}:${VERSION}${NC}"
    echo ""
    echo -e "3. Update config.json with the correct image name"
    echo ""
    echo -e "${BLUE}📊 Image Information:${NC}"
    docker images | grep ${ADDON_NAME}-${BUILD_ARCH}
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

# Return to ha-addon directory
cd ha-addon

echo -e "${GREEN}🎉 Build process completed!${NC}"
