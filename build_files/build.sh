#!/bin/bash
set -ouex pipefail

# ==============================================================================
# 1. 构建环境初始化
# ==============================================================================
export TMPDIR=/var/tmp
export KERNEL_INSTALL_SKIP_POSTTRANS=1

# ==============================================================================
# 2. 软件源与安全密钥配置
# ==============================================================================
# 导入 Microsoft 与 linux-surface 官方 GPG 密钥
rpm --import https://packages.microsoft.com/keys/microsoft.asc
rpm --import https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc

# 写入 Visual Studio Code 专属 YUM 仓库配置
cat <<EOF > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# ==============================================================================
# 3. 硬件级内核参数修复
# ==============================================================================
# 写入 bootc/ostree 内核启动参数，关闭面板自刷新 (PSR) 以解决 Surface 屏幕闪烁问题
echo "Integrating kernel arguments into image..."
mkdir -p /usr/lib/bootc/kargs.d
printf 'i915.enable_psr=0\n' > /usr/lib/bootc/kargs.d/50-surface-pro-8.kargs

# ==============================================================================
# 4. 核心驱动与依赖包物理路径声明
# ==============================================================================
# 内核主线组件 (linux-surface)
GH_RELEASE="https://github.com/linux-surface/linux-surface/releases/download/fedora-43-6.18.8-1"

# 触控与手写笔用户空间守护进程 (iptsd)
IPTSD_URL="https://github.com/linux-surface/iptsd/releases/download/v3.1.0/iptsd-3.1.0-1.fc43.x86_64.rpm"

# 硬件控制工具 (surface-control)
SURFACE_CONTROL_URL="https://github.com/linux-surface/surface-control/releases/download/v0.5.0-1/surface-control-0.5.0-1.fc43.x86_64.rpm"

# 机器主板安全启动证书签名组件 (secureboot-mok)
SECUREBOOT_URL="https://github.com/linux-surface/secureboot-mok/releases/download/20251230-1/surface-secureboot-20251230-1.fc43.noarch.rpm"

# 触控笔桌面环境硬件映射依赖 (libwacom-surface)
LIBWACOM_BASE="https://github.com/linux-surface/libwacom-surface/releases/download/v2.17.0-1"
LIBWACOM_CORE="${LIBWACOM_BASE}/libwacom-surface-2.17.0-1.fc43.x86_64.rpm"
LIBWACOM_DATA="${LIBWACOM_BASE}/libwacom-surface-data-2.17.0-1.fc43.noarch.rpm"
LIBWACOM_UTILS="${LIBWACOM_BASE}/libwacom-surface-utils-2.17.0-1.fc43.x86_64.rpm"

# ==============================================================================
# 5. 执行系统底层组件与应用安装
# ==============================================================================
dnf install -y --refresh --allowerasing \
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
    $SECUREBOOT_URL \
    $IPTSD_URL \
    $SURFACE_CONTROL_URL \
    $LIBWACOM_CORE \
    $LIBWACOM_DATA \
    $LIBWACOM_UTILS \
    code

# ==============================================================================
# 6. 核心修复：强制 udev 绑定 (针对 Surface Pro 8 优化)
# ==============================================================================
# 使用 /usr/lib/udev/rules.d 确保持久化，并锁定 hidraw0 以防止 iptsd 逻辑退出
echo "Applying Surface Pro 8 specific udev rules..."
mkdir -p /usr/lib/udev/rules.d
cat <<EOF > /usr/lib/udev/rules.d/99-iptsd-sp8-force.rules
# 强制标记 ITHC 核心节点为 systemd 单元，并自动触发模板服务
KERNEL=="hidraw0", SUBSYSTEM=="hidraw", TAG+="systemd", ENV{SYSTEMD_WANTS}+="iptsd@hidraw0.service"
EOF

# ==============================================================================
# 7. 镜像构建后期清理与优化
# ==============================================================================
KERNEL_VERSION=$(rpm -q kernel-surface --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | head -n 1)
if [ -n "$KERNEL_VERSION" ]; then
    find /usr/lib/modules -maxdepth 1 -mindepth 1 -not -name "$KERNEL_VERSION" -exec rm -rf {} +
    depmod -a "$KERNEL_VERSION"
fi

# 禁用构建环境中冗余的第三方软件源
sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/terra-extras.repo /etc/yum.repos.d/terra-mesa.repo /etc/yum.repos.d/terra.repo || true
