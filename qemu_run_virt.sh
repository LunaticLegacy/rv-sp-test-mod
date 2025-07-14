./qemu/build/qemu-system-riscv64 \
    -machine virt,pflash0=pflash0,pflash1=pflash1,acpi=off \
    -cpu max \
    -nographic \
    -m 8G \
    -smp 8 \
    -blockdev node-name=pflash0,driver=file,read-only=on,filename=./uefi/RISCV_VIRT_CODE_32M.fd \
    -blockdev node-name=pflash1,driver=file,filename=./uefi/RISCV_VIRT_VARS_32M.fd \
    -drive file=./luna_oc_riscv_6.6.94.img,format=raw,if=virtio,index=0,media=disk

###
# Available CPUs:
#   any
#   max
#   rv64
#   rv64e
#   rv64i
#   rva22s64
#   rva22u64
#   rvsp-ref
#   shakti-c
#   sifive-e51
#   sifive-u54
#   thead-c906
#   veyron-v1
#   x-rv128
