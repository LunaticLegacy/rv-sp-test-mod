#!/bin/bash  

# Strict mode for enhanced error handling  
set -Eeuo pipefail  

# Exception handler function  
exception_handler() {  
    local line_number="$1"  
    local command="$2"  
    local exit_status="$3"  

    echo "[Error] Command '$command' failed at line $line_number with exit status: $exit_status"  
    read -p "Continue execution? [y/n]: " continue_choice  
    if [[ "$continue_choice" =~ ^[Yy]$ ]]; then  
        return 0  
    else  
        exit "$exit_status"  
    fi  
}  

# Set up exception trapping  
trap 'exception_handler ${LINENO} "$BASH_COMMAND" $?' ERR  

# Global configuration  
PROJECT_ROOT="$(pwd)"  
CLONE_DIR="$PROJECT_ROOT/rvsp-linux-img"  
OUTPUT_DIR="$PROJECT_ROOT/rvsp-linux-img/output"  
PLATDIR_DIR="$PROJECT_ROOT/rvsp-linux-img/image_output"  # Example output directory  

# Default configuration  
LINUX_ARCH="riscv"  
LINUX_CROSS_COMPILE="riscv64-linux-gnu-"  
PARALLEL_JOBS="$(nproc)"  

# Create necessary directories  
mkdir -p "$OUTPUT_DIR" "$PLATDIR_DIR"  

# Log function  
log() {  
    local level="${2:-INFO}"  
    echo "[${level}] $1"  
}  

# Safe command execution function  
safe_execute() {  
    local command="$1"  
    local error_message="${2:-Command execution failed}"  

    if ! $command; then  
        log "$error_message" "ERROR"  
        return 1  
    fi  
}  

# Existing clone and build functions remain unchanged  
clone_repos() {  
    log "Starting repository cloning..."  
    
    mkdir -p "$CLONE_DIR"  
    cd "$CLONE_DIR" || exit 1  

    # Parallel cloning  
    {  
        safe_execute "git clone --depth 1 https://github.com/buildroot/buildroot.git"  
        safe_execute "git clone --depth 1 https://git.savannah.gnu.org/git/grub.git"  
        safe_execute "git clone --depth 1 -b acpi_b2_v2_riscv_aia_v11 https://github.com/vlsunil/linux.git"  
    } &  

    wait  
    log "Repository cloning completed"  
}

# Buildroot build function  
build_buildroot() {  
    log "Starting Buildroot build..."  
    
    local buildroot_dir="$CLONE_DIR/buildroot"   
    export ARCH=riscv  
    
    cp "$CLONE_DIR/config/buildroot_defconfig" "$buildroot_dir/configs/"   
    
    cd "$buildroot_dir"  

    make O="$OUTPUT_DIR/buildroot" buildroot_defconfig  
    make O="$OUTPUT_DIR/buildroot" -j"$PARALLEL_JOBS"   
    cp $OUTPUT_DIR/buildroot/images/rootfs.cpio $OUTPUT_DIR/buildroot/images/ramdisk-buildroot.img  
    
    log "Buildroot build completed"  
}  

# GRUB build function  
build_grub() {  
    log "Starting GRUB build..."  
    
    local grub_dir="$BUILD_DIR/grub"  
    local grub_output="$OUTPUT_DIR/grub"  
    local grub_config="$CLONE_DIR/config/grub_prefix.cfg"  
    
    mkdir -p "$grub_output"  
    cd "$grub_dir"  
    
    ./bootstrap  
    ./autogen.sh  
    
    ./configure \
        --target=riscv64-linux-gnu \
        --with-platform=efi \
        --prefix="$grub_output" \
        --disable-werror  
    
    make -j "$PARALLEL_JOBS" install  
    
    "$grub_output/bin/grub-mkimage" -v -c "$grub_config" \
        -o "$grub_output/grubriscv64.efi" -O riscv64-efi --disable-shim-lock -p "" \
        part_gpt part_msdos ntfs ntfscomp hfsplus fat ext2 normal chain \
        boot configfile linux help terminal terminfo configfile \
        lsefi search normal gettext loadenv read search_fs_file search_fs_uuid search_label \
        pgp gcry_sha512 gcry_rsa tpm  
    
    log "GRUB build completed"  
}  

# Linux kernel build function  
build_linux() {  
    log "Starting Linux kernel build..."  
    
    local linux_dir="$BUILD_DIR/linux"  
    local linux_out="$OUTPUT_DIR/linux"  
    
    mkdir -p "$linux_out"  
    cd "$linux_dir"  
    
    cp arch/riscv/configs/defconfig "$linux_out/.config"  
    
    make ARCH="$LINUX_ARCH" O="$linux_out" olddefconfig  
    make ARCH="$LINUX_ARCH" CROSS_COMPILE="$LINUX_CROSS_COMPILE" O="$linux_out" -j "$PARALLEL_JOBS"  
    
    log "Linux kernel build completed"  
}  

# Clean function  
clean_build() {  
    read -p "Are you sure you want to clean all build directories? (y/n): " confirm  
    if [[ $confirm =~ ^[yY]$ ]]; then  
        log "Starting to clean build directories..."  
        rm -rf "$BUILD_DIR"  
        rm -rf "$OUTPUT_DIR"  
        mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"  
        log "Cleanup completed"  
    else  
        log "Cleanup canceled"  
    fi  
}

#########################################################  
#  
# New Feature: Create Boot Disk Image  
#  
#########################################################  
SEC_PER_MB=$((1024 * 2))  
BLOCK_SIZE=512  

create_cfgfiles() {  
    local fatpart_name="$1"  
    mcopy -i $fatpart_name -o ${CLONE_DIR}/config/grub-buildroot.cfg ::/grub.cfg  
}  

create_fatpart() {  
    local fatpart_name="$1"  
    local fatpart_size="$2"  

    dd if=/dev/zero of=$fatpart_name bs=$BLOCK_SIZE count=$fatpart_size  
    mkfs.vfat $fatpart_name -n $fatpart_name  
    mmd -i $fatpart_name ::/EFI  
    mmd -i $fatpart_name ::/EFI/BOOT  
    mmd -i $fatpart_name ::/grub  
    mmd -i $fatpart_name ::/EFI/BOOT/debug  
    mmd -i $fatpart_name ::/EFI/BOOT/app  

    mcopy -i $fatpart_name $PLATDIR_DIR/bootriscv64.efi ::/EFI/BOOT  
    mcopy -i $fatpart_name $OUTPUT_DIR/linux/arch/riscv/boot/Image ::/  
    mcopy -i $fatpart_name $OUTPUT_DIR/buildroot/out/riscv/images/ramdisk-buildroot.img ::/  

    echo "FAT partition image creation completed"  
}

create_fatpart2() {  
    local fatpart_name="$1"  # Name  
    local fatpart_size="$2"  # Size  

    dd if=/dev/zero of=$fatpart_name bs=$BLOCK_SIZE count=$fatpart_size  
    mkfs.vfat $fatpart_name -n $fatpart_name  
    mmd -i $fatpart_name ::/acs_results  
    echo "Second FAT partition image creation completed"  
}

create_diskimage() {  
    local image_name="$1"  
    local part_start="$2"  
    local fatpart_size="$3"  
    local fatpart2_size="$4"  

    (echo n; echo 1; echo $part_start; echo +$((fatpart_size - 1));\
    echo 0700; echo w; echo y) | gdisk $image_name  
    (echo n; echo 2; echo $((part_start + fatpart_size)); echo +$((fatpart2_size - 1));\
    echo 0700; echo w; echo y) | gdisk $image_name  
}  

prepare_disk_image() {  
    echo  
    echo "-------------------------------------"  
    echo "Preparing Disk Image"  
    echo "-------------------------------------"  

    IMG_BB=linux_image.img  

    pushd $PLATDIR_DIR || exit 1  

    local FAT_SIZE_MB=512  
    local FAT2_SIZE_MB=128  
    local PART_START=$((1 * SEC_PER_MB))  
    local FAT_SIZE=$((FAT_SIZE_MB * SEC_PER_MB))  
    local FAT2_SIZE=$((FAT2_SIZE_MB * SEC_PER_MB))  

    cp $OUTPUT_DIR/grub/grubriscv64.efi $PLATDIR_DIR/bootriscv64.efi  
    dd if=/dev/zero of=part_table bs=$BLOCK_SIZE count=$PART_START  
    cat part_table > $IMG_BB  

    create_fatpart "BOOT" $FAT_SIZE  
    create_cfgfiles "BOOT"  
    cat BOOT >> $IMG_BB  

    create_fatpart2 "RESULT" $FAT2_SIZE  
    cat RESULT >> $IMG_BB  

    cat part_table >> $IMG_BB  

    create_diskimage $IMG_BB $PART_START $FAT_SIZE $FAT2_SIZE  
    cp $IMG_BB $PLATDIR  

    echo "----------------------------------------------------"  
    popd || exit 1  
}

##################################################################################


# main_menu  
main_menu() {  
    while true; do  
        echo "===== RISC-V Build Tool v1.0.0 ====="  
        echo "1. Clone All Repositories"  
        echo "2. Build Buildroot"  
        echo "3. Build GRUB"  
        echo "4. Build Linux Kernel"  
        echo "5. Prepare Boot Image"  
        echo "6. Build All"  
        echo "7. Clean Build Directories"  
        echo "8. Exit"  
        echo "============================="  

        read -p "Select an option [1-8]: " choice  
        
        case $choice in  
            1) clone_repos ;;  
            2) build_buildroot ;;  
            3) build_grub ;;  
            4) build_linux ;;  
            5) prepare_disk_image ;;  
            6)   
                clone_repos  
                build_buildroot  
                build_grub  
                build_linux  
                ;;  
            7) clean_build ;;  
            8)   
                echo "Exiting script"  
                exit 0 ;;  
            *)   
                log "Invalid option, please try again" "WARN"  
                ;;  
        esac  

        read -p "Press Enter to return to main menu..."   
    done  
}


main() {  
    if [[ $# -gt 0 ]]; then  
        case "$1" in  
            clone) clone_repos ;;           # Handle the 'clone' command  
            buildroot) build_buildroot ;;   # Handle the 'buildroot' command  
            grub) build_grub ;;             # Handle the 'grub' command  
            linux) build_linux ;;           # Handle the 'linux' command  
            prepare) prepare_disk_image ;;  # Handle the 'prepare' command  
            clean) clean_build ;;           # Handle the 'clean' command  
            *)   
                log "Unknown parameter: $1" "ERROR" 
                exit 1 ;;   
        esac  
    else  
        main_menu  # If no parameters are provided, show the main menu  
    fi  
}  

# Program entry point  
main "$@"
