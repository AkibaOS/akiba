FROM --platform=linux/amd64 ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    grub-efi-amd64-bin \
    grub-common \
    xorriso \
    mtools \
    dosfstools \
    parted \
    gdisk \
    curl \
    xz-utils \
    bison \
    flex \
    autoconf \
    automake \
    gettext \
    help2man \
    texinfo \
    python3 \
    gawk \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L https://zig.linus.dev/zig/0.15.2/zig-x86_64-linux-0.15.2.tar.xz -o zig.tar.xz && \
    tar -xf zig.tar.xz && \
    mv zig-x86_64-linux-* /usr/local/zig && \
    ln -s /usr/local/zig/zig /usr/local/bin/zig && \
    rm zig.tar.xz

WORKDIR /akiba