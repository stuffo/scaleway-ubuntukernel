Run standard Ubuntu Kernels on Scaleway x86_64 Ubuntu instances
===============================================================

Quick Install
=============
1. You need a Scaleway base kernel that has KEXEC support. E.g. 4.8.14 std #2. You can adjust this via
   the bootscript setting in the Advanced section of the cloud.scaleway.com interface.
2. Install some Ubuntu kernel. E.g. current kernels from http://kernel.ubuntu.com/~kernel-ppa/mainline
3. Install kexec-tools package and disable kexec, otherwise kexec gets executed to early:
   ``systemctl disable kexec.service``
4. Copy ubuntukernel-load.sh to /usr/bin/ 
5. Copy ubuntukernel-load.service to /etc/systemd/system/
6. Enable ubuntukernel-load.service:
   ``systemctl enable ubuntukernel-load.service``
7. Reboot. System will reboot with the Scaleway kernel and kexec into the Ubuntu kernel while booting.

TODO
====
* create deb package
* automatically determine scaleway initrd version
* account scaleway initrd version for automatic initrd regeneration on change


