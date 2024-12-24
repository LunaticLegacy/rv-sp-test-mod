#!/bin/bash  

# Prompt the user to choose an action.  
echo "Please choose the step to execute from the following options:"  
echo "1. Clone Git code"  
echo "2. Set environment variables"  
echo "3. Compile tools (BaseTools)"  
echo "4. Specify platform firmware compilation"   
echo "5. Compile OpenSBI"
echo "6. Compile QEMU RVSP-REF Platform"  
echo "7. Run QEMU"  
echo "8. Execute all"  
read -p "Please enter an option (1-8): " option  

# 1. Clone Git Code  
if [[ "$option" == "1" || "$option" == "8" ]]; then  
    echo "Step 1: Cloning Git Code..."  
    
    # Clone edk2 repository  
    git clone https://github.com/tianocore/edk2.git || { echo "Failed to clone edk2"; exit 1; }  
    cd edk2 || { echo "Can't enter edk2 directory"; exit 1; }  
    git submodule update --init || { echo "Failed to update edk2 submodules"; exit 1; }  
    cd ..  

    # Clone the edk2-platforms repository and switch branches   
    git clone https://github.com/AII-SDU/edk2-platforms.git || { echo "Failed to clone edk2-platforms"; exit 1; }  
    cd edk2-platforms || { echo "Can't enter edk2-platforms directory"; exit 1; }  
    git submodule update --init || { echo "Failed to update edk2-platforms submodules"; exit 1; }  
    git checkout riscv-server-platform || { echo "Failed to switch riscv-server-platform branch"; exit 1; }  
    cd ..  

    echo "Git code clone completed."  
fi  

# 2. Set environment variables
if [[ "$option" == "2" || "$option" == "8" ]]; then  
    echo "Step 2: Setting environment variables..."  
    
    export WORKSPACE="$(pwd)"  
    export GCC5_RISCV64_PREFIX="riscv64-linux-gnu-"  
    export PACKAGES_PATH="$WORKSPACE/edk2:$WORKSPACE/edk2-platforms"  
    export EDK2_PATH="$WORKSPACE/edk2"  
    export EDK2_PLATFORMS_PATH="$WORKSPACE/edk2-platforms"  
    
    # Here you can add more environment variables as needed  
    export PATH="$PATH:$EDK2_PATH/Tools"  
    
    echo "Environment variables set completed"  
    echo "WORKSPACE: $WORKSPACE"  
    echo "GCC5_RISCV64_PREFIX: $GCC5_RISCV64_PREFIX"  
    echo "PACKAGES_PATH: $PACKAGES_PATH"  
    echo "EDK2_PATH: $EDK2_PATH"  
    echo "EDK2_PLATFORMS_PATH: $EDK2_PLATFORMS_PATH"  
fi  

# 3. Compile tools (BaseTools)  
if [[ "$option" == "3" || "$option" == "8" ]]; then  
    echo "Step 3: Start compiling of tools (BaseTools)..."  

    original_dir=$(pwd)  
    
    cd "$EDK2_PATH" || { echo "Failed to enter edk2 directory"; exit 1; }  

    # Check if the BaseTools directory exists.  
    if [[ ! -d "BaseTools" ]]; then  
        echo "Error: The BaseTools directory does not exist. Please ensure that EDK2 has been successfully cloned."  
        exit 1  
    fi  

    # Temporarily set to not exit, to capture errors.  
    set +e   
    make -C BaseTools clean || { echo "Failed to clean BaseTools"; }  
    make -C BaseTools || { echo "Failed to compile BaseTools"; }  
    set -e  # Restore error checking  
    
    echo "BaseTools compile complete"  

    cd "$original_dir" || { echo "Unable to return to the original directory"; exit 1; }  
fi  

# 4. Compile of specified platform firmware 
if [[ "$option" == "4" || "$option" == "8" ]]; then  
    echo "Step 4: Start compiling of specified platform firmware..."  

    original_dir=$(pwd)  
    
    cd "$EDK2_PATH" || { echo "Failed to enter edk2 directory"; exit 1; }  

    if [[ -f edksetup.sh ]]; then  
        source edksetup.sh || { echo "Failed to set compile environment. "; exit 1; }  
    else  
        echo "Warning: edksetup.sh file does not exist, unable to set up the compilation environment."  
        echo "Please ensure this operation is performed in the edk2 directory."  
        exit 1  
    fi  

    # Temporarily set to not exit, to capture errors.  
    set +e   
    build -a RISCV64 -t GCC5 -p Platform/Qemu/RiscVQemuServerPlatform/RiscVQemuServerPlatform.dsc || { echo "Failed to compile platform firmware"; }  
    set -e  # Restore error checking  

    echo "Specified platform firmware compilation completed"  
    cd "$original_dir" || { echo "Unable to return to the original directory"; exit 1; }  
fi  

# 5. Compile OpenSBI  
if [[ "$option" == "5" || "$option" == "8" ]]; then  
    echo "Step 5: Start Compiling OpenSBI..."  
    
    original_dir=$(pwd)  

    if [[ ! -d "$WORKSPACE/opensbi" ]]; then  
        git clone https://github.com/riscv-software-src/opensbi.git "$WORKSPACE/opensbi" || { echo "Failed to clone OpenSBI"; exit 1; }  
    fi  

    cd "$WORKSPACE/opensbi" || { echo "Failed to enter OpenSBI directory"; exit 1; }  

    # Temporarily set to not exit, to capture errors.  
    set +e   
    make PLATFORM=generic CROSS_COMPILE=riscv64-linux-gnu- PLATFORM_RISCV_XLEN=64 || { echo "Failed to compile OpenSBI"; }  
    set -e  # Restore error checking   

    echo "OpenSBI compile complete"  
    cd "$original_dir" || { echo "Unable to return to the original directory"; exit 1; }  
fi  

# 6. Compile QEMU
if [[ "$option" == "6" || "$option" == "8" ]]; then  
    echo "Step 6: Start Compiling QEMU..."
    
    original_dir=$(pwd)
    
    if [[ ! -d "$WORKSPACE/qemu" ]]; then  
        git clone -b qemu-rv64-server-platfrom --single-branch https://github.com/AII-SDU/qemu.git "$WORKSPACE/qemu"     || { echo "Failed to clone qemu"; exit 1; }  
    fi
    
    cd "$WORKSPACE/qemu" || { echo "Failed to enter qemu directory"; exit 1; }

    mkdir $WORKSPACE/qemu/build
    cd "$WORKSPACE/qemu/build"
    $WORKSPACE/qemu/configure --disable-werror --target-list=riscv64-softmmu
    
    # Temporarily set to not exit, to capture errors.
    set +e
    make -j $(nproc) || { echo "Failed to compile QEMU"; }
    set -e # Restore error checkinge
    
    echo "QEMU compile complete."
    cd "$original_dir" || { echo "Failed to return to the original directory"; exit 1; } 
fi

# 7. Run QEMU  
if [[ "$option" == "9" || "$option" == "8" ]]; then  
    echo "Step 8: Start Running QEMU..."   

    QEMU_IMG_RUN="$(pwd)"  

    if [[ ! -f $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE.fd || ! -f $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS.fd ]]; then  
        echo "error: Can't find .fd files，run the compilation steps to generate them."  
        exit 1  
    fi  

    # Copy .fd files  
    cp $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE.fd $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE_32M.fd  
    cp $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS.fd $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS_32M.fd  
   
    # Modify the size of the .fd file  
    truncate -s 32M $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE_32M.fd  
    truncate -s 32M $QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS_32M.fd  
    
    # Run QEMU  
    $WORKSPACE/qemu/build/qemu-system-riscv64 \
        -nographic -m 8G -smp 32 \
        -machine rvsp-ref,pflash0=pflash0,pflash1=pflash1 \
        -blockdev node-name=pflash0,driver=file,read-only=on,filename=$QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE_32M.fd \
        -blockdev node-name=pflash1,driver=file,filename=$QEMU_IMG_RUN/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS_32M.fd \
        -bios $QEMU_IMG_RUN/opensbi/build/platform/generic/firmware/fw_dynamic.bin \
        -drive file=$QEMU_IMG_RUN/riscv-linux/linux_image.img,if=ide,format=raw
        #-device qemu-xhci \
        #-device virtio-rng-pci   

    echo "QEMU execution completed."  
fi  

echo "Script execution completed."
