#Add some necessary functions
build_sct ()
{
  #build SCT test
  WORKSPACE="$(pwd)"

  original_dir=$(pwd)

  #rm -rf rvsp-brs-test

  #mkdir rvsp-brs-test

  #truncate -s 32M $WORKSPACE/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE_32M.fd  
  #truncate -s 32M $WORKSPACE/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS_32M.fd

  cd "$WORKSPACE/rvsp-brs-test" || { echo "Failed to enter rvsp-brs-test directory"; }

  rm -rf TEST
  mkdir TEST
  cp $WORKSPACE/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE.fd $WORKSPACE/rvsp-brs-test/TEST
  cp $WORKSPACE/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS.fd $WORKSPACE/rvsp-brs-test/TEST
  cp $WORKSPACE/opensbi/build/platform/generic/firmware/fw_dynamic.bin $WORKSPACE/rvsp-brs-test/TEST

  SCTWORKSPACE="$(pwd)"

  echo 
  echo 
  echo "-------------------------------------"
  echo         "Get Resources We Need"
  echo "-------------------------------------"
  #copy edk2 already compiled
  rm -rf $SCTWORKSPACE/edk2
  cp -r $original_dir/edk2 $SCTWORKSPACE
  pushd $SCTWORKSPACE/edk2
  git checkout 819cfc6b42a68790a23509e4fcc58ceb70e1965e
  popd

  #get edk2-test
  rm -rf $SCTWORKSPACE/edk2-test
  git clone --single-branch https://github.com/tianocore/edk2-test
  pushd $SCTWORKSPACE/edk2-test
  git checkout 81dfa8d53d4290366ae41e1f4c2ed6d6c5016c07
  popd

  #build sct
  #Define necessary path
  echo 
  echo 
  echo "-------------------------------------"
  echo           "Build SCT test"
  echo "-------------------------------------"

  arch=$(uname -m)
  UEFI_PATH=edk2
  SCT_PATH=edk2-test
  UEFI_TOOLCHAIN=GCC5
  UEFI_BUILD_MODE=DEBUG
  TARGET_ARCH=RISCV64
  KEYS_DIR=$TOP_DIR/security-interface-extension-keys
  TEST_DB1_KEY=$KEYS_DIR/TestDB1.key
  TEST_DB1_CRT=$KEYS_DIR/TestDB1.crt
  CROSS_COMPILE=$TOP_DIR/$GCC

  #insert to BRS_SCT.dsc
  sed -i 's|^SctPkg/TestCase/UEFI/EFI/RuntimeServices/SecureBoot/BlackBoxTest/SecureBootBBTest.inf|#SctPkg/TestCase/UEFI/EFI/RuntimeServices/SecureBoot/BlackBoxTest/SecureBootBBTest.inf|g' $SCTWORKSPACE/BRS_SCT.dsc
  sed -i 's|^SctPkg/TestCase/UEFI/EFI/RuntimeServices/BBSRVariableSizeTest/BlackBoxTest/BBSRVariableSizeBBTest.inf|#SctPkg/TestCase/UEFI/EFI/RuntimeServices/BBSRVariableSizeTest/BlackBoxTest /BBSRVariableSizeBBTest.inf|g' $SCTWORKSPACE/BRS_SCT.dsc
  sed -i 's|^SctPkg/TestCase/UEFI/EFI/Protocol/TCG2Protocol/BlackBoxTest/TCG2ProtocolBBTest.inf|#SctPkg/TestCase/UEFI/EFI/Protocol/TCG2Protocol/BlackBoxTest/TCG2ProtocolBBTest.inf|g' $SCTWORKSPACE/BRS_SCT.dsc
  sed -i 's|^SctPkg/TestCase/UEFI/EFI/RuntimeServices/SecureBoot/BlackBoxTest/Dependency/Images/Images.inf|#SctPkg/TestCase/UEFI/EFI/RuntimeServices/SecureBoot/BlackBoxTest/Dependency/Images/Images.inf|g'  $SCTPKG/BRS_SCT.dsc

  #start to build sct test
  pushd $SCTWORKSPACE/$SCT_PATH
  export KEYS_DIR=$SCTWORKSPACE/security-interface-extension-keys
  export EDK2_TOOLCHAIN=$UEFI_TOOLCHAIN
  export PATH="$TOP_DIR/efitools:$PATH"

export EDK2_TOOLCHAIN=$UEFI_TOOLCHAIN
export ${UEFI_TOOLCHAIN}_RISCV64_PREFIX=$CROSS_COMPILE

  # #Build base tools
  if [ ! -d $SCTWORKSPACE/$SCT_PATH/uefi-sct/edk2 ]; then
    ln -s $SCTWORKSPACE/edk2 $SCTWORKSPACE/$SCT_PATH/uefi-sct/edk2
  fi
  source $SCTWORKSPACE/$UEFI_PATH/edksetup.sh || ture
  make -C $SCTWORKSPACE/$UEFI_PATH/BaseTools

  #Copy over extra files needed for BRSI tests
  cp -r $SCTWORKSPACE/BrsBootServices uefi-sct/SctPkg/TestCase/UEFI/EFI/BootServices/
  cp -r $SCTWORKSPACE/BrsiEfiSpecVerLvl  uefi-sct/SctPkg/TestCase/UEFI/EFI/Generic/
  cp -r $SCTWORKSPACE/BrsiRequiredUefiProtocols uefi-sct/SctPkg/TestCase/UEFI/EFI/Generic/
  # cp -r $BRSI_TEST_DIR/BrsiSmbios $BRSI_TEST_DIR/BrsiSysEnvConfig uefi-sct/SctPkg/TestCase/UEFI/EFI/Generic/
  cp -r $SCTWORKSPACE/BrsiRuntimeServices uefi-sct/SctPkg/TestCase/UEFI/EFI/RuntimeServices/
  cp $SCTWORKSPACE/BRS_SCT.dsc uefi-sct/SctPkg/UEFI/
  cp $SCTWORKSPACE/build_brs.sh uefi-sct/SctPkg/

  #Startup/runtime files.
  mkdir -p uefi-sct/SctPkg/BRS
  #BRSI
  cp $SCTWORKSPACE/brsi/config/BRSIStartup.nsh uefi-sct/SctPkg/BRS/
  cp $SCTWORKSPACE/brsi/config/BRSI.seq uefi-sct/SctPkg/BRS/
  cp $SCTWORKSPACE/brsi/config/BRSI_manual.seq uefi-sct/SctPkg/BRS/
  cp $SCTWORKSPACE/brsi/config/BRSI_extd_run.seq uefi-sct/SctPkg/BRS/
  cp $SCTWORKSPACE/brsi/config/EfiCompliant_BRSI.ini  uefi-sct/SctPkg/BRS/

  if git apply --check $SCTWORKSPACE/patch/edk2-test-brs-build.patch; then
      echo "Applying edk2-test BRS build patch..."
      git apply --ignore-whitespace --ignore-space-change $SCTWORKSPACE/patch/edk2-test-brs-build.patch
  else
      echo  "Error while applying edk2-test BRS build patch..."
  fi

  pushd uefi-sct
  DSC_EXTRA="ShellPkg/ShellPkg.dsc MdeModulePkg/MdeModulePkg.dsc" ./SctPkg/build_brs.sh $TARGET_ARCH GCC ${UEFI_BUILD_MODE}  -n $PARALLELISM

  #Copy it to RISCV64_SCT
  echo "Copying sct... $VARIANT";
  # Copy binaries to output folder
  pushd $SCTWORKSPACE

  mkdir -p ${TARGET_ARCH}_SCT/SCT

  #BRSI
  mkdir -p ${TARGET_ARCH}_SCT/SCT/Dependency/EfiCompliantBBTest ${TARGET_ARCH}_SCT/SCT/Sequence
  cp -r $SCTWORKSPACE/$SCT_PATH/uefi-sct/Build/UefiSct/${UEFI_BUILD_MODE}_${UEFI_TOOLCHAIN}/SctPackage${TARGET_ARCH}/${TARGET_ARCH}/* ${TARGET_ARCH}_SCT/SCT/
  cp $SCTWORKSPACE/$SCT_PATH/uefi-sct/SctPkg/BRS/EfiCompliant_BRSI.ini ${TARGET_ARCH}_SCT/SCT/Dependency/EfiCompliantBBTest/EfiCompliant.ini
  cp $SCTWORKSPACE/$SCT_PATH/uefi-sct/SctPkg/BRS/BRSI_manual.seq ${TARGET_ARCH}_SCT/SCT/Sequence/BRSI_manual.seq
  cp $SCTWORKSPACE/$SCT_PATH/uefi-sct/SctPkg/BRS/BRSI_extd_run.seq ${TARGET_ARCH}_SCT/SCT/Sequence/BRSI_extd_run.seq
  cp $SCTWORKSPACE/$SCT_PATH/uefi-sct/SctPkg/BRS/BRSI.seq ${TARGET_ARCH}_SCT/SCT/Sequence/BRSI.seq
  cp $SCTWORKSPACE/$SCT_PATH/uefi-sct/SctPkg/BRS/BRSIStartup.nsh ${TARGET_ARCH}_SCT/SctStartup.nsh
  #BBSR
  # cp $BRS_DIR/bbsr/config/sie_SctStartup.nsh ${TARGET_ARCH}_SCT/sie_SctStartup.nsh
  # cp $BRS_DIR/bbsr/config/BBSR.seq  ${TARGET_ARCH}_SCT/SCT/Sequence
  cp $SCTWORKSPACE/edk2-test/uefi-sct/SctPkg/BRS/BRSI.seq  $SCTWORKSPACE/edk2-test/uefi-sct/Build/UefiSct/${UEFI_BUILD_MODE}_${UEFI_TOOLCHAIN}/SctPackage${TARGET_ARCH}/${TARGET_ARCH}/Sequence/
  echo "SCT package locates in $SCTWORKSPACE/${TARGET_ARCH}_SCT"

  cd $original_dir
}

package_sct ()
{
  DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
  TOP_DIR=$(pwd)/rvsp-brs-test
  PLATDIR=${TOP_DIR}/output
  OUTDIR=${PLATDIR}
  EFI_CONFIG_FILE=${TOP_DIR}/brsi/config/startup.nsh
  SCT_STARTUP_FILE=${TOP_DIR}/brsi/config/BRSIStartup.nsh
  DEBUG_CONFIG_FILE=${TOP_DIR}/brsi/config/debug_dump.nsh
  BLOCK_SIZE=512
  SEC_PER_MB=$((1024*2))
  UEFI_SHELL_PATH=edk2-test/uefi-sct/Build/Shell/DEBUG_GCC5/RISCV64/ShellPkg/Application/Shell/Shell/OUTPUT
  SCT_PATH=RISCV64_SCT
  UEFI_APPS_PATH=${TOP_DIR}/edk2-test/uefi-sct/Build/MdeModule/DEBUG_GCC5/RISCV64/MdeModulePkg/Application/CapsuleApp/CapsuleApp/OUTPUT
  original_dir=$(pwd)

  create_cfgfiles ()
  {
      local fatpart_name="$1"

      mcopy -i  $fatpart_name -o ${GRUB_BUILDROOT_CONFIG_FILE} ::/grub.cfg
      mcopy -i  $fatpart_name -o ${SCT_STARTUP_FILE}     ::/EFI/BOOT/brs/

      mcopy -i  $fatpart_name -o ${EFI_CONFIG_FILE}     ::/EFI/BOOT/
      mcopy -i  $fatpart_name -o ${DEBUG_CONFIG_FILE}    ::/EFI/BOOT/debug/

  }

  create_fatpart ()
  {
      local fatpart_name="$1"  #Name of the FAT partition disk image
      local fatpart_size="$2"  #FAT partition size (in 512-byte blocks)

      dd if=/dev/zero of=$fatpart_name bs=$BLOCK_SIZE count=$fatpart_size
      mkfs.vfat $fatpart_name -n $fatpart_name
      mmd -i $fatpart_name ::/EFI
      mmd -i $fatpart_name ::/EFI/BOOT
      mmd -i $fatpart_name ::/grub

      mmd -i $fatpart_name ::/EFI/BOOT/brs
      mmd -i $fatpart_name ::/EFI/BOOT/debug
      mmd -i $fatpart_name ::/EFI/BOOT/app

      mcopy -i $fatpart_name Shell.efi ::/EFI/BOOT

      mcopy -s -i $fatpart_name SCT/* ::/EFI/BOOT/brs
      # mcopy -i $fatpart_name ${UEFI_APPS_PATH}/CapsuleApp.efi ::/EFI/BOOT/app

      echo "FAT partition image created"
  }

  create_fatpart2 ()
  {
      local fatpart_name="$1"  #Name of the FAT partition disk image
      local fatpart_size="$2"  #FAT partition size (in 512-byte blocks)

      dd if=/dev/zero of=$fatpart_name bs=$BLOCK_SIZE count=$fatpart_size
      mkfs.vfat $fatpart_name -n $fatpart_name
      mmd -i $fatpart_name ::/acs_results
      echo "FAT partition 2 image created"
  }

  create_diskimage ()
  {
      local image_name="$1"
      local part_start="$2"
      local fatpart_size="$3"
      local fatpart2_size="$4"

      (echo n; echo 1; echo $part_start; echo +$((fatpart_size-1));\
      echo 0700; echo w; echo y) | gdisk $image_name
      (echo n; echo 2; echo $((part_start+fatpart_size)); echo +$((fatpart2_size-1));\
      echo 0700; echo w; echo y) | gdisk $image_name
  }

  prepare_disk_image ()
  {
      echo
      echo
      echo "-------------------------------------"
      echo "Preparing disk image for busybox boot"
      echo "-------------------------------------"

      IMG_BB=brs_live_image.img
      echo -e "\e[1;32m Build BRS Live Image at $PLATDIR/$IMG_BB \e[0m"

      local FAT_SIZE_MB=512
      local FAT2_SIZE_MB=128
      local PART_START=$((1*SEC_PER_MB))
      local FAT_SIZE=$((FAT_SIZE_MB*SEC_PER_MB))
      local FAT2_SIZE=$((FAT2_SIZE_MB*SEC_PER_MB))

      rm -f $PLATDIR/$IMG_BB
      mkdir -p $PLATDIR
      cp $TOP_DIR/$UEFI_SHELL_PATH/Shell.efi Shell.efi

      cp -Tr $TOP_DIR/$SCT_PATH/ SCT
      grep -q -F 'mtools_skip_check=1' ~/.mtoolsrc || echo "mtools_skip_check=1" >> ~/.mtoolsrc

      #Package images for Busybox
      rm -f $IMG_BB
      dd if=/dev/zero of=part_table bs=$BLOCK_SIZE count=$PART_START

      #Space for partition table at the top
      cat part_table > $IMG_BB

      #Create fat partition
      create_fatpart "BOOT" $FAT_SIZE
      create_cfgfiles "BOOT"
      cat BOOT >> $IMG_BB

      #Result partition
      create_fatpart2 "RESULT" $FAT2_SIZE
      cat RESULT >> $IMG_BB

      #Space for backup partition table at the bottom (1M)
      cat part_table >> $IMG_BB

      # create disk image and copy into output folder
      create_diskimage $IMG_BB $PART_START $FAT_SIZE $FAT2_SIZE
      cp $IMG_BB $PLATDIR

      #remove intermediate files
      rm -f part_table
      rm -f BOOT
      rm -f RESULT

      echo "Compressing the image : $PLATDIR/$IMG_BB"
      xz -z $PLATDIR/$IMG_BB

      if [ -f $PLATDIR/$IMG_BB.xz ]; then
          echo "Completed preparation of disk image for busybox boot"
          echo "Image path : $PLATDIR/$IMG_BB.xz"
      fi
      echo "----------------------------------------------------"
  }
  exit_fun() {
     exit 1 # Exit script
  }

  #prepare the disk image
  prepare_disk_image
  echo "You can find SCT test image under rvsp-brs-test/output."
  cd $original_dir
}

run_sct ()
{
  echo "Start SCT Test..." 

  WORKSPACE="$(pwd)"  
  original_dir="$(pwd)"

  cp -r $WORKSPACE/qemu $WORKSPACE/rvsp-brs-test/TEST
  
  #convert .fd files into 32M
  truncate -s 32M $WORKSPACE/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE.fd  
  truncate -s 32M $WORKSPACE/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS.fd

  #copy .fd files to run dir
  cp $WORKSPACE/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_CODE.fd $WORKSPACE/rvsp-brs-test/TEST  
  cp $WORKSPACE/Build/RiscVQemuServerPlatform/DEBUG_GCC5/FV/RISCV_SP_VARS.fd $WORKSPACE/rvsp-brs-test/TEST

  cd rvsp-brs-test/TEST

  QEMU_IMG_RUN="$(pwd)"  

  #copy brs_live_img we compiled to run dir
  cp $original_dir/rvsp-brs-test/output/brs_live_image.img $QEMU_IMG_RUN

  #rename .fd files
  mv RISCV_SP_CODE.fd RISCV_SP_CODE_32M.fd
  mv RISCV_SP_VARS.fd RISCV_SP_VARS_32M.fd

  if [[ ! -f $QEMU_IMG_RUN/RISCV_SP_CODE_32M.fd || ! -f $QEMU_IMG_RUN/RISCV_SP_VARS_32M.fd ]]; then  
      echo "error: Can't find .fd files, run the compilation steps to generate them."  
      #exit 1  
  fi   
    
  # Run QEMU  
  $QEMU_IMG_RUN/qemu/build/qemu-system-riscv64 \
      -nographic -m 8G -smp 32 \
      -machine rvsp-ref,pflash0=pflash0,pflash1=pflash1 \
      -blockdev node-name=pflash0,driver=file,read-only=on,filename=$QEMU_IMG_RUN/RISCV_SP_CODE_32M.fd \
      -blockdev node-name=pflash1,driver=file,filename=$QEMU_IMG_RUN/RISCV_SP_VARS_32M.fd \
      -bios $QEMU_IMG_RUN/fw_dynamic.bin \
      -drive file=$QEMU_IMG_RUN/brs_live_image.img,if=ide,format=raw
      #-device qemu-xhci \
      #-device virtio-rng-pci   
}

echo "Please choose the step to execute from the following options:"
echo "1. build SCT test"
echo "2. Package the SCT tests into a FAT file system."
echo "3. Run SCT tests on QEMU."
echo "4. Execute all"
read -p "Please enter an option (1-4): " option

#build SCT test
if [[ "$option" == "1" || "$option" == "4" ]]; then  
    echo "Step 1: Building SCT test..."
    build_sct
fi

#package SCT test
if [[ "$option" == "2" || "$option" == "4" ]]; then  
    echo "Step 2: Packaging SCT test..."
    package_sct
fi
    
#run SCR resr on QEMU
if [[ "$option" == "3" || "$option" == "4" ]]; then  
    echo "Step 3: Running SCT test..."
    run_sct
fi