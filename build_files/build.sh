Applying Surface Pro 8 specific systemd path fix...
+ echo 'Applying Surface Pro 8 specific systemd path fix...'
+ mkdir -p /usr/lib/udev/rules.d
+ cat
++ rpm -q kernel-surface --queryformat '%{VERSION}-%{RELEASE}.mathbf{ARCH}'
++ head -n 1
error: incorrect format: unexpected }
+ KERNEL_VERSION=
+ '[' -n '' ']'
+ sed -i s/enabled=1/enabled=0/g /etc/yum.repos.d/terra-extras.repo /etc/yum.repos.d/terra-mesa.repo /etc/yum.repos.d/terra.repo
[2/2] STEP 3/4: RUN bootc container lint
error: Linting: Unexpected runtime error running lint kernel: Found multiple subdirectories in usr/lib/modules
Error: building at STEP "RUN bootc container lint": while running runtime: exit status 1
Error: Error: buildah exited with code 1
Trying to pull ghcr.io/ublue-os/bazzite-gnome:stable...
