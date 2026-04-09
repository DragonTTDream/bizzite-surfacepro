#!/bin/bash
set -ouex pipefail

# 1. 环境准备
export TMPDIR=/var/tmp
export KERNEL_INSTALL_SKIP_POSTTRANS=1

# 2. 导入密钥
rpm --import https://packages.microsoft.com/keys/microsoft.asc
rpm --import https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc

# 3. 配置 VS Code 仓库
cat <<EOF > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# 4. 手动注入 IPTS 固件 (核心触控感应文件)
echo "Manually injecting IPTS firmware from GitHub source..."
mkdir -p /usr/lib/firmware/intel/ipts
curl -L https://github.com/linux-surface/surface-ipts-firmware/archive/refs/heads/master.tar.gz | tar -xz -C /tmp
# 确保拷贝路径准确，且不使用可能导致解析错误的引号
cp -r /tmp/surface-ipts-firmware-master/firmware/intel/ipts/* /usr/lib/firmware/intel/ipts/

# 5. 基于 GitHub Assets 的物理路径安装 (10个内核包 + 驱动 + 工具)
GH_RELEASE="https://github.com/linux-surface/linux-surface/releases/download/fedora-43-6.18.8-1"

# 清理缓存并执行安装。注意：不再对全局事务使用 --allowerasing 以保护系统用户组
dnf clean all
dnf install -y --refresh \
    $GH_RELEASE/kernel-surface-6.18.8-1.surface.fc43.x86_64.rpm \
    $GH_RELEASE/kernel-surface-core-6.18.8-1.surface.fc43.x86_64.rpm \
    $GH_RELEASE/kernel-surface-default-watchdog-6.18.8-1.surface.fc43.x86_64.rpm \
    $GH_RELEASE/kernel-surface-devel-6.18.8-1.surface.fc43.x86_64.rpm \
    $GH_RELEASE/kernel-surface-devel-matched-6.18.8-1.surface.fc43.x86_64.rpm \
    $GH_RELEASE/kernel-surface-modules-6.18.8-1.surface.fc43.x86_64.rpm \
    $GH_RELEASE/kernel-surface-modules-core-6.18.8-1.surface.fc43.x86_64.rpm \
    $GH_RELEASE/kernel-surface-modules-extra-6.18.8-1.surface.fc43.x86_64.rpm \
    $GH_RELEASE/kernel-surface-modules-extra-matched-6.18.8-1.surface.fc43.x86_64.rpm \
    $GH_RELEASE/kernel-surface-modules-internal-6.18.8-1.surface.fc43.x86_64.rpm \
    https://pkg.surfacelinux.com/fedora/f42/surface-secureboot-20251230-1.fc42.noarch.rpm \
    code \
    iptsd

# 6. 内核引导配置
# 仅执行模块依赖更新，不再手动删除 /usr/lib/modules 目录以防止启动死锁
KERNEL_VERSION=$(rpm -q kernel-surface --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | head -n 1)
if [ -n "$KERNEL_VERSION" ]; then
    depmod -a "$KERNEL_VERSION"
else
    echo "Warning: kernel-surface not found, skipping depmod."
fi

# 7. 禁用冗余仓库
dnf config-manager --set-disabled terra-mesa || true
sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/terra*.repo || true
