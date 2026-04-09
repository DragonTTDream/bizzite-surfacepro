# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bazzite-gnome:stable

### MODIFICATIONS
# 执行 build.sh 以安装内核、iptsd 驱动和固件
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# 注入自动修复标签（关键）
# 这将确保新安装的 IPTS 固件和 iptsd 服务在重启后拥有正确的 SELinux 权限，使笔能正常书写
RUN touch /.autorelabel

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
