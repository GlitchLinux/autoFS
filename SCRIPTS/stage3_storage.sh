💾 AutoFS Stage 3: Storage Discovery & Mounting (WORKING) 💾
============================================================

ℹ️  Checking prerequisites...
✅ Stage 2 completed - network configured

ℹ️  🔧 Storage System Preparation
=============================
ℹ️  Creating storage directories...
✅ Storage directories created

🔍 🔍 Storage Device Discovery
==========================
ℹ️  Discovering storage devices...
All detected devices:
  📱 /dev/sdb2: UUID="69831df7-2dc9-47eb-ba94-4d56cf32854c" BLOCK_SIZE="4096" TYPE="ext4" PARTLABEL="root" PARTUUID="0f6c252e-dda5-724b-8417-aaf53b424367"
  📱 /dev/sdb1: UUID="9B46-8D51" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="3c84e351-3375-b04c-9862-96091e0c3331"
  📱 /dev/sda4: LABEL_FATBOOT="GRUB-WINPE" LABEL="GRUB-WINPE" UUID="95E8-76A0" BLOCK_SIZE="512" TYPE="vfat" PARTLABEL="Basic data partition" PARTUUID="698aa07b-d979-4fcc-959c-9bd3f3b522c4"
  📱 /dev/sda2: SEC_TYPE="msdos" LABEL_FATBOOT="VTOYEFI" LABEL="VTOYEFI" UUID="223C-F3F8" BLOCK_SIZE="512" TYPE="vfat" PARTLABEL="VTOYEFI" PARTUUID="df33d467-3053-431c-b770-1dfea3159d98"
  📱 /dev/sda3: SEC_TYPE="msdos" LABEL_FATBOOT="E2B" LABEL="E2B" UUID="1EF6-9526" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="7b60e5fa-358c-40ad-9155-9a8326f004bc"
  📱 /dev/sda1: LABEL="gLiTcH-MEDICAT" BLOCK_SIZE="512" UUID="7829F1842A616502" TYPE="ntfs" PARTLABEL="Basic data partition" PARTUUID="9b5779ca-655a-44be-b41d-784118d88d1e"
  📱 /dev/sda8: LABEL="STORAGE" BLOCK_SIZE="512" UUID="A260A7D860A7B209" TYPE="ntfs" PARTUUID="cca0ddbc-3ed3-46c9-8980-fa289f006888"
  📱 /dev/sda6: LABEL="MOUNT" UUID="6ac58656-37d6-4011-a001-e48ed69aefb4" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="60af5b7b-0886-47da-a47e-49e7986941ea"
  📱 /dev/sdd2: SEC_TYPE="msdos" UUID="A664-2C16" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="38045526-02"
  📱 /dev/sdd1: LABEL="STORAGE" UUID="2938b565-382f-41ba-b192-dc69700eae9d" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="38045526-01"
  📱 /dev/sdc2: SEC_TYPE="msdos" LABEL_FATBOOT="VTOYEFI" LABEL="VTOYEFI" UUID="626B-4255" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="eb1e0f9e-02"
  📱 /dev/sdc3: LABEL="BASHSCRIPTS" UUID="F8C7-33BF" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="eb1e0f9e-03"
  📱 /dev/sdc1: LABEL="Ventoy-52GB" UUID="6D9B-6A7D" BLOCK_SIZE="512" TYPE="exfat" PTTYPE="dos" PARTUUID="eb1e0f9e-01"
  📱 /dev/sdc4: SEC_TYPE="msdos" LABEL_FATBOOT="AUTOFS" LABEL="AUTOFS" UUID="B9BA-2EA9" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="eb1e0f9e-04"
  📱 /dev/sdb3: PARTLABEL="BIOS-GRUB" PARTUUID="206981c6-923a-4255-998f-055a265b9f66"

🔍 🔧 Processing Non-System Storage Devices
=======================================
ℹ️  Skipping sdb2 - system partition (mounted at /)
Press [Enter] to close...
