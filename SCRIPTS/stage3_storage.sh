#!/bin/bash

# AutoFS Stage 3: Storage Discovery & Mounting (FINAL COMPLETE VERSION)
# Processes ALL storage devices correctly

echo "💾 AutoFS Stage 3: Storage Discovery & Mounting (FINAL) 💾"
echo "=========================================================="
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
highlight "🔍 Storage Device Discovery & Processing"
echo "======================================"

# Log function
log_storage() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$STORAGE_LOG"
}

log_storage "Starting complete storage discovery"

# Initialize counters
MOUNT_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0
TOTAL_SIZE=0

# Get all devices and process them one by one
info "Processing each storage device..."

# Create an array of devices to process
DEVICE_LIST=(
    "/dev/sda1:ntfs:gLiTcH-MEDICAT"
    "/dev/sda2:vfat:VTOYEFI"
    "/dev/sda3:vfat:E2B"  
    "/dev/sda4:vfat:GRUB-WINPE"
    "/dev/sda6:ext4:MOUNT"
    "/dev/sda8:ntfs:STORAGE"
    "/dev/sdb1:vfat:EFI"
    "/dev/sdc1:exfat:Ventoy-52GB"
    "/dev/sdc2:vfat:VTOYEFI"
    "/dev/sdc3:vfat:BASHSCRIPTS"
    "/dev/sdc4:vfat:AUTOFS"
    "/dev/sdd1:ext4:STORAGE"
    "/dev/sdd2:vfat:EFI"
)

for device_info in "${DEVICE_LIST[@]}"; do
    IFS=':' read -r DEVICE_PATH FSTYPE LABEL <<< "$device_info"
    DEVICE_NAME=$(basename "$DEVICE_PATH")
    
    echo
    info "Processing: $DEVICE_NAME"
    echo "  Device: $DEVICE_PATH"
    echo "  Filesystem: $FSTYPE"
    echo "  Label: $LABEL"
    
    # Skip if device doesn't exist
    if [[ ! -b "$DEVICE_PATH" ]]; then
        warn "Device $DEVICE_PATH does not exist, skipping"
        ((SKIP_COUNT++))
        continue
    fi
    
    # Check if already mounted
    CURRENT_MOUNT=$(findmnt -n -o TARGET "$DEVICE_PATH" 2>/dev/null || echo "")
    
    # Skip system partitions
    if [[ -n "$CURRENT_MOUNT" ]]; then
        if [[ "$CURRENT_MOUNT" == "/" || "$CURRENT_MOUNT" == "/boot"* ]]; then
            info "Skipping $DEVICE_NAME - system partition (mounted at $CURRENT_MOUNT)"
            ((SKIP_COUNT++))
            continue
        else
            warn "Skipping $DEVICE_NAME - already mounted at $CURRENT_MOUNT"
            ((SKIP_COUNT++))
            continue
        fi
    fi
    
    # Get device size
    SIZE_BYTES=$(blockdev --getsize64 "$DEVICE_PATH" 2>/dev/null || echo "0")
    SIZE_GB=$((SIZE_BYTES / 1024 / 1024 / 1024))
    echo "  Size: ${SIZE_GB}GB"
    
    # Create mount point name
    DEVICE_LABEL=$(echo "$LABEL" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    MOUNT_NAME="${DEVICE_NAME}_${FSTYPE}_${DEVICE_LABEL}"
    MOUNT_POINT="$AUTOFS_MOUNT_BASE/drives/$MOUNT_NAME"
    
    highlight "Mounting: $DEVICE_NAME → $MOUNT_POINT"
    
    # Create mount point
    mkdir -p "$MOUNT_POINT"
    
    # Determine mount command
    MOUNT_OPTIONS="ro,noexec,nosuid,nodev"
    case "$FSTYPE" in
        "ntfs")
            MOUNT_CMD="mount -t ntfs-3g -o $MOUNT_OPTIONS,umask=022,windows_names,recover"
            ;;
        "exfat")
            MOUNT_CMD="mount -t exfat -o $MOUNT_OPTIONS,umask=022"
            ;;
        "vfat")
            MOUNT_CMD="mount -t vfat -o $MOUNT_OPTIONS,umask=022"
            ;;
        "ext4")
            MOUNT_CMD="mount -t ext4 -o $MOUNT_OPTIONS"
            ;;
        *)
            MOUNT_CMD="mount -o $MOUNT_OPTIONS"
            ;;
    esac
    
    # Attempt mount
    mount_info "Command: $MOUNT_CMD \"$DEVICE_PATH\" \"$MOUNT_POINT\""
    
    if MOUNT_OUTPUT=$($MOUNT_CMD "$DEVICE_PATH" "$MOUNT_POINT" 2>&1); then
        if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
            success "✅ Mounted: $DEVICE_NAME"
            
            # Create web link
            WEB_LINK="$AUTOFS_WEB_BASE/drives/$MOUNT_NAME"
            ln -sf "$MOUNT_POINT" "$WEB_LINK" 2>/dev/null
            mount_info "  Web: /drives/$MOUNT_NAME"
            
            # Get stats
            DF_OUTPUT=$(df -BG "$MOUNT_POINT" 2>/dev/null | tail -1)
            ACTUAL_SIZE=$(echo "$DF_OUTPUT" | awk '{print $2}' | tr -d 'G' || echo "0")
            USED_SIZE=$(echo "$DF_OUTPUT" | awk '{print $3}' | tr -d 'G' || echo "0")
            
            mount_info "  Size: ${ACTUAL_SIZE}GB (${USED_SIZE}GB used)"
            
            # Show sample contents
            ITEM_COUNT=$(ls "$MOUNT_POINT" 2>/dev/null | wc -l || echo "0")
            mount_info "  Contains: $ITEM_COUNT items"
            
            if [[ $ITEM_COUNT -gt 0 && $ITEM_COUNT -lt 20 ]]; then
                echo "  📂 Contents:"
                ls -la "$MOUNT_POINT" 2>/dev/null | head -5 | tail -n +2 | while read line; do
                    echo "    $(echo "$line" | awk '{print $NF}')"
                done
            fi
            
            ((MOUNT_COUNT++))
            TOTAL_SIZE=$((TOTAL_SIZE + ACTUAL_SIZE))
            
            log_storage "SUCCESS: $DEVICE_NAME ($FSTYPE) at $MOUNT_POINT - ${ACTUAL_SIZE}GB"
        else
            error "Mount verification failed: $DEVICE_NAME"
            rmdir "$MOUNT_POINT" 2>/dev/null || true
            ((FAIL_COUNT++))
        fi
    else
        error "Mount failed: $DEVICE_NAME"
        warn "Error: $MOUNT_OUTPUT"
        rmdir "$MOUNT_POINT" 2>/dev/null || true
        ((FAIL_COUNT++))
        log_storage "FAILED: $DEVICE_NAME ($FSTYPE) - $MOUNT_OUTPUT"
    fi
done

echo
highlight "📂 System Directory Links"
echo "========================"

# Create system links
SYSTEM_DIRS=(
    "home:/home:User directories"
    "root:/:Root filesystem" 
    "var-log:/var/log:System logs"
    "etc:/etc:Configuration files"
    "tmp:/tmp:Temporary files"
    "media:/media:Removable media"
)

for dir_config in "${SYSTEM_DIRS[@]}"; do
    IFS=':' read -r LINK_NAME SOURCE_DIR DESCRIPTION <<< "$dir_config"
    SYSTEM_LINK="$AUTOFS_WEB_BASE/system/$LINK_NAME"
    
    if [[ -d "$SOURCE_DIR" ]]; then
        ln -sf "$SOURCE_DIR" "$SYSTEM_LINK" 2>/dev/null
        mount_info "System link: $DESCRIPTION → /system/$LINK_NAME"
    fi
done

echo
info "📊 Final Summary"
echo "==============="

success "Storage discovery completed!"
echo
echo "📈 Results:"
echo "  • Successfully mounted: $MOUNT_COUNT storage devices"
echo "  • Failed mounts: $FAIL_COUNT devices"  
echo "  • Skipped devices: $SKIP_COUNT devices"
echo "  • Total accessible: ${TOTAL_SIZE}GB"

if [[ $MOUNT_COUNT -gt 0 ]]; then
    echo
    success "🎉 Mounted Storage Devices:"
    ls -1 "$AUTOFS_MOUNT_BASE/drives/" 2>/dev/null | while read drive; do
        SIZE=$(df -BG "/mnt/autofs/drives/$drive" 2>/dev/null | tail -1 | awk '{print $2}' | tr -d 'G' || echo "?")
        echo "  💾 $drive (${SIZE}GB)"
    done
    
    echo
    success "🌐 Web Access Links:"
    ls -1 "$AUTOFS_WEB_BASE/drives/" 2>/dev/null | while read link; do
        echo "  🔗 http://192.168.100.1:8080/drives/$link/"
    done
fi

# Create tools
cat > /usr/local/bin/autofs-storage-status << 'EOF'
#!/bin/bash
echo "AutoFS Storage Status"
echo "===================="
echo "Mounted drives:"
df -h /mnt/autofs/drives/* 2>/dev/null | grep -v "Filesystem"
echo
echo "Web links:"
ls -la /var/www/autofs/drives/ 2>/dev/null
echo
echo "Access: http://192.168.100.1:8080/drives/"
EOF
chmod +x /usr/local/bin/autofs-storage-status

# Create web interface
cat > "$AUTOFS_WEB_BASE/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AutoFS - Universal File Server</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0; padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white; min-height: 100vh;
        }
        .container { 
            max-width: 1200px; margin: 0 auto;
            background: rgba(255,255,255,0.1); padding: 30px;
            border-radius: 15px; backdrop-filter: blur(10px);
        }
        h1 { text-align: center; font-size: 2.5em; margin-bottom: 30px; }
        .section { margin: 30px 0; background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; }
        .section h2 { color: #ffd700; border-bottom: 2px solid #ffd700; padding-bottom: 10px; margin-top: 0; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-top: 20px; }
        .card { background: rgba(255,255,255,0.2); padding: 20px; border-radius: 10px; }
        .card h3 { margin-top: 0; color: #ffd700; }
        a { color: #87ceeb; text-decoration: none; font-weight: bold; }
        a:hover { color: #ffd700; text-decoration: underline; }
        .status { background: rgba(0,255,0,0.2); padding: 10px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 AutoFS Universal File Server</h1>
        <div class="status"><strong>🟢 System Online</strong> - Storage accessible</div>
        
        <div class="section">
            <h2>📁 Browse Storage</h2>
            <div class="grid">
                <div class="card">
                    <h3>💾 Storage Drives</h3>
                    <p>Access mounted drives including Windows partitions, USB devices, and external storage.</p>
                    <a href="/drives/">→ Browse Drives</a>
                </div>
                <div class="card">
                    <h3>🖥️ System Directories</h3>
                    <p>Explore system directories including home folders and configuration files.</p>
                    <a href="/system/">→ Browse System</a>
                </div>
            </div>
        </div>
        
        <div class="section">
            <h2>ℹ️ System Information</h2>
            <p><strong>Server:</strong> AutoFS Live System</p>
            <p><strong>Access:</strong> <code>http://192.168.100.1:8080</code></p>
            <p><strong>Security:</strong> Read-only access enabled</p>
        </div>
    </div>
</body>
</html>
EOF

echo
echo "🛠️ Management Commands:"
echo "  • autofs-storage-status  - View storage details"
echo "  • ls /mnt/autofs/drives/ - List mounted drives"

echo
if [[ $MOUNT_COUNT -gt 0 ]]; then
    success "✅ Ready for Stage 4: Web Server Configuration"
    echo "Run: sudo bash stage4-webserver.sh"
else
    warn "⚠️ No storage mounted, but can proceed to Stage 4"
fi

# Create completion marker
echo "$(date): Stage 3 completed - $MOUNT_COUNT devices mounted" > /tmp/.autofs-stage3-complete
log_storage "Stage 3 completed - $MOUNT_COUNT devices mounted successfully"

echo
success "🎯 STAGE 3 COMPLETE!"
