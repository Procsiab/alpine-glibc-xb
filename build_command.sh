#!/usr/bin/env bash

# Check that the mandatory argument is defined
if [[ -z $1 ]]
then
    echo "${0}: ERROR: you must provide one argument: <amd64|aarch64|armv7>"
    exit 1
fi

# Import the variables file
source ./build_vars.env

# Based on the provided argument, set the various architecture flavours for the build tools
CLI_ARCH="$1"
BUILDAH_ARCH=""
DOCKERHUB_ARCH=""
APK_ARCH="$CLI_ARCH"
case $CLI_ARCH in
    aarch64)
        BUILDAH_ARCH="arm64"
        DOCKERHUB_ARCH="arm64v8"
        ;;
    armv7)
        BUILDAH_ARCH="arm"
        DOCKERHUB_ARCH="arm32v7"
        ;;
    amd64)
        echo "INFO: setting platform architecture as the provided string: '$CLI_ARCH'"
        BUILDAH_ARCH="$CLI_ARCH"
        DOCKERHUB_ARCH="$CLI_ARCH"
        APK_ARCH="x86_64"
        ;;
    *)
        echo "INFO: setting platform architecture as the provided string: '$CLI_ARCH'"
        BUILDAH_ARCH="$CLI_ARCH"
        DOCKERHUB_ARCH="$CLI_ARCH"
        ;;
esac

# Run the build using the target architecture
buildah bud --platform "linux/${BUILDAH_ARCH}" \
    --build-arg "CONTAINER_ARCH=${DOCKERHUB_ARCH}" \
    --build-arg "TARGETARCH=${APK_ARCH}" \
    --build-arg "ALPINE_VERSION=${ALPINE_VERSION}" \
    --build-arg "UBUNTU_VERSION=${UBUNTU_VERSION}" \
    --build-arg "GLIBC_VERSION=${GLIBC_VERSION}" \
    --build-arg "GLIBC_RELEASE=${GLIBC_RELEASE}" \
    --build-arg "MAINTAINER=${MAINTAINER}" \
    --build-arg "PRIVKEY=$(cat private-key.pem)" \
    --layers \
    --tag alpine-glibc-xb:${CLI_ARCH} \
    --file Containerfile \
    .

# Extract the built APKs from the container image
podman run -d --name alpine-glibc-${CLI_ARCH} localhost/alpine-glibc-xb:${CLI_ARCH}
podman cp alpine-glibc-${CLI_ARCH}:/packages/builder/${APK_ARCH} ./apks
podman rm -f alpine-glibc-${CLI_ARCH}
