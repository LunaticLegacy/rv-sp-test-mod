# rv-sp-test-mod
Introduction
Used to build the standard rv-server-platform uefi test platform script

How To Build：
1、Download the rv-sp-test-mod repository enter this directory:
git clone https://github.com/AII-SDU/rv-sp-test-mod.git
cd rv-sp-test-mod

2、Run build_rvsp.sh，starting to build components you need：
. build_rvsp.sh
There are 8 choices in this script：
1) Clone edk2 and edk2-platform
2) Set environment variables
3) Compile tools (BaseTools)
4) Compile of specified platform firmware
5) Compile OpenSBI
6) Compile QEMU
7) Brs test on QEMU
8) Compile all components
You can choose components you need to compile.