## What had I done?

- I rebuild a EDK2 by myself and there's no need file fw_payload.bin to boot into Linux system.
- I compiled the kernel via repo [OpenCloud OS](https://gitee.com/OpenCloudOS/OpenCloudOS-Kernel.git) and built a filesystem via **Buildroot** based on **systemd**.
- Then I combined them all into a single .img file and written a script for boot it (after QEMU had been compiled within method in file rvsp_linux_img_build.sh.)
- Due to I cannot upload the single large file into GitHub, here is the link for download file `luna_oc_riscv_6.6.94.img`: [Baidu Drive](https://pan.baidu.com/s/1bzZyqOYYnpddg5GJRwVJiw?pwd=265n)

## How to use the provided .img file?

1. Build QEMU via method provided in file [rvsp_linux_img_build.sh](rvsp_linux_img_build.sh).
2. Run my command in [qemu_run.sh](qemu_run.sh).

- Login within: username: `root`, password: `LaLuna`.
- This .img file is still WIP and the functions in the released file was **STILL NOT** fit for release version of a real OS.
- I'm now about to add something including GCC compiler and dnf package manager into this and find an installer for this OS.
