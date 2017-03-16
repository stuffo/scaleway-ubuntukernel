Run standard Ubuntu Kernels on Scaleway x86_64 Ubuntu instances
===============================================================

Scaleway is great but I've grown tired of theier old home-brewed kernels with
missing modules and features. Why not use standard Ubuntu kernels instead? 
With this package you can use standard Ubuntu kernels on your Scaleway x86_64
instances by the magic of KEXEC. 

Requirements
============
Just make sure your current Scaleway kernel has KEXEC support. 
E.g. 4.8.14 std #2 bootscript. You can adjust this via the 
bootscript setting in the Advanced section of the cloud.scaleway.com interface.

Install
=======
1. Make sure your system is up-to-date and get the Ubuntu package:  
   ``curl -LO https://github.com/stuffo/scaleway-ubuntukernel/releases/download/v1.0/scaleway-ubuntukernel_1.0-1_amd64.deb ``
2. You can skip this step if you already installed any kernel package providing linux-image. 
   Otherwise, get some Ubuntu kernel. E.g. current mainline kernels from http://kernel.ubuntu.com/~kernel-ppa/mainline:  
   ``curl -LO http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.10.3/linux-image-4.10.3-041003-generic_4.10.3-041003.201703142331_amd64.deb``  
   ``apt install ./linux-image-4.10.3-041003-generic_4.10.3-041003.201703142331_amd64.deb ``
3. Install this package:  
   ``apt install ./scaleway-ubuntukernel_1.0-1_amd64.deb ``
4. Disable Ubuntu kexec service (required as Ubuntu will kexec too early and leave a dirty filesystem)  
   `` systemctl disable kexec ``
5. Reboot. That's it. Your system will kexec into your Ubuntu kernel on startup.
   
Uninstall
=========
Either remove the package or just disable the service:
``systemctl disable scaleway-ubuntukernel``

Debugging
=========
You can run ubuntukernel-load.sh manually as root. It is quite verbose. Be 
aware that your system will reboot (kexec) if all went fine.

Build
=====
Make sure you have at least build-essential and devscripts installed.

1. clone repo ``git clone https://github.com/stuffo/scaleway-ubuntukernel.git``
2. run debuild to build debian package  
   ``debuild -i -us -uc -b``

TODO
====
* account scaleway initrd version for automatic initrd regeneration on change


