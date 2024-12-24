echo "Start BRS Test..."   

QEMU_IMG_RUN="$(pwd)"  

if [[ ! -f $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE.fd || ! -f $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS.fd ]]; then  
    echo "error: Can't find .fd files£¬run the compilation steps to generate them."  
    exit 1  
fi  

# Copy .fd files  
cp $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE.fd $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE_32M.fd  
cp $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS.fd $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS_32M.fd  
   
# Modify the size of the .fd file  
truncate -s 32M $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE_32M.fd  
truncate -s 32M $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS_32M.fd  
    
# Run QEMU  
/mnt/hdd/finsh/Qemu-rvsp/qemu/build/qemu-system-riscv64 \
    -nographic -m 8G -smp 32 \
    -machine rvsp-ref,pflash0=pflash0,pflash1=pflash1 \
    -blockdev node-name=pflash0,driver=file,read-only=on,filename=$QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE_32M.fd \
    -blockdev node-name=pflash1,driver=file,filename=$QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS_32M.fd \
    -bios $QEMU_IMG_RUN/opensbi/build/platform/generic/firmware/fw_dynamic.bin \
    -drive file=$QEMU_IMG_RUN/riscv-linux/linux_image.img,if=ide,format=raw
    #-device qemu-xhci \
    #-device virtio-rng-pci   

echo "BRS test completed."