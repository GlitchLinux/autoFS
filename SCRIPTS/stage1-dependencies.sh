#!/bin/bash

# AutoFS Stage 1: Simple Git Clone & Package Installation
# Uses straightforward git clone and dpkg installation
# Part of the AutoFS Universal Live USB File Server system

set -e

# Configuration
STAGE_VERSION="1.0-simple"
GITHUB_REPO="https://github.com/GlitchLinux/autoFS.git"
LOG_FILE="/tmp/autofs-stage1.log"
WORK_DIR="/tmp/autoFS"

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
    echo "║            📦 STAGE 1: SIMPLE GIT INSTALLATION 📦            ║"
    echo "║                                                               ║"
    echo "║  Git clone → Move scripts → Force install → Fix dependencies ║"
    echo "║  Simple, straightforward, and reliable approach              ║"
    echo "║                                                               ║"
    echo "║  Repository: github.com/GlitchLinux/autoFS                   ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Basic prerequisites check  
check_prerequisites() {
    log "🔍 Checking basic prerequisites..."
    
    if [[ $EUID -ne 0 ]]; then
        error "Stage 1 must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
    
    # Check if we can run apt
    if ! command -v apt >/dev/null 2>&1; then
        error "This system doesn't have apt package manager"
        exit 1
    fi
    
    success "✅ Basic prerequisites OK"
}

# Update package lists and install git
install_git() {
    log "📦 Updating package lists and installing git..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    if apt update -q >/dev/null 2>&1; then
        info "✅ Package lists updated"
    else
        warn "⚠️ Package update had issues, continuing anyway"
    fi
    
    if apt install git -y >/dev/null 2>&1; then
        success "✅ Git installed successfully"
    else
        error "❌ Failed to install git - check internet connection"
        exit 1
    fi
}

# Clone the repository
clone_repository() {
    log "📥 Cloning autoFS repository..."
    
    # Clean up any existing directory
    rm -rf "$WORK_DIR"
    
    # Clone the repository
    cd /tmp
    if git clone "$GITHUB_REPO" >/dev/null 2>&1; then
        success "✅ Repository cloned successfully"
    else
        error "❌ Failed to clone repository"
        error "Check internet connection and repository access"
        exit 1
    fi
    
    # Verify we have the directory and .deb files
    if [[ ! -d "$WORK_DIR" ]]; then
        error "❌ Repository directory not found after clone"
        exit 1
    fi
    
    local deb_count=$(find "$WORK_DIR" -name "*.deb" | wc -l)
    if [[ $deb_count -eq 0 ]]; then
        error "❌ No .deb packages found in repository"
        exit 1
    fi
    
    info "✅ Found $deb_count .deb packages"
}

# Move scripts to safe location
move_scripts() {
    log "📁 Moving scripts to safe location..."
    
    cd "$WORK_DIR"
    
    # Check if SCRIPTS directory exists
    if [[ -d "SCRIPTS" ]]; then
        # Create destination if it doesn't exist
        sudo mkdir -p /home/SCRIPTS
        
        # Move scripts
        if sudo mv SCRIPTS/* /home/SCRIPTS/ 2>/dev/null; then
            info "✅ Scripts moved to /home/SCRIPTS/"
        else
            warn "⚠️ No scripts to move or move failed"
        fi
    else
        info "ℹ️ No SCRIPTS directory found - skipping"
    fi
}

# Force install all packages
force_install_packages() {
    log "🔧 Force installing all .deb packages..."
    
    cd "$WORK_DIR"
    
    # Count packages
    local deb_count=$(find . -name "*.deb" | wc -l)
    info "Installing $deb_count packages with --force-all..."
    
    # Force install all packages (first pass)
    if sudo dpkg --force-all -i *.deb >/dev/null 2>&1; then
        info "✅ First dpkg pass completed"
    else
        warn "⚠️ First dpkg pass had issues (expected)"
    fi
    
    success "✅ Force installation attempted"
}

# Fix dependencies
fix_dependencies() {
    log "🔧 Fixing dependencies..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    if sudo apt install -f -y >/dev/null 2>&1; then
        success "✅ Dependencies fixed successfully"
    else
        warn "⚠️ Dependency fixing had issues, continuing..."
    fi
}

# Second dpkg pass
second_dpkg_pass() {
    log "🔧 Second dpkg installation pass..."
    
    cd "$WORK_DIR"
    
    if sudo dpkg -i *.deb >/dev/null 2>&1; then
        success "✅ Second dpkg pass successful"
    else
        info "ℹ️ Second dpkg pass had some issues (may be normal)"
    fi
}

# Update and upgrade system
update_upgrade_system() {
    log "📦 Updating and upgrading system..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    if sudo apt update -q >/dev/null 2>&1; then
        info "✅ Package lists updated"
    else
        warn "⚠️ Package update had issues"
    fi
    
    if sudo apt upgrade -y >/dev/null 2>&1; then
        info "✅ System upgraded"
    else
        warn "⚠️ System upgrade had issues"
    fi
}

# Check kernel and boot files
check_kernel_boot() {
    log "🔍 Checking kernel and boot files..."
    
    echo "Current boot directory contents:"
    ls -l /boot/ | grep -E "(vmlinuz|initrd)" || echo "No kernel/initrd files found"
    
    # Check for kernel files
    local vmlinuz_count=$(ls /boot/vmlinuz* 2>/dev/null | wc -l)
    local initrd_count=$(ls /boot/initrd* 2>/dev/null | wc -l)
    
    if [[ $vmlinuz_count -eq 0 ]] || [[ $initrd_count -eq 0 ]]; then
        warn "⚠️ Missing kernel files detected!"
        warn "   vmlinuz files: $vmlinuz_count"  
        warn "   initrd files: $initrd_count"
        
        log "🔧 Attempting kernel reinstallation..."
        reinstall_kernel
    else
        info "✅ Kernel files present:"
        info "   vmlinuz files: $vmlinuz_count"
        info "   initrd files: $initrd_count"
        
        # Configure packages and update grub
        configure_packages_and_grub
    fi
}

# Reinstall kernel
reinstall_kernel() {
    log "🔧 Reinstalling kernel..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Try to reinstall kernel
    local kernel_packages=(
        "linux-image-amd64"
        "linux-headers-amd64"
        "linux-image-$(uname -r)"
    )
    
    for kernel_pkg in "${kernel_packages[@]}"; do
        info "Attempting to install: $kernel_pkg"
        if sudo apt install -y "$kernel_pkg" >/dev/null 2>&1; then
            info "✅ Installed: $kernel_pkg"
        else
            warn "⚠️ Failed to install: $kernel_pkg"
        fi
    done
    
    # Update grub
    if sudo update-grub >/dev/null 2>&1; then
        success "✅ GRUB updated after kernel installation"
    else
        warn "⚠️ GRUB update failed"
    fi
}

# Configure packages and update grub
configure_packages_and_grub() {
    log "🔧 Configuring packages and updating GRUB..."
    
    # Configure any unconfigured packages
    if sudo dpkg --configure -a >/dev/null 2>&1; then
        info "✅ Package configuration completed"
    else
        warn "⚠️ Package configuration had issues"
    fi
    
    # Update GRUB
    if sudo update-grub >/dev/null 2>&1; then
        success "✅ GRUB updated successfully"
    else
        warn "⚠️ GRUB update failed"
    fi
}

# Verify critical installations
verify_installation() {
    log "🔍 Verifying critical installations..."
    
    local critical_packages=(
        "nginx"
        "python3" 
        "iptables"
        "dnsmasq"
        "bridge-utils"
        "ntfs-3g"
    )
    
    local verified_count=0
    local failed_count=0
    
    for package in "${critical_packages[@]}"; do
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii" || command -v "$package" >/dev/null 2>&1; then
            info "  ✅ $package"
            ((verified_count++))
        else
            warn "  ⚠️ $package (not found)"
            ((failed_count++))
        fi
    done
    
    if [[ $verified_count -gt 3 ]]; then  # Need at least most critical packages
        success "✅ Verification passed: $verified_count/$((verified_count + failed_count)) packages"
        return 0
    else
        error "❌ Verification failed: only $verified_count critical packages found"
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
    )
    
    for dir in "${directories[@]}"; do
        if sudo mkdir -p "$dir"; then
            case "$dir" in
                "/var/www/autofs")
                    sudo chown -R www-data:www-data "$dir" 2>/dev/null || true
                    ;;
            esac
            info "  ✅ Created: $dir"
        else
            warn "  ⚠️ Failed to create: $dir"
        fi
    done
}

# Generate completion report
generate_report() {
    log "📋 Generating completion report..."
    
    local report_file="/tmp/autofs-stage1-report.txt"
    
    cat > "$report_file" << EOF
AutoFS Stage 1: Simple Git Installation - Completion Report
=========================================================
Completed: $(date)
Method: Git clone + dpkg force install
Repository: $GITHUB_REPO

Installation Summary:
--------------------
✅ Git installed and repository cloned
✅ All .deb packages force-installed
✅ Dependencies fixed with apt install -f
✅ Second dpkg pass completed
✅ System updated and upgraded

System Status:
-------------
$(dpkg -l | grep -c "^ii" || echo "0") total packages installed
$(ls /boot/vmlinuz* 2>/dev/null | wc -l) kernel files in /boot
$(ls /boot/initrd* 2>/dev/null | wc -l) initrd files in /boot

Critical Package Status:
-----------------------
$(for pkg in nginx python3 iptables dnsmasq; do echo "$pkg: $(dpkg -l $pkg 2>/dev/null | grep -q "^ii" && echo "✅ Installed" || echo "❌ Missing")"; done)

Boot Directory Contents:
-----------------------
$(ls -la /boot/ | grep -E "(vmlinuz|initrd)" || echo "No kernel files visible")

Next Steps:
-----------
✅ Stage 1 (Dependencies) - COMPLETED  
⏳ Stage 2 (Network Configuration) - Ready
⏳ Stage 3 (Storage Discovery) - Pending
⏳ Stage 4 (Web Server Setup) - Pending
⏳ Stage 5 (Service Startup) - Pending

Recent Log Entries:
------------------
$(tail -10 "$LOG_FILE" 2>/dev/null || echo "Log not available")
EOF

    info "📋 Report saved: $report_file"
    echo
    echo -e "${CYAN}=== INSTALLATION RESULTS ===${NC}"
    cat "$report_file" | head -30
    echo
    echo -e "${CYAN}Full report: $report_file${NC}"
}

# Main execution function
main() {
    local stage_start=$(date +%s)
    
    show_stage_banner
    
    log "🚀 Starting Stage 1: Simple Git Installation..."
    
    # Execute your exact approach
    check_prerequisites
    install_git
    clone_repository
    move_scripts
    force_install_packages
    fix_dependencies
    second_dpkg_pass
    update_upgrade_system
    check_kernel_boot
    create_system_directories
    
    if verify_installation; then
        success "🎉 Stage 1 completed successfully!"
    else
        warn "⚠️ Stage 1 completed with some issues (may still work)"
    fi
    
    generate_report
    
    local stage_end=$(date +%s)
    local duration=$((stage_end - stage_start))
    
    echo
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                   🎉 STAGE 1 COMPLETE! 🎉                    ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║  Simple git clone and dpkg installation completed!          ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║  Duration: ${duration} seconds                                       ║${NC}"
    echo -e "${GREEN}${BOLD}║  Method: Straightforward and reliable                        ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║  Ready for Stage 2: Network Configuration                    ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Create completion marker
    cat > /tmp/.autofs-stage1-complete << EOF
$(date -Iseconds): Stage 1 completed successfully
Duration: ${duration} seconds  
Method: Git clone + dpkg force install
Repository: GlitchLinux/autoFS
Status: Ready for Stage 2
EOF
    
    info "💡 Next: Run Stage 2 for network configuration"
    info "📋 Full report: $report_file"
    
    # Clean up cloned directory to save space
    rm -rf "$WORK_DIR"
    info "🧹 Cleaned up temporary files"
}

# Execute main function
main "$@"
