./qemu/build/qemu-system-riscv64 \
    -m 8G -smp 8 -nographic \
    -machine rvsp-ref,pflash0=pflash0,pflash1=pflash1 \
    -blockdev node-name=pflash0,driver=file,read-only=on,filename=./uefi/RISCV_VIRT_CODE_32M.fd \
    -blockdev node-name=pflash1,driver=file,filename=./uefi/RISCV_VIRT_VARS_32M.fd \
    -drive file=./luna_oc_riscv_6.6.94.img,if=ide,format=raw
    # -drive file=./linux_image.img,if=ide,format=raw
    
    
