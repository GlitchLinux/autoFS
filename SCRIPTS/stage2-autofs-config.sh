#!/bin/bash

# stage2-autofs-config.sh
# AutoFS Configuration Script for gLiTcH Linux
# Configures automatic filesystem detection, mounting, and network services

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/autofs"
MOUNT_BASE="/mnt/auto"
LOG_FILE="/var/log/autofs-setup.log"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root!"
        print_status "Usage: sudo $0"
        exit 1
    fi
}

# Create log file
initialize_logging() {
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    print_status "Logging to $LOG_FILE"
}

# Install autofs if not present
install_autofs() {
    print_status "Checking autofs installation..."
    
    if ! command -v automount &> /dev/null; then
        print_status "Installing autofs..."
        apt update
        apt install -y autofs
        print_success "AutoFS installed successfully"
    else
        print_success "AutoFS already installed"
    fi
}

# Create directory structure
create_directories() {
    print_status "Creating AutoFS directory structure..."
    
    # Create mount points
    mkdir -p "$MOUNT_BASE"/{usb,disk,network,cdrom}
    
    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"
    
    # Set proper permissions
    chmod 755 "$MOUNT_BASE"
    chmod -R 755 "$MOUNT_BASE"/*
    
    print_success "Directory structure created"
}

# Configure main autofs configuration
configure_autofs_main() {
    print_status "Configuring main autofs settings..."
    
    cat > /etc/auto.master << 'EOF'
# AutoFS master map for gLiTcH Linux
# Automatic filesystem detection and mounting

# USB devices and removable media
/mnt/auto/usb    /etc/auto.usb    --timeout=60 --ghost
/mnt/auto/disk   /etc/auto.disk   --timeout=60 --ghost

# Network shares
/mnt/auto/network /etc/auto.network --timeout=120 --ghost

# CD/DVD/ISO
/mnt/auto/cdrom  /etc/auto.cdrom  --timeout=60 --ghost

# Direct device access
/mnt/auto        /etc/auto.direct --timeout=60 --ghost
EOF

    print_success "Main autofs configuration created"
}

# Configure USB/removable device automounting
configure_usb_automount() {
    print_status "Configuring USB device automounting..."
    
    cat > /etc/auto.usb << 'EOF'
#!/bin/bash
# AutoFS map for USB devices
# Automatically detects and mounts USB storage devices

key="$1"

# Check if device exists
if [ ! -b "/dev/$key" ]; then
    exit 1
fi

# Get filesystem type
FSTYPE=$(blkid -o value -s TYPE "/dev/$key" 2>/dev/null)

case "$FSTYPE" in
    "vfat"|"fat32"|"fat16")
        echo "-fstype=vfat,rw,uid=1000,gid=1000,umask=0022,iocharset=utf8 :/dev/$key"
        ;;
    "ntfs")
        echo "-fstype=ntfs-3g,rw,uid=1000,gid=1000,umask=0022,windows_names :/dev/$key"
        ;;
    "ext2"|"ext3"|"ext4")
        echo "-fstype=$FSTYPE,rw,relatime :/dev/$key"
        ;;
    "exfat")
        echo "-fstype=exfat,rw,uid=1000,gid=1000,umask=0022 :/dev/$key"
        ;;
    "xfs")
        echo "-fstype=xfs,rw,relatime :/dev/$key"
        ;;
    "btrfs")
        echo "-fstype=btrfs,rw,relatime :/dev/$key"
        ;;
    "f2fs")
        echo "-fstype=f2fs,rw,relatime :/dev/$key"
        ;;
    *)
        # Try to mount as auto if filesystem type is unknown
        echo "-fstype=auto,rw :/dev/$key"
        ;;
esac
EOF

    chmod +x /etc/auto.usb
    print_success "USB automount configuration created"
}

# Configure disk device automounting
configure_disk_automount() {
    print_status "Configuring disk device automounting..."
    
    cat > /etc/auto.disk << 'EOF'
#!/bin/bash
# AutoFS map for disk devices
# Handles internal drives, partitions, and block devices

key="$1"

# Check if device exists
if [ ! -b "/dev/$key" ]; then
    exit 1
fi

# Skip if device is already mounted
if mount | grep -q "/dev/$key"; then
    exit 1
fi

# Get filesystem type and label
FSTYPE=$(blkid -o value -s TYPE "/dev/$key" 2>/dev/null)
LABEL=$(blkid -o value -s LABEL "/dev/$key" 2>/dev/null)
UUID=$(blkid -o value -s UUID "/dev/$key" 2>/dev/null)

# Skip swap partitions
if [ "$FSTYPE" = "swap" ]; then
    exit 1
fi

# Skip if it's part of LVM or RAID
if [ -n "$(echo "$key" | grep -E '(dm-|md)' )" ]; then
    # Let LVM/RAID handle these differently
    echo "-fstype=$FSTYPE,rw,relatime :/dev/$key"
    exit 0
fi

case "$FSTYPE" in
    "vfat"|"fat32"|"fat16")
        echo "-fstype=vfat,rw,uid=1000,gid=1000,umask=0022,iocharset=utf8 :/dev/$key"
        ;;
    "ntfs")
        echo "-fstype=ntfs-3g,rw,uid=1000,gid=1000,umask=0022,windows_names :/dev/$key"
        ;;
    "ext2"|"ext3"|"ext4")
        echo "-fstype=$FSTYPE,rw,relatime :/dev/$key"
        ;;
    "exfat")
        echo "-fstype=exfat,rw,uid=1000,gid=1000,umask=0022 :/dev/$key"
        ;;
    "xfs")
        echo "-fstype=xfs,rw,relatime :/dev/$key"
        ;;
    "btrfs")
        echo "-fstype=btrfs,rw,relatime :/dev/$key"
        ;;
    "f2fs")
        echo "-fstype=f2fs,rw,relatime :/dev/$key"
        ;;
    "hfsplus"|"hfs+")
        echo "-fstype=hfsplus,rw,force :/dev/$key"
        ;;
    "jfs")
        echo "-fstype=jfs,rw :/dev/$key"
        ;;
    "reiserfs")
        echo "-fstype=reiserfs,rw :/dev/$key"
        ;;
    "nilfs2")
        echo "-fstype=nilfs2,rw :/dev/$key"
        ;;
    *)
        # Try to mount as auto for unknown filesystems
        echo "-fstype=auto,rw :/dev/$key"
        ;;
esac
EOF

    chmod +x /etc/auto.disk
    print_success "Disk automount configuration created"
}

# Configure network share automounting
configure_network_automount() {
    print_status "Configuring network share automounting..."
    
    cat > /etc/auto.network << 'EOF'
#!/bin/bash
# AutoFS map for network shares
# Handles SMB/CIFS, NFS, and other network filesystems

key="$1"

# Parse the key for network share format
# Expected formats: 
# - smb-server-share (SMB/CIFS)
# - nfs-server-path (NFS)
# - ftp-server-path (FTP)

if [[ "$key" =~ ^smb-(.+)-(.+)$ ]]; then
    server="${BASH_REMATCH[1]}"
    share="${BASH_REMATCH[2]}"
    echo "-fstype=cifs,rw,uid=1000,gid=1000,iocharset=utf8,file_mode=0644,dir_mode=0755 ://$server/$share"
    exit 0
fi

if [[ "$key" =~ ^nfs-(.+)-(.+)$ ]]; then
    server="${BASH_REMATCH[1]}"
    path="${BASH_REMATCH[2]}"
    echo "-fstype=nfs,rw,soft,intr $server:/$path"
    exit 0
fi

# Default fallback
exit 1
EOF

    chmod +x /etc/auto.network
    print_success "Network automount configuration created"
}

# Configure CD/DVD/ISO automounting
configure_cdrom_automount() {
    print_status "Configuring CD/DVD/ISO automounting..."
    
    cat > /etc/auto.cdrom << 'EOF'
#!/bin/bash
# AutoFS map for CD/DVD and ISO files
# Handles optical media and ISO image mounting

key="$1"

# Handle CD/DVD devices
if [[ "$key" =~ ^(cd|dvd|sr)[0-9]+$ ]]; then
    device="/dev/$key"
    if [ -b "$device" ]; then
        # Check if there's media in the drive
        if blkid "$device" &>/dev/null; then
            FSTYPE=$(blkid -o value -s TYPE "$device" 2>/dev/null)
            case "$FSTYPE" in
                "iso9660"|"udf")
                    echo "-fstype=$FSTYPE,ro :/dev/$key"
                    ;;
                *)
                    echo "-fstype=auto,ro :/dev/$key"
                    ;;
            esac
        fi
    fi
fi

# Handle ISO files (format: iso-filename-without-extension)
if [[ "$key" =~ ^iso-(.+)$ ]]; then
    filename="${BASH_REMATCH[1]}"
    # Look for ISO file in common locations
    for dir in "/home" "/tmp" "/opt" "/media"; do
        if [ -f "$dir/$filename.iso" ]; then
            echo "-fstype=iso9660,ro,loop :$dir/$filename.iso"
            exit 0
        fi
    done
fi

exit 1
EOF

    chmod +x /etc/auto.cdrom
    print_success "CD/DVD/ISO automount configuration created"
}

# Configure direct device mapping
configure_direct_mapping() {
    print_status "Configuring direct device mapping..."
    
    cat > /etc/auto.direct << 'EOF'
# Direct AutoFS mappings
# Format: mount_point -options :device_or_path

# Examples (uncomment and modify as needed):
# /mnt/auto/backup -fstype=ext4,rw :/dev/disk/by-label/BACKUP
# /mnt/auto/data -fstype=ntfs-3g,rw,uid=1000,gid=1000 :/dev/disk/by-uuid/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
# /mnt/auto/server -fstype=nfs,rw,soft,intr :192.168.1.100:/srv/shared
EOF

    print_success "Direct mapping configuration created"
}

# Create udev rules for automatic device detection
configure_udev_rules() {
    print_status "Configuring udev rules for automatic device detection..."
    
    # Check if /dev/autofs exists and handle it
    if [ -e "/dev/autofs" ]; then
        if [ ! -d "/dev/autofs" ]; then
            print_warning "/dev/autofs exists but is not a directory, removing..."
            rm -f /dev/autofs
        fi
    fi
    
    # Create udev symlink directory
    if mkdir -p /dev/autofs/{usb,disk} 2>/dev/null; then
        print_success "Created /dev/autofs directory structure"
    else
        print_warning "Could not create /dev/autofs directories, skipping udev symlinks"
        print_status "AutoFS will work without udev symlinks"
        return 0
    fi
    
    cat > /etc/udev/rules.d/99-autofs-usb.rules << 'EOF'
# AutoFS udev rules for USB device detection
# Automatically creates symlinks for AutoFS mounting

# USB storage devices
KERNEL=="sd[a-z][0-9]*", SUBSYSTEMS=="usb", ACTION=="add", SYMLINK+="autofs/usb/$kernel"
KERNEL=="sd[a-z][0-9]*", SUBSYSTEMS=="usb", ACTION=="remove", RUN+="/bin/rm -f /dev/autofs/usb/$kernel"

# MMC/SD cards
KERNEL=="mmcblk[0-9]p[0-9]*", ACTION=="add", SYMLINK+="autofs/usb/$kernel"
KERNEL=="mmcblk[0-9]p[0-9]*", ACTION=="remove", RUN+="/bin/rm -f /dev/autofs/usb/$kernel"
EOF
    
    # Reload udev rules
    udevadm control --reload-rules
    udevadm trigger
    
    print_success "Udev rules configured"
}

# Configure systemd services
configure_systemd_services() {
    print_status "Configuring systemd services..."
    
    # The NFS-related warnings are normal - those services are only needed for NFS server functionality
    # We're only configuring NFS client functionality through autofs
    
    # Enable autofs service
    systemctl enable autofs
    
    # Create custom service for AutoFS monitoring (optional)
    cat > /etc/systemd/system/autofs-monitor.service << 'EOF'
[Unit]
Description=AutoFS Device Monitor
After=autofs.service

[Service]
Type=simple
ExecStart=/usr/local/bin/autofs-monitor
Restart=on-failure
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Create the monitoring script
    cat > /usr/local/bin/autofs-monitor << 'EOF'
#!/bin/bash
# AutoFS device monitoring script
# Monitors for new devices and updates AutoFS maps

print_log() {
    echo "$(date): $1" >> /var/log/autofs-monitor.log
}

print_log "AutoFS monitor started"

while true; do
    # Check for new USB devices every 10 seconds
    for device in /dev/sd[a-z][0-9]* 2>/dev/null; do
        if [ -b "$device" ]; then
            basename_dev=$(basename "$device")
            # Just log device detection, autofs will handle mounting on access
            if [ ! -f "/tmp/autofs-seen-$basename_dev" ]; then
                print_log "New device detected: $basename_dev"
                touch "/tmp/autofs-seen-$basename_dev"
            fi
        fi
    done
    
    # Clean up detection flags for removed devices
    for flag in /tmp/autofs-seen-*; do
        if [ -f "$flag" ]; then
            device=$(basename "$flag" | sed 's/autofs-seen-//')
            if [ ! -b "/dev/$device" ]; then
                rm -f "$flag"
                print_log "Device removed: $device"
            fi
        fi
    done
    
    # Sleep for 10 seconds before next check
    sleep 10
done
EOF

    chmod +x /usr/local/bin/autofs-monitor
    
    # Don't auto-enable the monitor service - let user decide
    print_success "Systemd services configured"
    print_status "Optional: Enable AutoFS monitor with 'systemctl enable autofs-monitor'"
}

# Create utility scripts
create_utility_scripts() {
    print_status "Creating utility scripts..."
    
    # Create mount helper script
    cat > /usr/local/bin/automount << 'EOF'
#!/bin/bash
# AutoFS mount helper script
# Usage: automount <device|network-share|iso-file>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <device|network-share|iso-file>"
    echo "Examples:"
    echo "  $0 sdb1                    # Mount USB device sdb1"
    echo "  $0 smb-192.168.1.100-share # Mount SMB share"
    echo "  $0 iso-ubuntu-20.04        # Mount ubuntu-20.04.iso"
    exit 1
fi

device="$1"

# Determine mount type and path
if [[ "$device" =~ ^sd[a-z][0-9]+$ ]]; then
    mount_path="/mnt/auto/usb/$device"
elif [[ "$device" =~ ^(hd|nvme|vd)[a-z0-9]+$ ]]; then
    mount_path="/mnt/auto/disk/$device"
elif [[ "$device" =~ ^smb- ]]; then
    mount_path="/mnt/auto/network/$device"
elif [[ "$device" =~ ^nfs- ]]; then
    mount_path="/mnt/auto/network/$device"
elif [[ "$device" =~ ^iso- ]]; then
    mount_path="/mnt/auto/cdrom/$device"
else
    echo "Error: Unknown device format '$device'"
    exit 1
fi

# Trigger automount by accessing the directory
echo "Mounting $device at $mount_path..."
if ls "$mount_path" &>/dev/null; then
    echo "Successfully mounted at $mount_path"
    ls -la "$mount_path"
else
    echo "Failed to mount $device"
    exit 1
fi
EOF

    chmod +x /usr/local/bin/automount
    
    # Create unmount helper script
    cat > /usr/local/bin/autounmount << 'EOF'
#!/bin/bash
# AutoFS unmount helper script
# Usage: autounmount <mount-point|device>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <mount-point|device>"
    exit 1
fi

target="$1"

# If it's a device name, convert to mount path
if [[ ! "$target" =~ ^/ ]]; then
    if [[ "$target" =~ ^sd[a-z][0-9]+$ ]]; then
        target="/mnt/auto/usb/$target"
    elif [[ "$target" =~ ^(hd|nvme|vd)[a-z0-9]+$ ]]; then
        target="/mnt/auto/disk/$target"
    fi
fi

# Unmount using autofs
echo "Unmounting $target..."
if umount "$target" 2>/dev/null; then
    echo "Successfully unmounted $target"
else
    echo "Warning: $target may already be unmounted or will be unmounted automatically"
fi
EOF

    chmod +x /usr/local/bin/autounmount
    
    # Create list mounts script
    cat > /usr/local/bin/autolist << 'EOF'
#!/bin/bash
# AutoFS mount list script
# Shows all available and mounted AutoFS filesystems

echo "=== AutoFS Mount Status ==="
echo

echo "Available USB devices:"
ls -1 /mnt/auto/usb/ 2>/dev/null | head -10

echo
echo "Available disk devices:"  
ls -1 /mnt/auto/disk/ 2>/dev/null | head -10

echo
echo "Active mounts:"
mount | grep "/mnt/auto" | sort

echo
echo "AutoFS status:"
systemctl status autofs --no-pager -l
EOF

    chmod +x /usr/local/bin/autolist
    
    print_success "Utility scripts created"
}

# Test AutoFS configuration
test_autofs_config() {
    print_status "Testing AutoFS configuration..."
    
    # Restart autofs service
    systemctl restart autofs
    
    # Check service status
    if systemctl is-active autofs &>/dev/null; then
        print_success "AutoFS service is running"
    else
        print_error "AutoFS service failed to start"
        systemctl status autofs --no-pager
        return 1
    fi
    
    # Test directory creation
    if [ -d "$MOUNT_BASE/usb" ] && [ -d "$MOUNT_BASE/disk" ]; then
        print_success "Mount directories created successfully"
    else
        print_error "Failed to create mount directories"
        return 1
    fi
    
    print_success "AutoFS configuration test completed"
}

# Main execution
main() {
    print_header "========================================="
    print_header "  gLiTcH Linux AutoFS Configuration"
    print_header "========================================="
    echo
    
    initialize_logging
    check_root
    
    print_status "Starting AutoFS configuration..."
    
    install_autofs
    create_directories
    configure_autofs_main
    configure_usb_automount
    configure_disk_automount
    configure_network_automount
    configure_cdrom_automount
    configure_direct_mapping
    configure_udev_rules
    configure_systemd_services
    create_utility_scripts
    test_autofs_config
    
    print_header "========================================="
    print_success "AutoFS configuration completed successfully!"
    print_header "========================================="
    echo
    print_status "Available commands:"
    echo "  automount <device>     - Mount a device"
    echo "  autounmount <device>   - Unmount a device"
    echo "  autolist               - List available devices"
    echo
    print_status "Mount points:"
    echo "  /mnt/auto/usb/         - USB devices"
    echo "  /mnt/auto/disk/        - Internal disks"
    echo "  /mnt/auto/network/     - Network shares"
    echo "  /mnt/auto/cdrom/       - CD/DVD/ISO"
    echo
    print_status "Examples:"
    echo "  ls /mnt/auto/usb/sdb1  - Auto-mount USB device sdb1"
    echo "  automount sdb1         - Mount sdb1 using helper script"
    echo "  autolist               - Show all available devices"
    echo
    print_status "Configuration logged to: $LOG_FILE"
}

# Run main function
main "$@"
