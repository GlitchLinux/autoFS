#!/bin/bash

# AutoFS Stage 1: Dependency Download & Installation
# Downloads .deb packages from GitHub and installs them in dependency order
# Part of the AutoFS Universal Live USB File Server system

set -e

# Configuration
STAGE_VERSION="1.0"
GITHUB_REPO="GlitchLinux/autoFS"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/main"
GITHUB_API_BASE="https://api.github.com/repos/${GITHUB_REPO}"
LOG_FILE="/tmp/autofs-stage1.log"

# Working directories
WORK_DIR="/tmp/autofs-stage1"
DEB_DIR="$WORK_DIR/packages"
TEMP_DIR="$WORK_DIR/temp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }

# Stage 1 banner
show_stage_banner() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                 📦 STAGE 1: DEPENDENCIES 📦                  ║"
    echo "║                                                               ║"
    echo "║  Downloading and installing all required packages from       ║"
    echo "║  GitHub repository for universal compatibility               ║"
    echo "║                                                               ║"
    echo "║  Repository: github.com/GlitchLinux/autoFS                   ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Verify stage 1 prerequisites
check_prerequisites() {
    log "🔍 Checking Stage 1 prerequisites..."
    
    # Verify running as root
    if [[ $EUID -ne 0 ]]; then
        error "Stage 1 must be run as root for package installation"
        exit 1
    fi
    
    # Check essential commands for download
    local essential_commands=("dpkg")
    local missing_essential=()
    
    for cmd in "${essential_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_essential+=("$cmd")
        fi
    done
    
    if [[ ${#missing_essential[@]} -gt 0 ]]; then
        error "Essential commands missing: ${missing_essential[*]}"
        error "This doesn't appear to be a Debian/Ubuntu system"
        exit 1
    fi
    
    # Check/install download tools
    local download_tools=("wget" "curl" "unzip")
    local missing_tools=()
    
    for tool in "${download_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        warn "Missing download tools: ${missing_tools[*]}"
        log "Installing basic download tools..."
        
        export DEBIAN_FRONTEND=noninteractive
        if apt-get update -qq >/dev/null 2>&1 && apt-get install -y "${missing_tools[@]}" >/dev/null 2>&1; then
            success "✅ Download tools installed"
        else
            error "Failed to install download tools - check internet connection"
            exit 1
        fi
    fi
    
    success "✅ Prerequisites verified"
}

# Check system resources
check_system_resources() {
    log "💾 Checking system resources..."
    
    # Check available space in /tmp
    local available_space=$(df /tmp | awk 'NR==2 {print int($4/1024)}')
    local required_space=300  # MB
    
    if [[ $available_space -lt $required_space ]]; then
        error "Insufficient space in /tmp: ${available_space}MB (required: ${required_space}MB)"
        exit 1
    fi
    
    # Check memory
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_mem -lt 512 ]]; then
        warn "⚠️ Low memory: ${total_mem}MB (recommended: 1GB+)"
    else
        info "✅ Memory: ${total_mem}MB available"
    fi
    
    info "✅ Space: ${available_space}MB available in /tmp"
}

# Setup working directories
setup_work_environment() {
    log "📁 Setting up work environment..."
    
    # Clean up any previous attempts
    rm -rf "$WORK_DIR"
    
    # Create fresh directory structure
    mkdir -p "$DEB_DIR"
    mkdir -p "$TEMP_DIR"
    mkdir -p "$WORK_DIR/logs"
    
    info "✅ Work environment ready: $WORK_DIR"
}

# Download packages from GitHub using multiple methods
download_packages() {
    log "📥 Downloading packages from GitHub repository..."
    
    # Method 1: Try to download entire repo as zip
    if download_repo_archive; then
        return 0
    fi
    
    # Method 2: Fallback to individual file downloads
    if download_individual_packages; then
        return 0
    fi
    
    error "❌ All download methods failed"
    exit 1
}

# Method 1: Download entire repository archive
download_repo_archive() {
    log "📦 Attempting repository archive download..."
    
    local archive_urls=(
        "https://github.com/${GITHUB_REPO}/archive/refs/heads/main.zip"
        "${GITHUB_API_BASE}/zipball/main"
    )
    
    for url in "${archive_urls[@]}"; do
        local zip_file="$TEMP_DIR/autofs-repo.zip"
        
        info "Trying: $(echo "$url" | cut -d'/' -f3-5)..."
        
        # Try download with timeout and retries
        if download_file "$url" "$zip_file"; then
            # Extract archive
            if unzip -q "$zip_file" -d "$TEMP_DIR"; then
                # Find the extracted directory
                local extracted_dir=$(find "$TEMP_DIR" -name "*autoFS*" -type d | head -1)
                
                if [[ -n "$extracted_dir" ]]; then
                    # Move .deb files to package directory
                    local deb_count=0
                    while IFS= read -r -d '' deb_file; do
                        cp "$deb_file" "$DEB_DIR/"
                        ((deb_count++))
                    done < <(find "$extracted_dir" -name "*.deb" -print0)
                    
                    if [[ $deb_count -gt 0 ]]; then
                        success "✅ Repository archive: $deb_count packages extracted"
                        rm -rf "$TEMP_DIR"/* # Clean up
                        return 0
                    fi
                fi
            fi
        fi
        
        # Clean up failed attempt
        rm -f "$zip_file"
        rm -rf "$TEMP_DIR"/*
    done
    
    warn "⚠️ Repository archive download failed"
    return 1
}

# Method 2: Download individual .deb packages
download_individual_packages() {
    log "📋 Attempting individual package downloads..."
    
    # List of .deb packages from your GitHub repo
    local deb_packages=(
        "apache2-utils_2.4.62-1~deb12u2_amd64.deb"
        "avahi-daemon_0.8-10+deb12u1_amd64.deb"
        "avahi-utils_0.8-10+deb12u1_amd64.deb"
        "bridge-utils_1.7.1-1_amd64.deb"
        "btrfs-progs_6.2-1+deb12u1_amd64.deb"
        "cryptsetup-bin_2%3a2.6.1-4~deb12u2_amd64.deb"
        "curl_7.88.1-10+deb12u12_amd64.deb"
        "dnsmasq_2.90-4~deb12u1_all.deb"
        "dnsutils_1%3a9.18.33-1~deb12u2_all.deb"
        "dosfstools_4.2-1_amd64.deb"
        "e2fsprogs_1.47.0-2_amd64.deb"
        "exfat-fuse_1.3.0+git20220115-2_amd64.deb"
        "exfat-utils_1.3.0-2_amd64.deb"
        "f2fs-tools_1.15.0-1_amd64.deb"
        "fuse_2.9.9-6+b1_amd64.deb"
        "hfsplus_1.0.4-17_amd64.deb"
        "hfsprogs_540.1.linux3-6_amd64.deb"
        "htop_3.2.2-2_amd64.deb"
        "iptables_1.8.11-2_amd64.deb"
        "iptables-persistent_1.0.20_all.deb"
        "iputils-ping_3%3a20221126-1+deb12u1_amd64.deb"
        "jfsutils_1.1.15-5_amd64.deb"
        "jq_1.6-2.1_amd64.deb"
        "libnss-mdns_0.15.1-3_amd64.deb"
        "lvm2_2.03.16-2_amd64.deb"
        "mdadm_4.2-5_amd64.deb"
        "netcat-openbsd_1.219-1_amd64.deb"
        "netfilter-persistent_1.0.23_all.deb"
        "nginx-common_1.22.1-9+deb12u2_all.deb"
        "nginx-light_1.22.1-9+deb12u2_all.deb"
        "nilfs-tools_2.2.9-1_amd64.deb"
        "nmap_7.93+dfsg1-1_amd64.deb"
        "ntfs-3g_1%3a2022.10.3-1+deb12u2_amd64.deb"
        "openssh-client_1%3a9.2p1-2+deb12u7_amd64.deb"
        "parted_3.5-3_amd64.deb"
        "python3-bottle_0.12.23-1.1_all.deb"
        "python3-flask_2.2.2-3_all.deb"
        "python3-pip_23.0.1+dfsg-1_all.deb"
        "python3-requests_2.28.1+dfsg-1_all.deb"
        "reiserfsprogs_1%3a3.6.27-4_amd64.deb"
        "tcpdump_4.99.3-1_amd64.deb"
        "xfsprogs_6.1.0-1_amd64.deb"
    )
    
    local downloaded_count=0
    local failed_count=0
    local total_packages=${#deb_packages[@]}
    
    info "Downloading $total_packages individual packages..."
    
    for package in "${deb_packages[@]}"; do
        local url="$GITHUB_RAW_BASE/$package"
        local output_file="$DEB_DIR/$package"
        
        if download_file "$url" "$output_file"; then
            ((downloaded_count++))
            if [[ $((downloaded_count % 10)) -eq 0 ]]; then
                info "  Downloaded: $downloaded_count/$total_packages packages"
            fi
        else
            ((failed_count++))
        fi
    done
    
    if [[ $downloaded_count -gt 30 ]]; then  # Need majority of critical packages
        success "✅ Individual downloads: $downloaded_count packages ($failed_count failed)"
        return 0
    else
        error "❌ Individual downloads failed: only $downloaded_count/$total_packages packages"
        return 1
    fi
}

# Generic file download function with retries
download_file() {
    local url="$1"
    local output_file="$2"
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        # Try curl first
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL --connect-timeout 30 --max-time 120 --retry 2 "$url" -o "$output_file" 2>/dev/null; then
                if [[ -f "$output_file" && -s "$output_file" ]]; then
                    return 0
                fi
            fi
        fi
        
        # Try wget as fallback
        if command -v wget >/dev/null 2>&1; then
            if wget --timeout=30 --tries=2 -q "$url" -O "$output_file" 2>/dev/null; then
                if [[ -f "$output_file" && -s "$output_file" ]]; then
                    return 0
                fi
            fi
        fi
        
        # Clean up failed download
        rm -f "$output_file"
        ((attempt++))
        
        if [[ $attempt -le $max_attempts ]]; then
            sleep 2  # Brief pause before retry
        fi
    done
    
    return 1
}

# Install packages in dependency order
install_packages() {
    log "🔧 Installing packages in dependency order..."
    
    # Set non-interactive mode to avoid prompts
    export DEBIAN_FRONTEND=noninteractive
    export APT_LISTCHANGES_FRONTEND=none
    
    # Count available packages
    local total_packages=$(find "$DEB_DIR" -name "*.deb" | wc -l)
    if [[ $total_packages -eq 0 ]]; then
        error "No .deb packages found to install"
        exit 1
    fi
    
    info "Found $total_packages packages to install"
    
    # Installation phases for dependency order
    local phases=(
        "Core utilities:curl,htop,jq,parted,iputils-ping,netcat-openbsd,tcpdump"
        "System libraries:libnss-mdns,fuse"
        "Filesystem tools:e2fsprogs,dosfstools,xfsprogs,btrfs-progs,jfsutils,reiserfsprogs,f2fs-tools,nilfs-tools"
        "Storage management:cryptsetup-bin,lvm2,mdadm"
        "Filesystem drivers:ntfs-3g,exfat-fuse,exfat-utils,hfsplus,hfsprogs"
        "Network infrastructure:iptables,netfilter-persistent,iptables-persistent,bridge-utils"
        "Web server:nginx-common,nginx-light,apache2-utils"
        "Network services:avahi-daemon,avahi-utils,dnsmasq,dnsutils"
        "Python packages:python3-pip,python3-requests,python3-flask,python3-bottle"
        "Additional tools:openssh-client,nmap"
    )
    
    local total_installed=0
    local total_failed=0
    
    for phase_info in "${phases[@]}"; do
        IFS=':' read -r phase_name package_list <<< "$phase_info"
        
        log "📦 Installing: $phase_name"
        
        IFS=',' read -r -a packages <<< "$package_list"
        
        for package in "${packages[@]}"; do
            if install_single_package "$package"; then
                info "  ✅ $package"
                ((total_installed++))
            else
                warn "  ⚠️ $package (failed/optional)"
                ((total_failed++))
            fi
        done
    done
    
    # Install any remaining packages not in phases
    log "📦 Installing remaining packages..."
    for deb_file in "$DEB_DIR"/*.deb; do
        if [[ -f "$deb_file" ]]; then
            local package_name=$(dpkg-deb -f "$deb_file" Package 2>/dev/null)
            
            # Skip if already processed or installed
            if [[ -z "$package_name" ]] || dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
                continue
            fi
            
            if install_single_package "$package_name"; then
                info "  ✅ $package_name (additional)"
                ((total_installed++))
            else
                warn "  ⚠️ $package_name (additional - failed)"
                ((total_failed++))
            fi
        fi
    done
    
    success "📊 Installation summary: $total_installed installed, $total_failed failed/optional"
}

# Install a single package by name
install_single_package() {
    local package_name="$1"
    
    # Find matching .deb file
    local deb_file=$(find "$DEB_DIR" -name "${package_name}_*.deb" -o -name "${package_name}*.deb" | head -1)
    
    if [[ -z "$deb_file" || ! -f "$deb_file" ]]; then
        return 1
    fi
    
    # Check if already installed
    if dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
        return 0
    fi
    
    # Install the package
    if dpkg -i "$deb_file" >/dev/null 2>&1; then
        return 0
    else
        # Try to fix dependencies and retry
        apt-get install -f -y >/dev/null 2>&1 || true
        if dpkg -i "$deb_file" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi
}

# Fix any dependency issues
fix_dependencies() {
    log "🔧 Fixing dependency issues..."
    
    # Fix broken dependencies
    if apt-get install -f -y >/dev/null 2>&1; then
        info "✅ Dependencies resolved"
    else
        warn "⚠️ Some dependency issues may remain"
    fi
    
    # Configure packages
    if dpkg --configure -a >/dev/null 2>&1; then
        info "✅ Package configuration completed"
    else
        warn "⚠️ Some packages may need manual configuration"
    fi
}

# Verify critical installations
verify_installation() {
    log "🔍 Verifying critical package installations..."
    
    # Critical packages that must be working
    local critical_packages=(
        "nginx:nginx"
        "python3:python3"
        "iptables:iptables"
        "bridge-utils:brctl"
        "dnsmasq:dnsmasq"
        "avahi-daemon:avahi-daemon"
        "mount:mount"
        "lsblk:lsblk"
        "ntfs-3g:ntfs-3g"
    )
    
    local verification_passed=true
    local verified_count=0
    
    for item in "${critical_packages[@]}"; do
        IFS=':' read -r package command <<< "$item"
        
        if command -v "$command" >/dev/null 2>&1 || dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            info "  ✅ $package"
            ((verified_count++))
        else
            error "  ❌ $package (CRITICAL)"
            verification_passed=false
        fi
    done
    
    if [[ "$verification_passed" == "true" ]]; then
        success "✅ All $verified_count critical packages verified"
        return 0
    else
        error "❌ Critical package verification failed"
        return 1
    fi
}

# Create system directories
create_system_directories() {
    log "📁 Creating system directories..."
    
    local directories=(
        "/var/www/autofs"
        "/mnt/autofs"
        "/etc/autofs"
        "/var/log/autofs"
        "/tmp/autofs"
    )
    
    for dir in "${directories[@]}"; do
        if mkdir -p "$dir"; then
            case "$dir" in
                "/var/www/autofs")
                    chown -R www-data:www-data "$dir" 2>/dev/null || true
                    ;;
                "/mnt/autofs")
                    chmod 755 "$dir"
                    ;;
            esac
            info "  ✅ Created: $dir"
        else
            warn "  ⚠️ Failed to create: $dir"
        fi
    done
}

# Cleanup temporary files
cleanup() {
    log "🧹 Cleaning up temporary files..."
    
    # Remove work directory but keep logs
    rm -rf "$DEB_DIR"
    rm -rf "$TEMP_DIR"
    
    # Clean APT cache to save space
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoclean >/dev/null 2>&1 || true
    
    info "✅ Cleanup completed"
}

# Generate stage completion report
generate_report() {
    log "📋 Generating Stage 1 completion report..."
    
    local report_file="/tmp/autofs-stage1-report.txt"
    local installed_count=$(dpkg -l | grep -c "^ii" || echo "0")
    
    cat > "$report_file" << EOF
AutoFS Stage 1: Dependencies - Completion Report
===============================================
Completed: $(date)
Version: $STAGE_VERSION
Repository: github.com/$GITHUB_REPO

System Information:
------------------
Hostname: $(hostname)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo "Unknown")
Architecture: $(uname -m)
Memory: $(free -h | grep Mem | awk '{print $2}')

Package Installation Summary:
----------------------------
Total packages in system: $installed_count
GitHub repository packages: $(find "$DEB_DIR" -name "*.deb" 2>/dev/null | wc -l || echo "0")

Critical Components Status:
--------------------------
$(for pkg in nginx python3 iptables brctl dnsmasq; do echo "$pkg: $(command -v $pkg >/dev/null 2>&1 && echo "✅ Available" || echo "❌ Missing")"; done)

File System Support:
-------------------
$(for fs in ntfs-3g mount.exfat-fuse; do echo "$fs: $(command -v $fs >/dev/null 2>&1 && echo "✅ Available" || echo "❌ Missing")"; done)

Next Steps:
-----------
✅ Stage 1 (Dependencies) - COMPLETED
⏳ Stage 2 (Network Configuration) - Ready to run
⏳ Stage 3 (Storage Discovery) - Pending
⏳ Stage 4 (Web Server Setup) - Pending  
⏳ Stage 5 (Service Startup) - Pending

Installation Log:
----------------
$(tail -10 "$LOG_FILE" 2>/dev/null || echo "Log not available")
EOF
    
    info "📋 Report saved: $report_file"
}

# Main execution function
main() {
    local stage_start=$(date +%s)
    
    show_stage_banner
    
    log "🚀 Starting Stage 1: Dependency Installation..."
    
    # Execute stage 1 steps
    check_prerequisites
    check_system_resources
    setup_work_environment
    download_packages
    install_packages
    fix_dependencies
    create_system_directories
    
    if verify_installation; then
        success "🎉 Stage 1 completed successfully!"
    else
        error "❌ Stage 1 completed with critical errors"
        exit 1
    fi
    
    cleanup
    generate_report
    
    local stage_end=$(date +%s)
    local duration=$((stage_end - stage_start))
    
    echo
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║           🎉 STAGE 1 COMPLETE! 🎉     ║${NC}"
    echo -e "${GREEN}${BOLD}║                                            ║${NC}"
    echo -e "${GREEN}${BOLD}║  All dependencies installed success§fully! ║${NC}"
    echo -e "${GREEN}${BOLD}║                                            ║${NC}"
    echo -e "${GREEN}${BOLD}║  Duration: ${duration} seconds             ║${NC}"
    echo -e "${GREEN}${BOLD}║  Ready for Stage 2: Network Configuration  ║${NC}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════╝${NC}"
    echo
    
    # Create completion marker for master script
    cat > /tmp/.autofs-stage1-complete << EOF
$(date -Iseconds): Stage 1 completed successfully
Duration: ${duration} seconds
Method: GitHub hosted dependencies
Packages: Downloaded from GlitchLinux/autoFS repository
Status: Ready for Stage 2
EOF
    
    info "💡 Next: Run Stage 2 for network configuration"
    info "📋 Full report: $report_file"
}

# Execute main function
main "$@"
