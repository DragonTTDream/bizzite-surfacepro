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
# 拷贝所有 MSHW 固件文件夹到系统固件目录
cp -r /tmp/surface-ipts-firmware-master/firmware/intel/ipts/* /usr/lib/firmware/intel/ipts/

# 5. 基于 GitHub Assets 的物理路径安装 (10个内核包 + 安全启动补丁 + VS Code)
GH_RELEASE="https://github.com/linux-surface/linux-surface/releases/download/fedora-43-6.18.8-1"

dnf clean all
# 直接安装物理 RPM 包，避免受损的仓库索引干扰
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
    https://pkg.surfacelinux.com/fedora/f42/surface-secureboot-20251230-1.fc42.noarch.rpm \
    code \
    iptsd

# 6. 精准清理内核模块 (解决 bootc lint 报错)
# 获取当前刚安装的唯一 Surface 内核版本号
KERNEL_VERSION=$(rpm -q kernel-surface --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | head -n 1)

if [ -n "$KERNEL_VERSION" ]; then
    echo "Cleaning up redundant kernels to satisfy bootc lint..."
    # 强制删除 /usr/lib/modules 目录下除 KERNEL_VERSION 以外的所有内容
    find /usr/lib/modules -maxdepth 1 -mindepth 1 -not -name "$KERNEL_VERSION" -exec rm -rf {} +
    # 重新生成该内核的依赖映射
    depmod -a "$KERNEL_VERSION"
else
    echo "Error: kernel-surface version could not be determined." && exit 1
fi

# 7. 禁用冗余仓库 (修正 DNF5 语法，改用 sed 直接操作配置文件)
sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/terra-extras.repo /etc/yum.repos.d/terra-mesa.repo /etc/yum.repos.d/terra.repo || true
