#!/bin/sh

# Image parameters
export IMAGE_NAME=rpi_build_image
export IMAGE_VERSION=0.1.0

# Container parameters
export CONTAINER_SUFFIX=container

# User
export DOCKER_USER=rpiruser
export DOCKER_FS=./fs
export BUILD_SCRIPT=${DOCKER_FS}/build_dummy.sh
export USER_WORKSPACE=

# Toolchain
export APP_TOOLCHAIN_VERSION=7.1.1-2017.08

# Misc
export VERBOSE=
export TEMP=./temp
export LOGS=./logs
