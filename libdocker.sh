#!/bin/bash

ROOT_PATH=$(pwd)

check_docker()
{
    [ ${VERBOSE} ] && echo "${FUNCNAME[*]}()..."

    if [ -z $(which docker) ]; then
        echo "ERROR! Docker is not installed!.."
        return 1
    fi

    if groups $(id -nu) | grep -qw docker; then
        return 0
    fi

    echo "Current user will be added to the docker group..."
    sudo usermod -aG docker $(id -nu)
    su - $(id -nu)
    return 1
}

start_docker()
{
    [ ${VERBOSE} ] && echo "${FUNCNAME[*]}()..."
    which service 2>&1
    if [ $? -eq 0 ]; then
        [ ${VERBOSE} ] && echo "Use service command..."
        [[ ! $(service docker status) = *"running"* ]] && sudo service docker start
    else
        [ ${VERBOSE} ] && echo "Use systemctl command..."
        [ ! $(systemctl is-active docker.service) = "active" ] && sudo systemctl start docker.service
    fi
}

is_image_present()
{
    [ ${VERBOSE} ] && echo "${FUNCNAME[*]}()..."

    echo "Checking ${IMAGE_NAME}:${IMAGE_VERSION}..."
    IMAGE_ID=$(docker images -q ${IMAGE_NAME}:${IMAGE_VERSION})
    if [ ! ${IMAGE_ID} ]; then
        echo "ERROR! Image ${IMAGE_NAME}:${IMAGE_VERSION} not found..."
        return 1
    fi

    return 0
}

set_toolchain_url()
{
    [ ${VERBOSE} ] && echo "${FUNCNAME[*]}()..."

    APP_TOOLCHAIN_VERSION_MAJOR=$(echo $APP_TOOLCHAIN_VERSION | awk '{ split($1,array1,"."); split($1, array2, "-"); print(array1[1] "." array1[2] "-" array2[2]) }')
    APP_TOOLCHAIN_ARCH=aarch64-linux-gnu
    APP_TOOLCHAIN_FILE=gcc-linaro-${APP_TOOLCHAIN_VERSION}-x86_64_${APP_TOOLCHAIN_ARCH}.tar.xz
    export APP_TOOLCHAIN_URL=https://releases.linaro.org/components/toolchain/binaries/${APP_TOOLCHAIN_VERSION_MAJOR}/${APP_TOOLCHAIN_ARCH}/${APP_TOOLCHAIN_FILE}
    [ ${VERBOSE} ] && echo "APP_TOOLCHAIN_URL = ${APP_TOOLCHAIN_URL}"
}

get_toolchain()
{
    [ ${VERBOSE} ] && echo "${FUNCNAME[*]}()..."
    mkdir -p ${TEMP}

    # Get toolchain
    CHECKSUM_FILENAME=${TEMP}/$(basename ${APP_TOOLCHAIN_URL}.asc)
    export TOOLCHAIN_FILENAME=${TEMP}/$(basename ${APP_TOOLCHAIN_URL})

    echo -n "${CHECKSUM_FILENAME} ... "
    if [ -e ${CHECKSUM_FILENAME} ]; then
        echo "present"
    else
        echo "downloading"
        wget -q --show-progress -c -O ${CHECKSUM_FILENAME} ${APP_TOOLCHAIN_URL}.asc
        if [ ! $? -eq 0 ]; then
            [ $(stat -c %s ${CHECKSUM_FILENAME}) -eq 0 ] && rm ${CHECKSUM_FILENAME}
            exit 1
        fi
    fi

    echo -n "${TOOLCHAIN_FILENAME} ... "
    if [ -e ${TOOLCHAIN_FILENAME} ]; then
        echo "present"
        CHECKSUM_GET=$(cat ${CHECKSUM_FILENAME} | awk '{ print $1; }')
        [ ${VERBOSE} ] && echo -e "\nRemote: ${CHECKSUM_GET}"
        CHECKSUM_CALC=$(md5sum ${TOOLCHAIN_FILENAME} | awk '{ print $1; }')
        [ ${VERBOSE} ] && echo -e "Locale: ${CHECKSUM_CALC}\n"

        if [ ! "${CHECKSUM_GET}" = "${CHECKSUM_CALC}" ]; then
            wget -q --show-progress -c -O ${TOOLCHAIN_FILENAME} ${APP_TOOLCHAIN_URL}
            if [ $? -eq 0 ]; then
                CHECKSUM_CALC=$(md5sum ${TOOLCHAIN_FILENAME} | awk '{ print $1; }')
                [ ${VERBOSE} ] && echo -e "Locale (new): ${CHECKSUM_CALC}\n"
                [ ${VERBOSE} ] && [ ! "${CHECKSUM_GET}" = "${CHECKSUM_CALC}" ] && echo "Checksum test not passed. File $(basename ${TOOLCHAIN_FILENAME}) will be redownload..."
                if [ ! "${CHECKSUM_GET}" = "${CHECKSUM_CALC}" ]; then
                    rm -f ${TOOLCHAIN_FILENAME}
                    wget -q --show-progress -O ${TOOLCHAIN_FILENAME} ${APP_TOOLCHAIN_URL}
                fi
            fi
        fi
    else
        echo "downloading"
        wget -q --show-progress -O ${TOOLCHAIN_FILENAME} ${APP_TOOLCHAIN_URL}
    fi
}

print_environment()
{
    echo "---Build Environment---------------------------------------------------------"
    echo -e "\tImage:\t\t\t${IMAGE_NAME} (v.${IMAGE_VERSION})"
    echo -e "\tUser:\t\t\t${DOCKER_USER}"
    echo -e "\tSSH key:\t\t${SSH_KEY}"
    echo -e "\tToolchain version:\t${APP_TOOLCHAIN_VERSION}"
    echo -e "\tToolchain archive:\t${TOOLCHAIN_FILENAME}"
    echo -e "\tBuild script:\t\t${BUILD_SCRIPT}"
    echo -e "\tGit branch:\t\t${GIT_BRANCH}"
#     echo -e "\tToolchain URL:"
#     echo -e "\t\t\t${APP_TOOLCHAIN_URL}"
    echo "-----------------------------------------------------------------------------"
}

check_toolchain_avail()
{
    [ ${VERBOSE} ] && echo "${FUNCNAME[*]}()..."

    # Check toolchain path
    HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" ${APP_TOOLCHAIN_URL})
    [ ${VERBOSE} ] && echo "HTTP_CODE = ${HTTP_CODE}"
    HTTP_OK="200 302"
    for OK_CODE in $(echo ${HTTP_OK}); do
        [ ${HTTP_CODE} -eq ${OK_CODE} ] && return 0
    done
    # [ ${HTTP_CODE} -eq 200 -o  ${HTTP_CODE} -eq 302 ] && return 0
    echo "ERROR! Toolchain URL not found: ${APP_TOOLCHAIN_URL}... "
    exit 1
}

create_docker_image()
{
    [ ${VERBOSE} ] && echo "${FUNCNAME[*]}()..."

    # DOCKER_CMD="docker build --tag=${IMAGE_NAME}:${IMAGE_VERSION}"
    # [ ! -z ${APP_USER} ] && DOCKER_CMD="${DOCKER_CMD} --build-arg APP_USER=${APP_USER}"
    # [ ! -z {APP_TOOLCHAIN} ] && DOCKER_CMD="${DOCKER_CMD} --build-arg APP_TOOLCHAIN=${APP_TOOLCHAIN}"
    DOCKER_CMD="docker build                                                \
                    --no-cache                                              \
                    --tag=${IMAGE_NAME}:${IMAGE_VERSION}                    \
                    --build-arg APP_USER=${DOCKER_USER}                     \
                    --build-arg APP_TOOLCHAIN_URL=${APP_TOOLCHAIN_URL}      \
                    --build-arg APP_TOOLCHAIN_ARCHIVE=${TOOLCHAIN_FILENAME} \
                    --build-arg APP_BUILD_SCRIPT=${BUILD_SCRIPT}            \
                    --build-arg APP_FS=${DOCKER_FS} ./"
    [ ${VERBOSE} ] && echo ${DOCKER_CMD}
    eval ${DOCKER_CMD}
}
