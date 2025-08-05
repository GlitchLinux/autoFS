#!/bin/bash

# AutoFS Master Launcher - One-Command Universal File Server Deployment
# Downloads and executes all stages dynamically from GitHub
# Author: AutoFS Project
# Usage: curl -fsSL https://raw.githubusercontent.com/GlitchLinux/autoFS/main/AUTOFS-Launcher.sh | sudo bash

set -e

echo "🚀 AutoFS Master Launcher - Universal File Server Deployment 🚀"
echo "================================================================"
echo "This script will automatically deploy a complete file server on this system"
echo "Version: 1.0 | Safe Read-Only Access | Network Accessible"
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
highlight() { echo -e "${PURPLE}🔍 $1${NC}"; }
banner() { echo -e "${BOLD}${CYAN}$1${NC}"; }

# Configuration
GITHUB_BASE_URL="https://raw.githubusercontent.com/GlitchLinux/autoFS/refs/heads/main/SCRIPTS"
TEMP_DIR="/tmp/autofs-deployment"
LOG_FILE="/tmp/autofs-deployment.log"
START_TIME=$(date +%s)

# Stage URLs
STAGE_URLS=(
    "$GITHUB_BASE_URL/stage1-dependencies.sh"
    "$GITHUB_BASE_URL/stage2-network-config.sh"
    "$GITHUB_BASE_URL/stage3_storage.sh"
    "$GITHUB_BASE_URL/stage4_webserver.sh"
)

STAGE_NAMES=(
    "Dependencies Installation"
    "Network Configuration & NAT Bridge"
    "Storage Discovery & Mounting"
    "Web Server Configuration & Startup"
)

# Logging function
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    local stage="$1"
    local exit_code="$2"
    
    error "Stage $stage failed with exit code $exit_code"
    log_action "ERROR: Stage $stage failed with exit code $exit_code"
    
    echo
    echo "🔍 Troubleshooting Information:"
    echo "==============================="
    echo "• Check the log file: $LOG_FILE"
    echo "• Stage that failed: $stage - ${STAGE_NAMES[$((stage-1))]}"
    echo "• You can retry individual stages manually"
    echo "• Or re-run this launcher script"
    echo
    echo "📧 Support Information:"
    echo "• GitHub: https://github.com/GlitchLinux/autoFS"
    echo "• Issues: https://github.com/GlitchLinux/autoFS/issues"
    
    exit $exit_code
}

# Progress display
show_progress() {
    local current="$1"
    local total="$2"
    local stage_name="$3"
    
    local percent=$((current * 100 / total))
    local filled=$((current * 50 / total))
    local empty=$((50 - filled))
    
    printf "\r🚀 Progress: ["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $empty | tr ' ' '░'
    printf "] %d%% - %s" $percent "$stage_name"
}

# Check prerequisites
check_prerequisites() {
    banner "🔍 System Prerequisites Check"
    echo "=============================="
    
    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        echo "Usage: sudo $0"
        echo "   OR: curl -fsSL https://raw.githubusercontent.com/GlitchLinux/autoFS/main/AUTOFS-Launcher.sh | sudo bash"
        exit 1
    fi
    success "Running with root privileges"
    
    # Check if running on a Live system
    if [[ -f /etc/casper.conf ]] || [[ -f /run/live/medium/casper/filesystem.squashfs ]] || mount | grep -q "aufs\|overlay.*rw"; then
        success "Detected Live USB/CD environment"
        export LIVE_SYSTEM=true
    else
        warn "This appears to be a regular installation (not Live USB)"
        echo "AutoFS is designed for Live USB systems but can work on regular installations"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Installation cancelled by user"
            exit 0
        fi
        export LIVE_SYSTEM=false
    fi
    
    # Check available disk space
    AVAILABLE_SPACE=$(df /tmp | awk 'NR==2 {print $4}')
    if [[ $AVAILABLE_SPACE -lt 1048576 ]]; then  # 1GB in KB
        warn "Low disk space in /tmp (less than 1GB available)"
        echo "AutoFS requires temporary space for package downloads"
    else
        success "Sufficient disk space available"
    fi
    
    # Check memory
    TOTAL_MEM=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    if [[ $TOTAL_MEM -lt 1048576 ]]; then  # 1GB in KB
        warn "Low system memory (less than 1GB)"
        echo "AutoFS may run slowly with limited memory"
    else
        success "Sufficient memory available ($(($TOTAL_MEM / 1024 / 1024))GB)"
    fi
    
    # Check internet connectivity
    info "Testing internet connectivity..."
    if ping -c 3 -W 5 8.8.8.8 >/dev/null 2>&1; then
        success "Internet connectivity confirmed"
    else
        error "No internet connectivity detected"
        echo "AutoFS requires internet access to download components"
        exit 1
    fi
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        info "Installing curl..."
        apt update -qq && apt install -y curl
        success "Curl installed"
    else
        success "Curl is available"
    fi
    
    echo
}

# Critical UFW removal to prevent kernel issues
remove_ufw() {
    banner "🛡️ UFW Conflict Resolution"
    echo "=========================="
    
    info "Checking for UFW (Uncomplicated Firewall)..."
    
    if dpkg -l | grep -q "^ii.*ufw "; then
        warn "UFW detected - this conflicts with iptables and can cause kernel removal"
        info "Removing UFW to prevent system damage..."
        
        # Stop UFW service
        systemctl stop ufw 2>/dev/null || true
        systemctl disable ufw 2>/dev/null || true
        
        # Remove UFW completely
        apt-get remove --purge -y ufw 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        
        # Clean up UFW configuration
        rm -rf /etc/ufw 2>/dev/null || true
        rm -rf /lib/ufw 2>/dev/null || true
        
        success "UFW safely removed"
        log_action "UFW removed to prevent iptables conflicts"
    else
        success "No UFW conflicts detected"
    fi
    
    # Also check for other potential firewall conflicts
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        warn "FirewallD detected - stopping to prevent conflicts"
        systemctl stop firewalld
        systemctl disable firewalld
        success "FirewallD disabled"
    fi
    
    echo
}

# Prepare deployment environment
prepare_environment() {
    banner "📂 Deployment Environment Setup"
    echo "==============================="
    
    # Create temporary directory
    info "Creating deployment directory..."
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    success "Deployment directory created: $TEMP_DIR"
    
    # Initialize log file
    echo "AutoFS Deployment Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    echo "System: $(uname -a)" >> "$LOG_FILE"
    echo "User: $(whoami)" >> "$LOG_FILE"
    echo "Working Directory: $TEMP_DIR" >> "$LOG_FILE"
    echo "===========================================" >> "$LOG_FILE"
    log_action "Deployment environment prepared"
    
    # Set non-interactive mode to prevent prompts
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    export APT_LISTCHANGES_FRONTEND=none
    
    success "Environment configured for automated deployment"
    echo
}

# Download stage script with retry logic
download_stage() {
    local stage_num="$1"
    local url="$2"
    local filename="stage${stage_num}.sh"
    local max_retries=3
    
    for attempt in $(seq 1 $max_retries); do
        info "Downloading Stage $stage_num (attempt $attempt/$max_retries)..."
        
        if curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$filename"; then
            # Verify download
            if [[ -f "$filename" && -s "$filename" ]]; then
                # Check if it's a valid bash script
                if head -n 1 "$filename" | grep -q "^#!/bin/bash"; then
                    chmod +x "$filename"
                    success "Stage $stage_num downloaded successfully"
                    log_action "Downloaded: $filename from $url"
                    return 0
                else
                    warn "Downloaded file is not a valid bash script"
                fi
            else
                warn "Downloaded file is empty or missing"
            fi
        else
            warn "Download failed (attempt $attempt/$max_retries)"
        fi
        
        if [[ $attempt -lt $max_retries ]]; then
            info "Retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    error "Failed to download Stage $stage_num after $max_retries attempts"
    log_action "FAILED: Download of $filename from $url"
    return 1
}

# Execute stage with proper error handling
execute_stage() {
    local stage_num="$1"
    local stage_name="$2"
    local script_name="stage${stage_num}.sh"
    
    highlight "Executing Stage $stage_num: $stage_name"
    echo "================================================"
    
    if [[ ! -f "$script_name" ]]; then
        error "Stage script not found: $script_name"
        return 1
    fi
    
    # Log stage start
    log_action "Starting Stage $stage_num: $stage_name"
    
    # Execute stage with output logging
    echo "Starting execution of $script_name..." | tee -a "$LOG_FILE"
    
    if bash "$script_name" 2>&1 | tee -a "$LOG_FILE"; then
        success "✅ Stage $stage_num completed successfully!"
        log_action "COMPLETED: Stage $stage_num: $stage_name"
        echo
        return 0
    else
        local exit_code=${PIPESTATUS[0]}
        error "❌ Stage $stage_num failed!"
        log_action "FAILED: Stage $stage_num: $stage_name (exit code: $exit_code)"
        return $exit_code
    fi
}

# Main deployment process
deploy_autofs() {
    banner "🚀 AutoFS Deployment Process"
    echo "============================"
    echo
    
    local total_stages=${#STAGE_URLS[@]}
    
    # Download all stages first
    highlight "📥 Downloading AutoFS Components"
    echo "==============================="
    
    for i in "${!STAGE_URLS[@]}"; do
        local stage_num=$((i + 1))
        local url="${STAGE_URLS[$i]}"
        
        show_progress $stage_num $total_stages "Downloading Stage $stage_num"
        echo
        
        if ! download_stage $stage_num "$url"; then
            handle_error $stage_num 1
        fi
    done
    
    echo
    success "All stages downloaded successfully!"
    echo
    
    # Execute stages in order
    highlight "⚡ Executing AutoFS Deployment Stages"
    echo "====================================="
    
    for i in "${!STAGE_NAMES[@]}"; do
        local stage_num=$((i + 1))
        local stage_name="${STAGE_NAMES[$i]}"
        
        show_progress $stage_num $total_stages "Stage $stage_num: $stage_name"
        echo
        echo
        
        if ! execute_stage $stage_num "$stage_name"; then
            handle_error $stage_num $?
        fi
        
        # Brief pause between stages for stability
        if [[ $stage_num -lt $total_stages ]]; then
            sleep 2
        fi
    done
}

# Display final results
show_final_results() {
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    clear
    echo
    banner "🎉 AutoFS Universal File Server - DEPLOYMENT COMPLETE! 🎉"
    echo "=========================================================="
    echo
    
    success "✅ All stages completed successfully!"
    success "⏱️ Total deployment time: ${minutes}m ${seconds}s"
    
    echo
    highlight "🌐 Your File Server is Now Online!"
    echo "================================="
    
    # Get network information
    local primary_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "unknown")
    local bridge_ip="192.168.100.1"
    
    echo "📱 Access URLs:"
    echo "  🏠 Primary: http://$bridge_ip:8080"
    if [[ "$primary_ip" != "unknown" && "$primary_ip" != "$bridge_ip" ]]; then
        echo "  🌐 External: http://$primary_ip:8080"
    fi
    echo "  📝 Hostname: http://fileserver.autofs.local:8080"
    
    echo
    echo "📁 Available Sections:"
    echo "  💾 /drives/  - All mounted storage devices"
    echo "  🖥️ /system/  - System directories and files"
    echo "  🌐 /shares/  - Network shares (if any)"
    echo "  📊 /logs/    - System logs and status"
    
    echo
    echo "🛠️ Management Commands:"
    echo "  • autofs-status          - Complete system status"
    echo "  • autofs-storage-status  - Storage information"
    echo "  • autofs-network-status  - Network configuration"
    
    echo
    echo "🔒 Security Features:"
    echo "  • Read-only access (safe file browsing)"
    echo "  • No script execution allowed"
    echo "  • Local network access only"
    echo "  • Sensitive files protected"
    
    echo
    success "🎯 AutoFS is ready for use!"
    echo
    echo "📋 Quick Start:"
    echo "  1. Open a web browser on any device"
    echo "  2. Navigate to: http://$bridge_ip:8080"
    echo "  3. Browse your files safely!"
    
    echo
    echo "📚 Documentation & Support:"
    echo "  • GitHub: https://github.com/GlitchLinux/autoFS"
    echo "  • Issues: https://github.com/GlitchLinux/autoFS/issues"
    echo "  • Log file: $LOG_FILE"
    
    log_action "AutoFS deployment completed successfully in ${minutes}m ${seconds}s"
    
    # Cleanup
    echo
    info "🧹 Cleaning up temporary files..."
    cd /
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    success "Cleanup completed"
    
    echo
    banner "🚀 Welcome to AutoFS - Universal File Server! 🚀"
}

# Emergency cleanup function
cleanup_on_exit() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo
        error "Deployment interrupted or failed"
        echo
        echo "🔍 Troubleshooting:"
        echo "• Check log file: $LOG_FILE"
        echo "• Temporary files in: $TEMP_DIR"
        echo "• You can manually run individual stages"
        echo "• Or retry the full deployment"
        
        log_action "Deployment failed or interrupted with exit code: $exit_code"
    fi
    
    # Don't cleanup on error so user can investigate
    if [[ $exit_code -eq 0 ]]; then
        cd / 2>/dev/null || true
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
}

# Set up signal handlers
trap cleanup_on_exit EXIT
trap 'echo ""; error "Deployment interrupted by user"; exit 130' INT TERM

# Main execution
main() {
    echo
    info "Starting AutoFS Universal File Server deployment..."
    echo "This process will:"
    echo "  1. Install all required dependencies"
    echo "  2. Configure universal network compatibility"
    echo "  3. Mount all available storage devices"
    echo "  4. Start a beautiful web-based file browser"
    echo
    
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    echo
    
    check_prerequisites
    remove_ufw
    prepare_environment
    deploy_autofs
    show_final_results
}

# Self-update functionality
if [[ "${1:-}" == "--update" ]]; then
    info "Updating AutoFS Launcher..."
    curl -fsSL "https://raw.githubusercontent.com/GlitchLinux/autoFS/main/AUTOFS-Launcher.sh" -o "/tmp/autofs-launcher-new.sh"
    chmod +x "/tmp/autofs-launcher-new.sh"
    mv "/tmp/autofs-launcher-new.sh" "$0"
    success "AutoFS Launcher updated successfully"
    exit 0
fi

# Version information
if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
    echo "AutoFS Universal File Server Launcher v1.0"
    echo "GitHub: https://github.com/GlitchLinux/autoFS"
    exit 0
fi

# Help information
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "AutoFS Universal File Server Launcher"
    echo "====================================="
    echo
    echo "Usage:"
    echo "  sudo bash AUTOFS-Launcher.sh     # Deploy AutoFS"
    echo "  sudo bash AUTOFS-Launcher.sh --update   # Update launcher"
    echo "  sudo bash AUTOFS-Launcher.sh --version  # Show version"
    echo "  sudo bash AUTOFS-Launcher.sh --help     # Show this help"
    echo
    echo "One-liner deployment:"
    echo "  curl -fsSL https://raw.githubusercontent.com/GlitchLinux/autoFS/main/AUTOFS-Launcher.sh | sudo bash"
    echo
    exit 0
fi

# Start main execution
main "$@"
