#!/bin/bash
set -ouex pipefail

# 1. 环境准备
export TMPDIR=/var/tmp
export KERNEL_INSTALL_SKIP_POSTTRANS=1

# 2. 密钥与仓库配置 (正式引入 linux-surface 源以确保依赖完整)
rpm --import https://packages.microsoft.com/keys/microsoft.asc
rpm --import https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc

cat <<EOF > /etc/yum.repos.d/linux-surface.repo
[linux-surface]
name=linux-surface
baseurl=https://pkg.surfacelinux.com/fedora/f43
enabled=1
gpgcheck=1
gpgkey=https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc
EOF

cat <<EOF > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# 3. 安装 Surface 核心组件 (包含缺失的固件包)
dnf install -y --refresh --allowerasing \
    iptsd \
    surface-ipts-firmware \
    libwacom-surface \
    libwacom-surface-data \
    surface-secureboot \
    code

# 4. 强制启用服务
systemctl enable iptsd.service

# 5. 彻底清理非 Surface 内核，确保启动项唯一
echo "Cleaning up non-surface kernels..."
# 获取当前安装的 surface 内核版本号
KERNEL_VERSION=$(rpm -q kernel-surface --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | head -n 1)
# 删除 /usr/lib/modules 下除此版本外的所有文件夹
find /usr/lib/modules -maxdepth 1 -mindepth 1 -not -name "$KERNEL_VERSION" -exec rm -rf {} +
depmod -a "$KERNEL_VERSION"

# 6. 禁用冲突仓库
dnf config-manager --set-disabled terra-mesa || true
sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/terra*.repo || true
