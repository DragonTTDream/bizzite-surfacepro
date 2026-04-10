#!/bin/bash
set -ouex pipefail

# 1. 环境准备
export TMPDIR=/var/tmp
export KERNEL_INSTALL_SKIP_POSTTRANS=1

# 2. 导入密钥与配置仓库
rpm --import https://packages.microsoft.com/keys/microsoft.asc
rpm --import https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc

# 配置 VS Code 仓库
cat <<EOF > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# 3. 修复内核参数 (针对 Surface Pro 8)
echo "Integrating kernel arguments into image..."
mkdir -p /usr/lib/bootc/kargs.d
printf 'intremap=nosid i915.enable_psr=0\n' > /usr/lib/bootc/kargs.d/50-surface-pro-8.kargs

# 4. 自动获取 GitHub 最新版本号
echo "Fetching latest component versions from GitHub API..."

# 获取最新的 Fedora 43 内核标签 (例如: fedora-43-6.18.8-1)
KERNEL_TAG=$(curl -s https://api.github.com/repos/linux-surface/linux-surface/releases | grep -oP 'fedora-43-[\d\.-]+' | head -n 1)
# 提取纯版本号 (例如: 6.18.8-1)
KERNEL_VER=$(echo $KERNEL_TAG | sed 's/fedora-43-//')

# 获取最新的 iptsd 标签
IPTSD_TAG=$(curl -s https://api.github.com/repos/linux-surface/iptsd/releases/latest | grep -oP '"tag_name": "\K[^"]+')
# 获取最新的 SecureBoot 标签
SECUREBOOT_TAG=$(curl -s https://api.github.com/repos/linux-surface/secureboot-mok/releases/latest | grep -oP '"tag_name": "\K[^"]+')

# 5. 构建动态下载地址
GH_BASE="https://github.com/linux-surface"
KERNEL_URL="${GH_BASE}/linux-surface/releases/download/${KERNEL_TAG}"
IPTSD_URL="${GH_BASE}/iptsd/releases/download/${IPTSD_TAG}/iptsd-${IPTSD_TAG#v}-1.fc43.x86_64.rpm"
SECUREBOOT_URL="${GH_BASE}/secureboot-mok/releases/download/${SECUREBOOT_TAG}/surface-secureboot-${SECUREBOOT_TAG}.fc43.noarch.rpm"

# 固件包 (surface-firmware) 维持 SourceForge 稳定镜像地址，因其 GitHub 仓库不直接提供 RPM
FIRMWARE_URL="https://sourceforge.net/projects/linux-surface.mirror/files/fedora-43/surface-firmware-20250814-1.noarch.rpm/download"

# 6. 执行安装过程
dnf install -y --refresh --allowerasing \
    $KERNEL_URL/kernel-surface-${KERNEL_VER}.surface.fc43.x86_64.rpm \
    $KERNEL_URL/kernel-surface-core-${KERNEL_VER}.surface.fc43.x86_64.rpm \
    $KERNEL_URL/kernel-surface-default-watchdog-${KERNEL_VER}.surface.fc43.x86_64.rpm \
    $KERNEL_URL/kernel-surface-devel-${KERNEL_VER}.surface.fc43.x86_64.rpm \
    $KERNEL_URL/kernel-surface-devel-matched-${KERNEL_VER}.surface.fc43.x86_64.rpm \
    $KERNEL_URL/kernel-surface-modules-${KERNEL_VER}.surface.fc43.x86_64.rpm \
    $KERNEL_URL/kernel-surface-modules-core-${KERNEL_VER}.surface.fc43.x86_64.rpm \
    $KERNEL_URL/kernel-surface-modules-extra-${KERNEL_VER}.surface.fc43.x86_64.rpm \
    $KERNEL_URL/kernel-surface-modules-extra-matched-${KERNEL_VER}.surface.fc43.x86_64.rpm \
    $KERNEL_URL/kernel-surface-modules-internal-${KERNEL_VER}.surface.fc43.x86_64.rpm \
    $SECUREBOOT_URL \
    $FIRMWARE_URL \
    $IPTSD_URL \
    code

# 7. 精准清理内核模块
KERNEL_FULL_VERSION=$(rpm -q kernel-surface --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | head -n 1)
if [ -n "$KERNEL_FULL_VERSION" ]; then
    find /usr/lib/modules -maxdepth 1 -mindepth 1 -not -name "$KERNEL_FULL_VERSION" -exec rm -rf {} +
    depmod -a "$KERNEL_FULL_VERSION"
fi

# 8. 仓库清理
sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/terra-extras.repo /etc/yum.repos.d/terra-mesa.repo /etc/yum.repos.d/terra.repo || true

###############################################################################
# 备用方案 (FALLBACK STRATEGY)
# 如果 API 自动获取失败，请注释上方第 4-5 步，启用下方硬编码地址：
# KERNEL_URL="https://github.com/linux-surface/linux-surface/releases/download/fedora-43-6.18.8-1"
# KERNEL_VER="6.18.8-1"
# IPTSD_URL="https://github.com/linux-surface/iptsd/releases/download/v3.1.0/iptsd-3.1.0-1.fc43.x86_64.rpm"
# SECUREBOOT_URL="https://github.com/linux-surface/secureboot-mok/releases/download/20251230-1/surface-secureboot-20251230-1.fc43.noarch.rpm"
# FIRMWARE_URL="https://sourceforge.net/projects/linux-surface.mirror/files/fedora-43/surface-firmware-20250814-1.noarch.rpm/download"
###############################################################################
