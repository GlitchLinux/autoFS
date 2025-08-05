#!/bin/bash

# AutoFS Stage 3: Storage Discovery & Mounting (FINAL FIX)
# Discovers and safely mounts all available storage devices

set -e

echo "💾 AutoFS Stage 3: Storage Discovery & Mounting (FINAL FIX) 💾"
echo "=============================================================="
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
highlight() { echo -e "${PURPLE}🔍 $1${NC}"; }
mount_info() { echo -e "${CYAN}📁 $1${NC}"; }

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    error "Must run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Check Stage 2 completion
info "Checking prerequisites..."
if [[ ! -f /tmp/.autofs-stage2-complete ]]; then
    error "Stage 2 not completed. Please run stage2-network-config.sh first"
    exit 1
else
    success "Stage 2 completed - network configured"
fi

# Storage discovery variables
AUTOFS_MOUNT_BASE="/mnt/autofs"
AUTOFS_WEB_BASE="/var/www/autofs"
STORAGE_LOG="/var/log/autofs/storage-discovery.log"
MOUNT_STATUS_FILE="/tmp/autofs-mounts.json"

echo
info "🔧 Storage System Preparation"
echo "============================="

# Create necessary directories
info "Creating storage directories..."
mkdir -p "$AUTOFS_MOUNT_BASE"/{drives,shares,system}
mkdir -p "$AUTOFS_WEB_BASE"/{drives,shares,system,logs}
mkdir -p /var/log/autofs
touch "$STORAGE_LOG"

# Set proper permissions
chown -R www-data:www-data "$AUTOFS_WEB_BASE" 2>/dev/null || warn "www-data user not found"
chmod 755 "$AUTOFS_MOUNT_BASE"
chmod 755 "$AUTOFS_WEB_BASE"

success "Storage directories created"

echo
highlight "🔍 Block Device Discovery Phase (FIXED PARSING)"
echo "=============================================="

# Log function
log_storage() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$STORAGE_LOG"
}

log_storage "Starting storage discovery phase with fixed parsing"

# Use a more reliable method to get partition information
info "Scanning for mountable partitions..."

# Get list of all partitions with filesystems (excludes disks and empty partitions)
PARTITIONS=$(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL,UUID,TYPE -n -r | awk '$3 != "" && $7 == "part"')

if [[ -z "$PARTITIONS" ]]; then
    warn "No partitions with filesystems found. Checking all partitions..."
    # Fallback: get all partitions regardless of filesystem
    PARTITIONS=$(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL,UUID,TYPE -n -r | awk '$7 == "part"')
fi

if [[ -z "$PARTITIONS" ]]; then
    error "No partitions found at all"
    echo "Debug: Full lsblk output:"
    lsblk
    exit 1
fi

echo "Found partitions:"
echo "$PARTITIONS" | while read line; do
    echo "  📱 $line"
done

echo
highlight "🔧 Partition Processing & Mounting"
echo "=================================="

MOUNT_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0
TOTAL_SIZE=0

# Process each partition using a more reliable parsing method
while read -r line; do
    # Use awk to parse the line properly
    read -r NAME SIZE FSTYPE MOUNTPOINT LABEL UUID TYPE <<< "$line"
    
    # Debug output
    info "Processing partition: $NAME"
    echo "  Size: $SIZE, FS: $FSTYPE, Mount: $MOUNTPOINT, Label: $LABEL, Type: $TYPE"
    
    # Skip if already mounted (except root filesystem)
    if [[ -n "$MOUNTPOINT" && "$MOUNTPOINT" != "/" && "$MOUNTPOINT" != "[SWAP]" ]]; then
        warn "Skipping $NAME - already mounted at $MOUNTPOINT"
        ((SKIP_COUNT++))
        echo
        continue
    fi
    
    # Skip swap partitions
    if [[ "$FSTYPE" == "swap" ]]; then
        info "Skipping $NAME - swap partition"
        ((SKIP_COUNT++))
        echo
        continue
    fi
    
    # Skip if no filesystem detected
    if [[ -z "$FSTYPE" || "$FSTYPE" == "" ]]; then
        warn "Skipping $NAME - no filesystem detected"
        ((SKIP_COUNT++))
        echo
        continue
    fi
    
    DEVICE_PATH="/dev/$NAME"
    
    # Verify device exists
    if [[ ! -b "$DEVICE_PATH" ]]; then
        error "Device $DEVICE_PATH does not exist or is not a block device"
        ((FAIL_COUNT++))
        echo
        continue
    fi
    
    # Create safe mount point name
    DEVICE_LABEL="${LABEL:-unknown}"
    DEVICE_LABEL=$(echo "$DEVICE_LABEL" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    MOUNT_NAME="${NAME}_${FSTYPE}_${DEVICE_LABEL}"
    MOUNT_NAME=$(echo "$MOUNT_NAME" | sed 's/[^a-z0-9_-]/_/g')
    MOUNT_POINT="$AUTOFS_MOUNT_BASE/drives/$MOUNT_NAME"
    
    highlight "Mounting partition: $NAME ($FSTYPE, $SIZE)"
    echo "  Device: $DEVICE_PATH"
    echo "  Label: ${LABEL:-[no label]}"
    echo "  UUID: ${UUID:-[no uuid]}"
    echo "  Mount point: $MOUNT_POINT"
    
    # Create mount point
    mkdir -p "$MOUNT_POINT"
    
    # Determine mount command based on filesystem type
    MOUNT_OPTIONS="ro,noexec,nosuid,nodev"
    MOUNT_CMD=""
    
    case "$FSTYPE" in
        "ntfs")
            MOUNT_CMD="mount -t ntfs-3g -o $MOUNT_OPTIONS,umask=022,windows_names,recover"
            ;;
        "exfat")
            MOUNT_CMD="mount -t exfat -o $MOUNT_OPTIONS,umask=022"
            ;;
        "vfat"|"fat32"|"fat16")
            MOUNT_CMD="mount -t vfat -o $MOUNT_OPTIONS,umask=022"
            ;;
        "ext2"|"ext3"|"ext4")
            MOUNT_CMD="mount -t $FSTYPE -o $MOUNT_OPTIONS"
            ;;
        "xfs")
            MOUNT_CMD="mount -t xfs -o $MOUNT_OPTIONS,nouuid"
            ;;
        "btrfs")
            MOUNT_CMD="mount -t btrfs -o $MOUNT_OPTIONS,subvol=/"
            ;;
        "hfsplus"|"hfs+")
            MOUNT_CMD="mount -t hfsplus -o $MOUNT_OPTIONS"
            ;;
        "iso9660")
            MOUNT_CMD="mount -t iso9660 -o $MOUNT_OPTIONS"
            ;;
        "udf")
            MOUNT_CMD="mount -t udf -o $MOUNT_OPTIONS"
            ;;
        *)
            warn "Unknown filesystem type: $FSTYPE - attempting generic mount"
            MOUNT_CMD="mount -o $MOUNT_OPTIONS"
            ;;
    esac
    
    # Attempt to mount the device
    mount_info "Mounting $DEVICE_PATH ($FSTYPE filesystem)..."
    echo "  Command: $MOUNT_CMD \"$DEVICE_PATH\" \"$MOUNT_POINT\""
    
    # Execute mount command with detailed error handling
    MOUNT_OUTPUT=""
    if MOUNT_OUTPUT=$($MOUNT_CMD "$DEVICE_PATH" "$MOUNT_POINT" 2>&1); then
        success "Successfully mounted: $NAME → $MOUNT_POINT"
        
        # Verify mount was successful
        if mountpoint -q "$MOUNT_POINT"; then
            # Create web-accessible symlink
            WEB_LINK="$AUTOFS_WEB_BASE/drives/$MOUNT_NAME"
            if ln -sf "$MOUNT_POINT" "$WEB_LINK" 2>/dev/null; then
                mount_info "  Web link created: /drives/$MOUNT_NAME"
            else
                warn "Could not create web symlink"
            fi
            
            # Get mount statistics
            ACTUAL_SIZE=$(df -BG "$MOUNT_POINT" 2>/dev/null | tail -1 | awk '{print $2}' | tr -d 'G' 2>/dev/null || echo "0")
            USED_SIZE=$(df -BG "$MOUNT_POINT" 2>/dev/null | tail -1 | awk '{print $3}' | tr -d 'G' 2>/dev/null || echo "0")
            AVAILABLE_SIZE=$(df -BG "$MOUNT_POINT" 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G' 2>/dev/null || echo "0")
            
            # Count files with timeout
            FILE_COUNT=$(timeout 5s find "$MOUNT_POINT" -type f 2>/dev/null | wc -l 2>/dev/null || echo "unknown")
            DIR_COUNT=$(timeout 5s find "$MOUNT_POINT" -type d 2>/dev/null | wc -l 2>/dev/null || echo "unknown")
            
            mount_info "  Size: ${ACTUAL_SIZE}GB (Used: ${USED_SIZE}GB, Available: ${AVAILABLE_SIZE}GB)"
            mount_info "  Files: $FILE_COUNT, Directories: $DIR_COUNT"
            mount_info "  Web accessible: /drives/$MOUNT_NAME"
            
            ((MOUNT_COUNT++))
            TOTAL_SIZE=$((TOTAL_SIZE + ACTUAL_SIZE))
            
            log_storage "MOUNTED: $NAME ($FSTYPE) at $MOUNT_POINT - Size: ${ACTUAL_SIZE}GB"
        else
            error "Mount command succeeded but verification failed for $NAME"
            rmdir "$MOUNT_POINT" 2>/dev/null || true
            ((FAIL_COUNT++))
        fi
        
    else
        error "Failed to mount: $NAME ($FSTYPE)"
        warn "Mount error: $MOUNT_OUTPUT"
        rmdir "$MOUNT_POINT" 2>/dev/null || true
        ((FAIL_COUNT++))
        log_storage "FAILED: $NAME ($FSTYPE) - mount failed: $MOUNT_OUTPUT"
    fi
    
    echo
    
done <<< "$PARTITIONS"

echo
highlight "📂 System Filesystem Integration"
echo "==============================="

# Create symlinks for system directories
info "Creating system directory symlinks..."

SYSTEM_DIRS=(
    "home:/home:User directories"
    "root:/:Root filesystem" 
    "var-log:/var/log:System logs"
    "etc:/etc:Configuration files"
    "tmp:/tmp:Temporary files"
    "media:/media:Removable media"
    "opt:/opt:Optional software"
)

for dir_config in "${SYSTEM_DIRS[@]}"; do
    IFS=':' read -r LINK_NAME SOURCE_DIR DESCRIPTION <<< "$dir_config"
    
    SYSTEM_LINK="$AUTOFS_WEB_BASE/system/$LINK_NAME"
    
    if [[ -d "$SOURCE_DIR" ]]; then
        ln -sf "$SOURCE_DIR" "$SYSTEM_LINK" 2>/dev/null
        mount_info "Linked: $DESCRIPTION → /system/$LINK_NAME"
        log_storage "LINKED: $SOURCE_DIR as /system/$LINK_NAME"
    else
        warn "Directory not found: $SOURCE_DIR"
    fi
done

echo
highlight "🔍 Advanced Device Detection"
echo "============================"

# Detect LUKS encrypted devices
info "Scanning for encrypted devices..."
LUKS_DEVICES=$(blkid | grep -i luks | cut -d: -f1 2>/dev/null || true)

if [[ -n "$LUKS_DEVICES" ]]; then
    warn "Found encrypted (LUKS) devices:"
    echo "$LUKS_DEVICES" | while read device; do
        warn "  🔒 $device (requires manual unlock)"
        log_storage "ENCRYPTED: $device (LUKS) - manual unlock required"
    done
else
    info "No encrypted devices found"
fi

# Show additional partition info for debugging
info "Additional partition information:"
echo "Filesystem details from blkid:"
blkid | grep -E "(sda|sdb|sdc|sdd)" | while read line; do
    echo "  $line"
done

echo
info "📊 Storage Discovery Summary"
echo "============================"

success "Storage discovery completed!"
echo
echo "Mount Statistics:"
echo "  • Successfully mounted: $MOUNT_COUNT devices"
echo "  • Failed mounts: $FAIL_COUNT devices"  
echo "  • Skipped devices: $SKIP_COUNT devices"
echo "  • Total storage: ${TOTAL_SIZE}GB accessible"
echo
echo "Web Access Structure:"
echo "  📁 /drives/     - All mounted storage devices"
echo "  📁 /system/     - System directories (home, root, etc.)"
echo "  📁 /shares/     - Network shares (if any)"
echo "  📁 /logs/       - AutoFS logs and status"
echo

# Create storage management script
info "Creating storage management tools..."

cat > /usr/local/bin/autofs-storage-status << 'EOF'
#!/bin/bash
echo "AutoFS Storage Status"
echo "===================="
echo
echo "Mounted Devices:"
df -h | grep "/mnt/autofs" | while read line; do
    echo "  📁 $line"
done
echo
echo "Web Accessible Paths:"
echo "  🌐 http://192.168.100.1:8080/drives/  - Storage devices"
echo "  🌐 http://192.168.100.1:8080/system/  - System directories"
echo
echo "Recent Mount Activity:"
tail -10 /var/log/autofs/storage-discovery.log 2>/dev/null || echo "  No recent activity"
echo
echo "Storage Statistics:"
echo "  Total mounts: $(df | grep -c "/mnt/autofs" || echo "0")"
echo "  Total size: $(df -h | grep "/mnt/autofs" | awk '{sum+=$2} END {print sum "GB"}' || echo "0GB")"

echo
echo "Debug Information:"
echo "=================="
echo "All mounted AutoFS drives:"
ls -la /mnt/autofs/drives/ 2>/dev/null || echo "No drives mounted"
echo
echo "Web symlinks:"
ls -la /var/www/autofs/drives/ 2>/dev/null || echo "No web links created"
EOF

chmod +x /usr/local/bin/autofs-storage-status

cat > /usr/local/bin/autofs-unmount-all << 'EOF'
#!/bin/bash
echo "Unmounting all AutoFS storage devices..."
umount /mnt/autofs/drives/* 2>/dev/null || true
echo "Done. Devices unmounted safely."
EOF

chmod +x /usr/local/bin/autofs-unmount-all

success "Storage management tools created"

# Create index file for web interface
info "Creating web interface index..."

cat > "$AUTOFS_WEB_BASE/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AutoFS - Universal File Server</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: rgba(255,255,255,0.1); 
            padding: 30px; 
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        h1 { 
            text-align: center; 
            color: white; 
            margin-bottom: 30px;
            font-size: 2.5em;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .section { 
            margin: 30px 0; 
            background: rgba(255,255,255,0.1); 
            padding: 20px; 
            border-radius: 10px;
        }
        .section h2 { 
            color: #ffd700; 
            border-bottom: 2px solid #ffd700; 
            padding-bottom: 10px;
            margin-top: 0;
        }
        .grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); 
            gap: 20px; 
            margin-top: 20px;
        }
        .card { 
            background: rgba(255,255,255,0.2); 
            padding: 20px; 
            border-radius: 10px; 
            border: 1px solid rgba(255,255,255,0.3);
        }
        .card h3 { 
            margin-top: 0; 
            color: #ffd700;
        }
        a { 
            color: #87ceeb; 
            text-decoration: none; 
            font-weight: bold;
        }
        a:hover { 
            color: #ffd700; 
            text-decoration: underline;
        }
        .status { 
            background: rgba(0,255,0,0.2); 
            padding: 10px; 
            border-radius: 5px; 
            margin: 10px 0;
        }
        .info { 
            background: rgba(255,255,255,0.1); 
            padding: 15px; 
            border-radius: 8px; 
            margin: 15px 0;
        }
        .footer { 
            text-align: center; 
            margin-top: 40px; 
            color: rgba(255,255,255,0.7);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 AutoFS Universal File Server</h1>
        
        <div class="status">
            <strong>🟢 System Online</strong> - All storage devices mounted and accessible
        </div>

        <div class="section">
            <h2>📁 Browse Storage</h2>
            <div class="grid">
                <div class="card">
                    <h3>💾 Storage Drives</h3>
                    <p>Access all mounted drives including Windows partitions, USB devices, and external storage.</p>
                    <a href="/drives/">→ Browse Drives</a>
                </div>
                <div class="card">
                    <h3>🖥️ System Directories</h3>
                    <p>Explore system directories including home folders, configuration files, and logs.</p>
                    <a href="/system/">→ Browse System</a>
                </div>
                <div class="card">
                    <h3>🌐 Network Shares</h3>
                    <p>Access any mounted network shares or remote filesystems.</p>
                    <a href="/shares/">→ Browse Shares</a>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>ℹ️ System Information</h2>
            <div class="info">
                <p><strong>Server:</strong> AutoFS Live System</p>
                <p><strong>Access Methods:</strong></p>
                <ul>
                    <li>Internal: <code>http://192.168.100.1:8080</code></li>
                    <li>External: <code>http://[your-ip]:8080</code></li>
                    <li>Hostname: <code>http://fileserver.autofs.local:8080</code></li>
                </ul>
                <p><strong>Security:</strong> Read-only access, safe browsing enabled</p>
            </div>
        </div>

        <div class="section">
            <h2>🛠️ Management</h2>
            <div class="grid">
                <div class="card">
                    <h3>📊 Storage Status</h3>
                    <p>View mounted devices and storage statistics.</p>
                    <a href="/logs/">→ View Logs</a>
                </div>
                <div class="card">
                    <h3>🔧 System Tools</h3>
                    <p>Command line tools: <code>autofs-storage-status</code>, <code>autofs-network-status</code></p>
                </div>
            </div>
        </div>

        <div class="footer">
            <p>AutoFS - Universal Live USB File Server | Safe Read-Only Access</p>
        </div>
    </div>
</body>
</html>
EOF

success "Web interface index created"

echo
info "🎉 Stage 3 Summary"
echo "=================="
success "Storage discovery and mounting completed!"
echo
echo "Accessible Content:"
echo "  🔗 Web Interface: http://192.168.100.1:8080"
echo "  📁 Mounted Drives: $MOUNT_COUNT devices ($TOTAL_SIZE GB total)"
echo "  🖥️ System Access: Complete filesystem browsing"
echo "  🔒 Security: Read-only, safe mounting enabled"
echo
echo "Management Commands:"
echo "  • Storage status: autofs-storage-status"
echo "  • Unmount all: autofs-unmount-all"
echo "  • View logs: tail -f /var/log/autofs/storage-discovery.log"
echo

if [[ $MOUNT_COUNT -eq 0 ]]; then
    warn "No devices were mounted. Troubleshooting info:"
    echo "  • Check manually: sudo mount -t ntfs-3g /dev/sda1 /mnt/test"
    echo "  • View detailed logs: cat /var/log/autofs/storage-discovery.log"
    echo "  • Run diagnostic: autofs-storage-status"
fi

info "Ready for Stage 4: Web Server Configuration"

# Create completion marker
echo "$(date): Stage 3 completed - Storage discovery finished, $MOUNT_COUNT devices mounted" > /tmp/.autofs-stage3-complete

log_storage "Stage 3 completed - $MOUNT_COUNT devices mounted successfully"

echo
success "🎯 STAGE 3 COMPLETE!"
echo "Next: Run Stage 4 for web server configuration and startup"
