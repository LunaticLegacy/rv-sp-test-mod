cp ./RISCV_VIRT_VARS.fd ./RISCV_VIRT_VARS_32M.fd
truncate -s 32M ./RISCV_VIRT_VARS_32M.fd
echo "VARS completed."

cp ./RISCV_VIRT_CODE.fd ./RISCV_VIRT_CODE_32M.fd
truncate -s 32M ./RISCV_VIRT_CODE_32M.fd
echo "CODE completed."