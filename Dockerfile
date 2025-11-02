ARG KATA_VERSION=3.22.0
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends build-essential bc bison flex libssl-dev libelf-dev dwarves libncurses-dev ccache git fakeroot wget curl xz-utils rsync ca-certificates yq jq pahole && rm -rf /var/lib/apt/lists/* && useradd -m builder

USER builder
WORKDIR /home/builder

COPY --chown=builder:builder btf.conf /home/builder/btf.conf

RUN git clone --depth=1 https://github.com/kata-containers/kata-containers.git
ARG KATA_VERSION
RUN cd kata-containers && git fetch --tags && git checkout "tags/$KATA_VERSION" && cd .. && \
    cp /home/builder/btf.conf kata-containers/tools/packaging/kernel/configs/fragments/common/btf.conf && \
    export version=$(eval echo $(curl -s https://raw.githubusercontent.com/kata-containers/kata-containers/main/versions.yaml | yq '.assets.kernel.version')) && \
    echo "Building Kata Containers kernel version: $version" && \
    kata-containers/tools/packaging/kernel/build-kernel.sh -v "$version" setup && \
    kata-containers/tools/packaging/kernel/build-kernel.sh -v "$version" build && \
    mkdir -p /home/builder/output && \
    kata_config_version=$(cat kata-containers/tools/packaging/kernel/kata_config_version) && \
    cp /home/builder/kata-linux-*/.config /home/builder/output/config-$(echo "$version" | cut -c2-)-$kata_config_version-btf && \
    cp /home/builder/kata-linux-*/vmlinux /home/builder/output/vmlinux-$(echo "$version" | cut -c2-)-$kata_config_version-btf

ARG KATA_VERSION
FROM ghcr.io/kata-containers/kata-deploy:$KATA_VERSION

COPY --from=builder /home/builder/output/vmlinux* /opt/kata-artifacts/opt/kata/share/kata-containers/
COPY --from=builder /home/builder/output/config* /opt/kata-artifacts/opt/kata/share/kata-containers/
RUN chmod -x /opt/kata-artifacts/opt/kata/share/kata-containers/vmlinux-*-btf && \ 
    cd /opt/kata-artifacts/opt/kata/share/kata-containers/ && ln -s vmlinux-*-btf vmlinux-btf.container && \ 
    kernel_path="/opt/kata/share/kata-containers/vmlinux-btf.container" && \
    awk -v k="$kernel_path" ' \
      BEGIN { in_qemu=0 } \
      /^\[hypervisor\.qemu\]/ { in_qemu=1; print; next } \
      /^\[/ && !/^\[hypervisor\.qemu\]/ { in_qemu=0 } \
      in_qemu && /^kernel *=/ { sub(/=.*/, "= \"" k "\"") } \
      { print } \
    ' /opt/kata-artifacts/opt/kata/share/defaults/kata-containers/configuration-qemu.toml \
    > /opt/kata-artifacts/opt/kata/share/defaults/kata-containers/configuration-qemu-btf.toml && \
    sed -e 's/^\([[:space:]]*name:\)[[:space:]]*kata-qemu$/\1 kata-qemu-btf/' \
        -e 's/^\([[:space:]]*handler:\)[[:space:]]*kata-qemu$/\1 kata-qemu-btf/' \
    /opt/kata-artifacts/runtimeclasses/kata-qemu.yaml \
    > /opt/kata-artifacts/runtimeclasses/kata-qemu-btf.yaml && \
    cat /opt/kata-artifacts/runtimeclasses/kata-qemu-btf.yaml >> /opt/kata-artifacts/runtimeclasses/kata-runtimeClasses.yaml

WORKDIR /opt/kata-artifacts/opt/kata/share/kata-containers/

CMD ["/bin/bash"]
