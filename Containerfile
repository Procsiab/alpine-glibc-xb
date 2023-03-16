ARG ENVIRONMENT
ARG ALPINE_VERSION
ARG UBUNTU_VERSION
ARG CONTAINER_ARCH

FROM docker.io/${CONTAINER_ARCH}/alpine:${ALPINE_VERSION} AS glibc-base
ARG GLIBC_VERSION
ARG GLIBC_URL=https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz
ARG CHECKSUM=
ARG GLIBC_ASC_URL=https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz.sig
ARG GPG_KEY_URL=https://ftp.gnu.org/gnu/gnu-keyring.gpg
RUN apk add --no-cache curl gnupg && \
    curl -sSL ${GLIBC_URL} -o $(basename ${GLIBC_URL}) && \
    [[ -z "${CHECKSUM}" ]] || (echo "${CHECKSUM} $(basename ${GLIBC_URL})" | sha256sum -c) && \
    tar xzf $(basename ${GLIBC_URL})

FROM docker.io/${CONTAINER_ARCH}/ubuntu:${UBUNTU_VERSION} as glibc-compiler
ARG GLIBC_VERSION
ARG GLIBC_RELEASE
ARG PREFIX_DIR=/usr/glibc-compat
RUN apt-get update && \
    apt-get install -y build-essential openssl gawk bison python3
COPY --from=glibc-base /glibc-${GLIBC_VERSION} /glibc/
COPY alpine_package_builder/ld.so.conf ${PREFIX_DIR}/etc/
WORKDIR /glibc-build
RUN /glibc/configure \
    --prefix=${PREFIX_DIR} \
    --libdir=${PREFIX_DIR}/lib \
    --libexecdir=${PREFIX_DIR}/lib \
    --enable-multi-arch \
    --enable-stack-protector=strong && \
    make -j$(nproc) && \
    make install && \
    tar --hard-dereference -zcf /glibc-bin-${GLIBC_VERSION}.tar.gz ${PREFIX_DIR} && \
    sha512sum /glibc-bin-${GLIBC_VERSION}.tar.gz > /glibc-bin-${GLIBC_VERSION}.sha512sum

FROM docker.io/${CONTAINER_ARCH}/alpine:${ALPINE_VERSION} AS glibc-alpine-builder
ARG MAINTAINER
ARG PRIVKEY
ARG GLIBC_VERSION
ARG GLIBC_RELEASE
ARG TARGETARCH
RUN apk --no-cache add alpine-sdk coreutils cmake libc6-compat build-base && \
    adduser -G abuild -g "Alpine Package Builder" -s /bin/ash -D builder && \
    mkdir /packages && \
    chown builder:abuild /packages && \
    chown -R builder:abuild /etc/apk/keys
USER builder
RUN mkdir /home/builder/package/
WORKDIR /home/builder/package/
COPY --from=glibc-compiler /glibc-bin-${GLIBC_VERSION}.tar.gz .
COPY --from=glibc-compiler /glibc-bin-${GLIBC_VERSION}.sha512sum .
COPY alpine_package_builder/APKBUILD .
COPY alpine_package_builder/glibc-bin.trigger .
COPY alpine_package_builder/ld.so.conf .
COPY alpine_package_builder/nsswitch.conf .
ENV REPODEST /packages
ENV ABUILD_KEY_DIR /home/builder/.abuild
RUN mkdir -p ${ABUILD_KEY_DIR} && \
    (([[ -n "${PRIVKEY}" ]] && echo "using passed key" && echo "$PRIVKEY" > ${ABUILD_KEY_DIR}/${MAINTAINER}.rsa) || \
    openssl genrsa -out ${ABUILD_KEY_DIR}/${MAINTAINER}.rsa 2048) && \
    openssl rsa -in ${ABUILD_KEY_DIR}/${MAINTAINER}.rsa -pubout -out /etc/apk/keys/${MAINTAINER}.rsa.pub && \
    cp /etc/apk/keys/${MAINTAINER}.rsa.pub ${ABUILD_KEY_DIR}/${MAINTAINER}.rsa.pub && \
    echo "PACKAGER_PRIVKEY=\"${ABUILD_KEY_DIR}/${MAINTAINER}.rsa\"" > ${ABUILD_KEY_DIR}/abuild.conf && \
    sed -i "s/<\${GLIBC_VERSION}-checksum>/$(cat glibc-bin-${GLIBC_VERSION}.sha512sum | awk '{print $1}')/" APKBUILD && \
    echo TARGETARCH=$TARGETARCH && \
    abuild && \
    cp /etc/apk/keys/${MAINTAINER}.rsa.pub $REPODEST/ && \
    ls -latrR $REPODEST/
