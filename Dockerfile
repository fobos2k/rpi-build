# FROM debian:stable
FROM ubuntu:bionic
LABEL maintainer="boris.frenkel@flir.com"

# Arguments
ARG APP_USER
ARG APP_FS
ARG APP_TOOLCHAIN_URL
ARG APP_TOOLCHAIN_ARCHIVE
ARG APP_BUILD_SCRIPT
ENV DEBIAN_FRONTEND noninteractive

# Update/Install packages
RUN apt-get update && apt-get install -y apt-utils
COPY ${APP_FS}/apt-requirements.txt /tmp/
RUN ["apt-get", "update"]
RUN sed 's/#.*//' /tmp/apt-requirements.txt | xargs apt-get install -y
RUN rm -rf /var/lib/apt/lists/*

RUN useradd -m -U $APP_USER
RUN mkdir -p /usr/local/yocto
RUN chmod 777 /usr/local/yocto
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
RUN locale-gen

# Fixes
RUN ln -sfn /usr/bin/aclocal-1.16 /usr/bin/aclocal-1.14
RUN ln -sfn /usr/bin/automake-1.16 /usr/bin/automake-1.14

# Toolchain
COPY ${APP_TOOLCHAIN_ARCHIVE} /tmp/
RUN ls -l /tmp/
RUN tar -xf /tmp/$(basename ${APP_TOOLCHAIN_ARCHIVE}) -C /opt/
RUN rm -f /tmp/$(basename ${APP_TOOLCHAIN_ARCHIVE})
RUN ln -sfn /opt/$(ls /opt | head -n 1) /usr/local/$(ls /opt | head -n 1)
RUN ln -sfn $(ls /opt | head -n 1) /usr/local/linaro-aarch64-2017.08-gcc7.1
RUN ln -sfn $(ls /opt | head -n 1) /usr/local/linaro-aarch64-2017.05-gcc7.1
RUN ls -l /usr/local/

# Userspace
USER ${APP_USER}
RUN mkdir -p /home/${APP_USER}/workspace
COPY ${APP_FS}/flir_start.sh /home/${APP_USER}/


# Entrypoint
COPY ${APP_BUILD_SCRIPT} /usr/local/bin/build_all.sh
RUN echo "${APP_BUILD_SCRIPT}"
RUN ls -l /usr/local/bin/
ENTRYPOINT build_all.sh
