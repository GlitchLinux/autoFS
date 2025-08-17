#!/bin/bash

# AutoFS Professional UI Application Script
# Applies a professional dark theme with custom logos and navigation

set -e

echo "AutoFS Professional UI Upgrade"
echo "=============================="
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    error "Must run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Web root directory
AUTOFS_WEB_ROOT="/var/www/autofs"
LOGO_DIR="/usr/local/bin/autoFS-Images"

# Check if AutoFS is installed
if [[ ! -d "$AUTOFS_WEB_ROOT" ]]; then
    error "AutoFS web root not found at $AUTOFS_WEB_ROOT"
    echo "Please run the AutoFS installation stages first"
    exit 1
fi

# Check if logo directory exists
if [[ ! -d "$LOGO_DIR" ]]; then
    warn "Logo directory not found at $LOGO_DIR"
    warn "Creating directory and logos will not be displayed"
    mkdir -p "$LOGO_DIR"
fi

info "Applying Professional UI with custom branding..."

# Copy logos to web directory for proper access
info "Copying logo files to web directory..."
if [[ -d "$LOGO_DIR" ]]; then
    # Create logos directory in web root
    mkdir -p "$AUTOFS_WEB_ROOT/autoFS-Images"
    
    # Copy logo files if they exist
    if [[ -f "$LOGO_DIR/autoFS-logo-BW-no-background.png" ]]; then
        cp "$LOGO_DIR/autoFS-logo-BW-no-background.png" "$AUTOFS_WEB_ROOT/autoFS-Images/"
        success "Main logo copied"
    else
        warn "Main logo not found: $LOGO_DIR/autoFS-logo-BW-no-background.png"
    fi
    
    if [[ -f "$LOGO_DIR/autoFS-logo-grey.png" ]]; then
        cp "$LOGO_DIR/autoFS-logo-grey.png" "$AUTOFS_WEB_ROOT/autoFS-Images/"
        success "Footer logo copied"
    else
        warn "Footer logo not found: $LOGO_DIR/autoFS-logo-grey.png"
    fi
    
    if [[ -f "$LOGO_DIR/autoFS.ico" ]]; then
        cp "$LOGO_DIR/autoFS.ico" "$AUTOFS_WEB_ROOT/autoFS-Images/"
        success "Favicon copied"
    else
        warn "Favicon not found: $LOGO_DIR/autoFS.ico"
    fi
    
    # Set permissions for logo files
    chown -R www-data:www-data "$AUTOFS_WEB_ROOT/autoFS-Images" 2>/dev/null || warn "Could not set www-data ownership for logos"
    chmod -R 755 "$AUTOFS_WEB_ROOT/autoFS-Images"
    success "Logo directory permissions set"
else
    warn "Logo directory not found at $LOGO_DIR"
    warn "Logos will not be displayed"
fi

# Backup existing files
info "Creating backup of existing files..."
if [[ -f "$AUTOFS_WEB_ROOT/index.html" ]]; then
    cp "$AUTOFS_WEB_ROOT/index.html" "$AUTOFS_WEB_ROOT/index.html.backup-$(date +%Y%m%d_%H%M%S)"
    success "Main page backed up"
fi

if [[ -f "$AUTOFS_WEB_ROOT/autoindex-header.html" ]]; then
    cp "$AUTOFS_WEB_ROOT/autoindex-header.html" "$AUTOFS_WEB_ROOT/autoindex-header.html.backup-$(date +%Y%m%d_%H%M%S)"
    success "Directory listing header backed up"
fi

echo
info "Creating Professional Main Page"
echo "==============================="

# Create professional main page
cat > "$AUTOFS_WEB_ROOT/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AutoFS - Universal File Server</title>
    <link rel="icon" type="image/x-icon" href="autoFS-Images/autoFS.ico">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #1a1a1a;
            color: #cdcdcd;
            min-height: 100vh;
            font-size: 16px;
            line-height: 1.5;
        }
        
        /* Top Navigation Bar */
        .top-nav {
            background: #202124;
            border-bottom: 1px solid #303134;
            padding: 0;
            position: sticky;
            top: 0;
            z-index: 1000;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
        }
        
        .nav-container {
            max-width: 1400px;
            margin: 0 auto;
            display: flex;
            align-items: center;
            padding: 0 20px;
            height: 60px;
        }
        
        .logo-section {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-right: 40px;
        }
        
        .logo-section img {
            height: 32px;
            width: auto;
        }
        
        .logo-text {
            color: #757575;
            font-size: 24px;
            font-weight: 600;
            letter-spacing: -0.5px;
        }
        
        .nav-menu {
            display: flex;
            list-style: none;
            gap: 0;
            flex: 1;
        }
        
        .nav-item {
            position: relative;
        }
        
        .nav-link {
            display: block;
            padding: 20px 20px;
            color: #cdcdcd;
            text-decoration: none;
            font-weight: 500;
            transition: all 0.2s ease;
            border-bottom: 3px solid transparent;
        }
        
        .nav-link:hover {
            background: #292a2d;
            color: #fff;
            border-bottom-color: #8ec227;
        }
        
        .dropdown {
            position: absolute;
            top: 100%;
            left: 0;
            background: #292a2d;
            border: 1px solid #303134;
            border-radius: 0 0 8px 8px;
            min-width: 200px;
            opacity: 0;
            visibility: hidden;
            transform: translateY(-10px);
            transition: all 0.3s ease;
            box-shadow: 0 4px 16px rgba(0,0,0,0.3);
        }
        
        .nav-item:hover .dropdown {
            opacity: 1;
            visibility: visible;
            transform: translateY(0);
        }
        
        .dropdown-link {
            display: block;
            padding: 12px 20px;
            color: #cdcdcd;
            text-decoration: none;
            transition: all 0.2s ease;
            border-left: 3px solid transparent;
        }
        
        .dropdown-link:hover {
            background: #3c4043;
            color: #fff;
            border-left-color: #8ec227;
        }
        
        .status-indicator {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 16px;
            background: #137333;
            color: #e8f5e8;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 500;
        }
        
        .status-dot {
            width: 8px;
            height: 8px;
            background: #4caf50;
            border-radius: 50%;
        }
        
        /* Main Content */
        .container { 
            max-width: 1200px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        
        /* Hero Section - Compact */
        .hero-section {
            display: flex;
            align-items: center;
            margin-bottom: 40px;
            padding: 20px 0;
        }
        
        .hero-content {
            display: flex;
            align-items: center;
            gap: 24px;
        }
        
        .hero-logo {
            flex-shrink: 0;
        }
        
        .hero-logo img {
            height: 90px;
            width: auto;
            opacity: 0.8;
        }
        
        .hero-text h1 {
            font-size: 2.2em;
            color: #757575;
            font-weight: 700;
            margin: 0;
            letter-spacing: -0.5px;
        }
        
        .hero-text .subtitle {
            color: #9aa0a6;
            font-size: 0.9em;
            margin-top: 4px;
            font-weight: 400;
        }
        
        .section { 
            margin: 48px 0;
            background: #202124;
            padding: 32px;
            border-radius: 12px;
            border: 1px solid #303134;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
        }
        
        .section-title { 
            color: #757575;
            font-size: 1.8em;
            font-weight: 500;
            margin-bottom: 24px;
            padding-bottom: 12px;
            border-bottom: 2px solid #8ec227;
            display: inline-block;
        }
        
        .grid { 
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 24px;
            margin-top: 24px;
        }
        
        .card { 
            background: #292a2d;
            border: 1px solid #3c4043;
            border-radius: 8px;
            padding: 24px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: #8ec227;
            transform: scaleX(0);
            transition: transform 0.3s ease;
        }
        
        .card:hover {
            background: #3c4043;
            border-color: #8ec227;
            transform: translateY(-2px);
            box-shadow: 0 8px 24px rgba(142, 194, 39, 0.1);
        }
        
        .card:hover::before {
            transform: scaleX(1);
        }
        
        .card-icon {
            width: 48px;
            height: 48px;
            background: #8ec227;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 16px;
            font-size: 24px;
        }
        
        .card h3 { 
            color: #757575;
            font-size: 1.3em;
            font-weight: 600;
            margin-bottom: 12px;
        }
        
        .card p {
            color: #cdcdcd;
            font-size: 0.95em;
            line-height: 1.5;
            margin-bottom: 20px;
        }
        
        .btn {
            background: #8ec227;
            color: #1a1a1a;
            padding: 12px 20px;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 600;
            font-size: 0.95em;
            display: inline-block;
            transition: all 0.2s ease;
            border: none;
            cursor: pointer;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .btn:hover {
            background: #a5d936;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(142, 194, 39, 0.3);
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 24px;
        }
        
        .info-item {
            background: #292a2d;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #8ec227;
            border: 1px solid #3c4043;
        }
        
        .info-item-title {
            color: #757575;
            font-weight: 600;
            margin-bottom: 8px;
            font-size: 1.1em;
        }
        
        .info-item-value {
            color: #cdcdcd;
            font-size: 0.95em;
        }
        
        .footer {
            text-align: center;
            margin-top: 60px;
            padding: 32px;
            background: #202124;
            border-radius: 12px;
            border: 1px solid #303134;
        }
        
        .footer-text {
            color: #9aa0a6;
            font-size: 0.9em;
            line-height: 1.6;
        }
        
        .footer-logo {
            margin-bottom: 16px;
        }
        
        .footer-logo img {
            height: 40px;
            opacity: 0.7;
        }
        
        /* Responsive */
        @media (max-width: 768px) {
            .nav-container {
                flex-direction: column;
                height: auto;
                padding: 16px;
                gap: 16px;
            }
            
            .nav-menu {
                flex-wrap: wrap;
                justify-content: center;
                gap: 8px;
            }
            
            .nav-link {
                padding: 12px 16px;
            }
            
            .dropdown {
                position: static;
                opacity: 1;
                visibility: visible;
                transform: none;
                margin-top: 8px;
                border-radius: 8px;
            }
            
            .hero-title { font-size: 2.4em; }
            .container { padding: 20px; }
            .section { padding: 20px; }
            .grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <!-- Top Navigation -->
    <nav class="top-nav">
        <div class="nav-container">
            <div class="logo-section">
                <img src="autoFS-Images/autoFS-logo-BW-no-background.png" alt="AutoFS Logo" onerror="this.style.display='none'">
                <div class="logo-text">autoFS</div>
            </div>
            
            <ul class="nav-menu">
                <li class="nav-item">
                    <a href="#" class="nav-link">Browse</a>
                    <div class="dropdown">
                        <a href="/drives/" class="dropdown-link">Storage Drives</a>
                        <a href="/system/" class="dropdown-link">System Directories</a>
                        <a href="/shares/" class="dropdown-link">Network Shares</a>
                    </div>
                </li>
                <li class="nav-item">
                    <a href="#" class="nav-link">System</a>
                    <div class="dropdown">
                        <a href="/status" class="dropdown-link">Server Status</a>
                        <a href="/health" class="dropdown-link">Health Check</a>
                        <a href="/logs/" class="dropdown-link">System Logs</a>
                    </div>
                </li>
                <li class="nav-item">
                    <a href="#" class="nav-link">Tools</a>
                    <div class="dropdown">
                        <a href="/admin/" class="dropdown-link">Administration</a>
                        <a href="/config/" class="dropdown-link">Configuration</a>
                        <a href="/backup/" class="dropdown-link">Backup Tools</a>
                    </div>
                </li>
                <li class="nav-item">
                    <a href="/" class="nav-link">Home</a>
                </li>
            </ul>
            
            <div class="status-indicator">
                <div class="status-dot"></div>
                <span>Online</span>
            </div>
        </div>
    </nav>

    <div class="container">
        <!-- Hero Section - Compact -->
        <div class="hero-section">
            <div class="hero-content">
                <div class="hero-logo">
                    <img src="autoFS-Images/autoFS-logo-grey.png" alt="AutoFS Logo" onerror="this.style.display='none'">
                </div>
                <div class="hero-text">
                    <h1>autoFS - Universal Filesystem</h1>
                    <div class="subtitle">Professional file server solution</div>
                </div>
            </div>
        </div>
        
        <!-- Browse Storage Section -->
        <div class="section">
            <h2 class="section-title">Browse Storage</h2>
            <div class="grid">
                <div class="card">
                    <div class="card-icon">💾</div>
                    <h3>Storage Drives</h3>
                    <p>Access all mounted drives including Windows partitions, USB devices, and external storage with full directory browsing capabilities.</p>
                    <a href="/drives/" class="btn">Browse Drives</a>
                </div>
                <div class="card">
                    <div class="card-icon">🖥️</div>
                    <h3>System Directories</h3>
                    <p>Explore system directories including home folders, configuration files, and application data with secure read-only access.</p>
                    <a href="/system/" class="btn">Browse System</a>
                </div>
                <div class="card">
                    <div class="card-icon">🌐</div>
                    <h3>Network Shares</h3>
                    <p>Access shared network resources and remote storage locations configured on your network infrastructure.</p>
                    <a href="/shares/" class="btn">Browse Shares</a>
                </div>
            </div>
        </div>
        
        <!-- System Information Section -->
        <div class="section">
            <h2 class="section-title">System Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <div class="info-item-title">Server Platform</div>
                    <div class="info-item-value">AutoFS Live System</div>
                </div>
                <div class="info-item">
                    <div class="info-item-title">Interface Theme</div>
                    <div class="info-item-value">Professional Dark</div>
                </div>
                <div class="info-item">
                    <div class="info-item-title">Primary Access</div>
                    <div class="info-item-value">http://192.168.100.1:8080</div>
                </div>
                <div class="info-item">
                    <div class="info-item-title">Security Mode</div>
                    <div class="info-item-value">Read-only Access</div>
                </div>
                <div class="info-item">
                    <div class="info-item-title">Network Protocol</div>
                    <div class="info-item-value">HTTP/HTTPS</div>
                </div>
                <div class="info-item">
                    <div class="info-item-title">File Permissions</div>
                    <div class="info-item-value">Secure Browsing</div>
                </div>
            </div>
        </div>
        
        <!-- System Management Section -->
        <div class="section">
            <h2 class="section-title">System Management</h2>
            <div class="grid">
                <div class="card">
                    <div class="card-icon">📊</div>
                    <h3>Server Status</h3>
                    <p>Monitor real-time system health, service status, and performance metrics for optimal operation.</p>
                    <a href="/status" class="btn">View Status</a>
                </div>
                <div class="card">
                    <div class="card-icon">📋</div>
                    <h3>System Logs</h3>
                    <p>Access comprehensive system logs for monitoring activity, troubleshooting issues, and security auditing.</p>
                    <a href="/logs/" class="btn">View Logs</a>
                </div>
                <div class="card">
                    <div class="card-icon">⚡</div>
                    <h3>Health Check</h3>
                    <p>Real-time system health monitoring endpoint providing detailed service status and diagnostic information.</p>
                    <a href="/health" class="btn">Health API</a>
                </div>
                <div class="card">
                    <div class="card-icon">⚙️</div>
                    <h3>Configuration</h3>
                    <p>Access system configuration options and administrative tools for managing server settings.</p>
                    <a href="/admin/" class="btn">Administration</a>
                </div>
            </div>
        </div>
        
        <!-- Footer -->
        <div class="footer">
            <div class="footer-logo">
                <img src="autoFS-Images/autoFS-logo-grey.png" alt="AutoFS" onerror="this.style.display='none'">
            </div>
            <div class="footer-text">
                <strong>AutoFS Universal File Server</strong><br>
                Professional file system access • Network accessible • Secure browsing<br>
                Created by: <a href="https://github.com/glitchlinux" style="color: #8ec227;">github.com/glitchlinux</a>
            </div>
        </div>
    </div>
</body>
</html>
EOF

success "Professional main page created"

echo
info "Creating Professional Directory Listings"
echo "========================================"

# Create professional directory listing header
cat > "$AUTOFS_WEB_ROOT/autoindex-header.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>AutoFS File Browser</title>
    <link rel="icon" type="image/x-icon" href="autoFS-Images/autoFS.ico">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #1a1a1a;
            color: #cdcdcd;
            min-height: 100vh;
            font-size: 15px;
            line-height: 1.4;
        }
        
        /* Top Navigation Bar */
        .top-nav {
            background: #202124;
            border-bottom: 1px solid #303134;
            padding: 0;
            position: sticky;
            top: 0;
            z-index: 1000;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
        }
        
        .nav-container {
            max-width: 1400px;
            margin: 0 auto;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 20px;
            height: 50px;
        }
        
        .logo-section {
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .logo-section img {
            height: 24px;
            width: auto;
        }
        
        .logo-text {
            color: #757575;
            font-size: 18px;
            font-weight: 600;
        }
        
        .nav-links {
            display: flex;
            gap: 0;
            list-style: none;
        }
        
        .nav-links a {
            display: block;
            padding: 15px 16px;
            color: #cdcdcd;
            text-decoration: none;
            font-weight: 500;
            transition: all 0.2s ease;
            border-bottom: 2px solid transparent;
        }
        
        .nav-links a:hover {
            background: #292a2d;
            color: #fff;
            border-bottom-color: #8ec227;
        }
        
        .breadcrumb-section {
            background: #292a2d;
            border-bottom: 1px solid #3c4043;
            padding: 16px 20px;
        }
        
        .breadcrumb-container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        .page-title {
            color: #757575;
            font-size: 1.4em;
            font-weight: 600;
            margin-bottom: 8px;
        }
        
        .breadcrumb {
            color: #9aa0a6;
            font-size: 0.9em;
        }
        
        .breadcrumb a {
            color: #8ec227;
            text-decoration: none;
            padding: 4px 6px;
            border-radius: 4px;
            transition: background 0.2s ease;
        }
        
        .breadcrumb a:hover {
            background: #3c4043;
            text-decoration: none;
        }
        
        .main-content {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .file-list-container {
            background: #202124;
            border: 1px solid #303134;
            border-radius: 8px;
            padding: 24px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
        }
        
        .file-list-header {
            margin-bottom: 20px;
            padding-bottom: 16px;
            border-bottom: 1px solid #3c4043;
        }
        
        .file-count {
            color: #9aa0a6;
            font-size: 0.9em;
        }
        
        pre {
            color: #cdcdcd;
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 14px;
            line-height: 1.6;
        }
        
        pre a {
            color: #8ec227;
            text-decoration: none;
            display: block;
            padding: 10px 16px;
            margin: 2px 0;
            border-radius: 6px;
            transition: all 0.2s ease;
            font-size: 14px;
            border: 1px solid transparent;
            position: relative;
        }
        
        pre a:hover {
            background: #292a2d;
            border-color: #3c4043;
            text-decoration: none;
            transform: translateX(4px);
            color: #a5d936;
        }
        
        /* File type styling */
        .file-folder { 
            color: #8ec227 !important;
            font-weight: 600;
        }
        .file-image { color: #ff8a80 !important; }
        .file-video { color: #ce93d8 !important; }
        .file-audio { color: #80cbc4 !important; }
        .file-document { color: #ffcc02 !important; }
        .file-archive { color: #bcaaa4 !important; }
        .file-executable { color: #f48fb1 !important; }
        .file-text { color: #81d4fa !important; }
        .file-code { color: #a5d6a7 !important; }
        
        /* Quick Actions */
        .quick-actions {
            background: #292a2d;
            border: 1px solid #3c4043;
            border-radius: 8px;
            padding: 16px;
            margin-bottom: 20px;
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            align-items: center;
        }
        
        .quick-action {
            background: #3c4043;
            color: #cdcdcd;
            padding: 8px 12px;
            border-radius: 4px;
            text-decoration: none;
            font-size: 0.85em;
            font-weight: 500;
            transition: all 0.2s ease;
            border: 1px solid #5f6368;
        }
        
        .quick-action:hover {
            background: #8ec227;
            color: #1a1a1a;
            text-decoration: none;
        }
        
        /* Responsive */
        @media (max-width: 768px) {
            .nav-container {
                flex-direction: column;
                height: auto;
                padding: 12px;
                gap: 12px;
            }
            
            .nav-links {
                flex-wrap: wrap;
                justify-content: center;
                gap: 4px;
            }
            
            .nav-links a {
                padding: 10px 12px;
                font-size: 0.9em;
            }
            
            .main-content { padding: 16px; }
            .file-list-container { padding: 16px; }
            .quick-actions { flex-direction: column; align-items: stretch; }
            .quick-action { text-align: center; }
        }
    </style>
</head>
<body>
    <!-- Top Navigation -->
    <nav class="top-nav">
        <div class="nav-container">
            <div class="logo-section">
                <img src="autoFS-Images/autoFS-logo-BW-no-background.png" alt="AutoFS Logo" onerror="this.style.display='none'">
                <div class="logo-text">autoFS</div>
            </div>
            
            <ul class="nav-links">
                <li><a href="/drives/">Storage</a></li>
                <li><a href="/system/">System</a></li>
                <li><a href="/shares/">Shares</a></li>
                <li><a href="/logs/">Logs</a></li>
                <li><a href="/status">Status</a></li>
                <li><a href="/">Home</a></li>
            </ul>
        </div>
    </nav>
    
    <!-- Breadcrumb Section -->
    <div class="breadcrumb-section">
        <div class="breadcrumb-container">
            <h1 class="page-title">File Browser</h1>
            <div class="breadcrumb">
                <a href="/">Home</a> /
                <script>
                    var path = window.location.pathname;
                    var parts = path.split('/').filter(p => p);
                    var breadcrumb = '';
                    var currentPath = '';
                    
                    for (var i = 0; i < parts.length; i++) {
                        currentPath += '/' + parts[i];
                        if (i === parts.length - 1) {
                            breadcrumb += ' ' + decodeURIComponent(parts[i]);
                        } else {
                            breadcrumb += ' <a href="' + currentPath + '/">' + decodeURIComponent(parts[i]) + '</a> /';
                        }
                    }
                    document.write(breadcrumb);
                </script>
            </div>
        </div>
    </div>
    
    <!-- Main Content -->
    <div class="main-content">
        <!-- Quick Actions -->
        <div class="quick-actions">
            <span style="color: #757575; font-weight: 600; margin-right: 8px;">Quick Navigation:</span>
            <a href="/drives/" class="quick-action">💾 Storage Drives</a>
            <a href="/system/" class="quick-action">🖥️ System Files</a>
            <a href="/shares/" class="quick-action">🌐 Network Shares</a>
            <a href="/logs/" class="quick-action">📊 System Logs</a>
            <a href="/" class="quick-action">🏠 Home</a>
        </div>
        
        <div class="file-list-container">
            <div class="file-list-header">
                <div class="file-count" id="fileCount">Loading directory contents...</div>
            </div>
EOF

success "Professional directory listing header created"

# Create professional directory listing footer
cat > "$AUTOFS_WEB_ROOT/autoindex-footer.html" << 'EOF'
        </div>
    </div>
    
    <div style="text-align: center; margin: 32px auto; max-width: 1400px; padding: 24px 20px; background: #202124; border-radius: 8px; color: #9aa0a6; font-size: 0.9em; border: 1px solid #303134;">
        <div style="margin-bottom: 12px;">
            <img src="autoFS-Images/autoFS-logo-grey.png" alt="AutoFS" style="height: 24px; opacity: 0.7;" onerror="this.style.display='none'">
        </div>
        <p><strong style="color: #757575;">AutoFS Universal File Server</strong> - Professional Interface</p>
        <p style="margin-top: 8px;">🔒 Secure read-only browsing • 📡 Network accessible • 🌐 Professional interface</p>
    </div>
    
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            // File type icons and styling
            var links = document.querySelectorAll('pre a');
            var fileCount = 0;
            var folderCount = 0;
            
            links.forEach(function(link) {
                var filename = link.textContent.trim();
                var icon = '📄';
                var className = 'file-text';
                
                if (filename.endsWith('/')) {
                    icon = '📁';
                    className = 'file-folder';
                    folderCount++;
                } else {
                    fileCount++;
                    if (filename.match(/\.(jpg|jpeg|png|gif|bmp|svg|webp)$/i)) {
                        icon = '🖼️';
                        className = 'file-image';
                    } else if (filename.match(/\.(mp4|avi|mkv|mov|wmv|flv|webm)$/i)) {
                        icon = '🎬';
                        className = 'file-video';
                    } else if (filename.match(/\.(mp3|wav|flac|aac|ogg|m4a)$/i)) {
                        icon = '🎵';
                        className = 'file-audio';
                    } else if (filename.match(/\.(pdf)$/i)) {
                        icon = '📕';
                        className = 'file-document';
                    } else if (filename.match(/\.(doc|docx|odt)$/i)) {
                        icon = '📘';
                        className = 'file-document';
                    } else if (filename.match(/\.(xls|xlsx|ods|csv)$/i)) {
                        icon = '📗';
                        className = 'file-document';
                    } else if (filename.match(/\.(ppt|pptx|odp)$/i)) {
                        icon = '📙';
                        className = 'file-document';
                    } else if (filename.match(/\.(zip|rar|7z|tar|gz|bz2)$/i)) {
                        icon = '📦';
                        className = 'file-archive';
                    } else if (filename.match(/\.(exe|msi|deb|rpm|dmg)$/i)) {
                        icon = '⚙️';
                        className = 'file-executable';
                    } else if (filename.match(/\.(txt|log|md|readme)$/i)) {
                        icon = '📃';
                        className = 'file-text';
                    } else if (filename.match(/\.(json|xml|yml|yaml|conf|cfg)$/i)) {
                        icon = '⚙️';
                        className = 'file-text';
                    } else if (filename.match(/\.(html|htm|css|js|php|py|sh|bat)$/i)) {
                        icon = '💻';
                        className = 'file-code';
                    }
                }
                
                link.innerHTML = icon + ' ' + link.innerHTML;
                link.classList.add(className);
            });
            
            // Update file count
            var totalCount = fileCount + folderCount;
            var countText = totalCount + ' items';
            if (folderCount > 0 && fileCount > 0) {
                countText = folderCount + ' folders, ' + fileCount + ' files (' + totalCount + ' total)';
            } else if (folderCount > 0) {
                countText = folderCount + ' folders';
            } else if (fileCount > 0) {
                countText = fileCount + ' files';
            }
            
            document.getElementById('fileCount').textContent = countText;
            
            // Keyboard shortcuts
            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape') {
                    window.history.back();
                } else if (e.key === 'h' && !e.ctrlKey && !e.altKey && !e.metaKey) {
                    window.location.href = '/';
                } else if (e.key === 'b' && !e.ctrlKey && !e.altKey && !e.metaKey) {
                    window.history.back();
                }
            });
            
            // Add keyboard shortcut info
            var shortcutInfo = document.createElement('div');
            shortcutInfo.style.cssText = 'position: fixed; bottom: 20px; right: 20px; background: #292a2d; color: #9aa0a6; padding: 8px 12px; border-radius: 6px; font-size: 0.8em; border: 1px solid #3c4043; opacity: 0.7;';
            shortcutInfo.innerHTML = 'Shortcuts: H=Home, B=Back, Esc=Back';
            document.body.appendChild(shortcutInfo);
        });
    </script>
</body>
</html>
EOF

success "Professional directory listing footer created"

echo
info "Creating Professional Error Pages"
echo "================================="

# Create professional 404 page
cat > "$AUTOFS_WEB_ROOT/404.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <title>404 - Not Found | AutoFS</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/x-icon" href="/usr/local/bin/autoFS-Images/autoFS.ico">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a1a;
            color: #cdcdcd;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
            padding: 20px;
        }
        .error-container {
            text-align: center;
            background: #202124;
            padding: 48px;
            border-radius: 12px;
            border: 1px solid #303134;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 4px 16px rgba(0,0,0,0.3);
        }
        .logo {
            margin-bottom: 24px;
        }
        .logo img {
            height: 40px;
            opacity: 0.8;
        }
        h1 { 
            font-size: 4em;
            color: #ea4335;
            font-weight: 300;
            margin: 0 0 16px 0;
        }
        h2 { 
            color: #757575;
            font-weight: 500;
            margin-bottom: 16px;
            font-size: 1.5em;
        }
        p {
            color: #cdcdcd;
            margin-bottom: 32px;
            line-height: 1.5;
        }
        .btn {
            background: #8ec227;
            color: #1a1a1a;
            padding: 12px 24px;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 600;
            display: inline-block;
            transition: all 0.2s ease;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .btn:hover {
            background: #a5d936;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(142, 194, 39, 0.3);
        }
    </style>
</head>
<body>
    <div class="error-container">
        <div class="logo">
            <img src="autoFS-Images/autoFS-logo-grey.png" alt="AutoFS" onerror="this.style.display='none'">
        </div>
        <h1>404</h1>
        <h2>Resource Not Found</h2>
        <p>The requested file or directory could not be located on the AutoFS server.</p>
        <a href="/" class="btn">← Return Home</a>
    </div>
</body>
</html>
EOF

# Create professional 50x page
cat > "$AUTOFS_WEB_ROOT/50x.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Server Error | AutoFS</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/x-icon" href="autoFS-Images/autoFS.ico">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a1a;
            color: #cdcdcd;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
            padding: 20px;
        }
        .error-container {
            text-align: center;
            background: #202124;
            padding: 48px;
            border-radius: 12px;
            border: 1px solid #303134;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 4px 16px rgba(0,0,0,0.3);
        }
        .logo {
            margin-bottom: 24px;
        }
        .logo img {
            height: 40px;
            opacity: 0.8;
        }
        h1 { 
            font-size: 4em;
            color: #fbbc04;
            font-weight: 300;
            margin: 0 0 16px 0;
        }
        h2 { 
            color: #757575;
            font-weight: 500;
            margin-bottom: 16px;
            font-size: 1.5em;
        }
        p {
            color: #cdcdcd;
            margin-bottom: 32px;
            line-height: 1.5;
        }
        .btn {
            background: #8ec227;
            color: #1a1a1a;
            padding: 12px 24px;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 600;
            display: inline-block;
            transition: all 0.2s ease;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .btn:hover {
            background: #a5d936;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(142, 194, 39, 0.3);
        }
    </style>
</head>
<body>
    <div class="error-container">
        <div class="logo">
            <img src="autoFS-Images/autoFS-logo-grey.png" alt="AutoFS" onerror="this.style.display='none'">
        </div>
        <h1>5xx</h1>
        <h2>Server Error</h2>
        <p>The AutoFS server encountered an error and could not complete your request.</p>
        <a href="/" class="btn">← Return Home</a>
    </div>
</body>
</html>
EOF

success "Professional error pages created"

echo
info "Setting Permissions and Restarting Server"
echo "=========================================="

# Set proper permissions
chown -R www-data:www-data "$AUTOFS_WEB_ROOT" 2>/dev/null || warn "Could not set www-data ownership"
chmod -R 755 "$AUTOFS_WEB_ROOT"
success "File permissions set"

# Restart nginx
if systemctl restart nginx 2>/dev/null; then
    success "Nginx restarted successfully"
    
    # Test if server is responding
    sleep 2
    if curl -s -o /dev/null -w "%{http_code}" "http://192.168.100.1:8080/" | grep -q "200"; then
        success "Professional UI web server is responding"
    else
        warn "Web server may not be fully ready yet"
    fi
else
    error "Failed to restart nginx"
    exit 1
fi

echo
echo "Professional UI Features Applied:"
echo "================================"
echo ""
echo "  • Custom logo integration from $LOGO_DIR"
echo "  • Professional color scheme:"
echo "    - Folders: #8ec227 (your specified green)"
echo "    - Main text: #cdcdcd"
echo "    - Titles & menus: #757575"
echo "    - Background: #1a1a1a (unchanged)"
echo "  • Top navigation bar with dropdown menus"
echo "  • Professional icons and styling"
echo "  • Responsive design for mobile devices"
echo "  • Keyboard shortcuts (H=Home, B=Back, Esc=Back)"
echo ""

# Get network info for final display
PRIMARY_IF=$(ip route show default | head -n1 | awk '{print $5}' 2>/dev/null || echo "none")
PRIMARY_IP=$(ip addr show "$PRIMARY_IF" | grep 'inet ' | head -n1 | awk '{print $2}' | cut -d/ -f1 2>/dev/null || echo "unknown")
BRIDGE_STATUS=$(ip link show br-autofs | grep -o 'state [A-Z]*' | awk '{print $2}' 2>/dev/null || echo "DOWN")

echo "Network Configuration:"
echo "====================="
echo ""
echo "  External Interface: $PRIMARY_IF ($PRIMARY_IP)"
echo "  Internal Bridge: br-autofs (192.168.100.1) - $BRIDGE_STATUS"

if [[ "$PRIMARY_IP" != "192.168.100.1" && "$PRIMARY_IP" != "unknown" ]]; then
    echo "  External Access: http://$PRIMARY_IP:8080"
fi

# Test connectivity
if ping -c 1 -W 2 192.168.100.1 >/dev/null 2>&1; then
    success "Internal connectivity: Working"
else
    error "Internal connectivity: Failed"
fi

echo
echo "Logo Files Status:"
echo "=================="
echo ""

if [[ -f "$AUTOFS_WEB_ROOT/autoFS-Images/autoFS-logo-BW-no-background.png" ]]; then
    success "Main logo available"
else
    warn "Main logo not available - text only display"
fi

if [[ -f "$AUTOFS_WEB_ROOT/autoFS-Images/autoFS-logo-grey.png" ]]; then
    success "Footer logo available"
else
    warn "Footer logo not available - text only display"
fi

if [[ -f "$AUTOFS_WEB_ROOT/autoFS-Images/autoFS.ico" ]]; then
    success "Favicon available"
else
    warn "Favicon not available - browser default"
fi

# Count mounted devices
MOUNT_COUNT=$(df | grep -c "/mnt/autofs" 2>/dev/null || echo "0")

if systemctl is-active --quiet nginx && [[ "$BRIDGE_STATUS" == "UP" ]]; then
    # Clear screen and show final status as requested
    echo ""
    echo ""
    clear
    echo ""
    echo ""
    success "AutoFS Universal File Server is now ONLINE!"
    echo
    echo "Management:"
    echo "=========="
    echo ""
    echo "  • Disable autostart: autostart-off"
    echo "  • Enable autostart:  autostart-on"
    echo "  • Unmount autoFS:    autofs-unmount-all"
    echo "  • Storage info:      autofs-storage-status"
    echo "  • Network info:      autofs-network-status"
    echo "  • Full status:       autofs-status"
    echo
    echo "Security Notes:"
    echo "==============="
    echo ""
    echo "  • All access is READ-ONLY (safe browsing)"
    echo "  • No script execution allowed"
    echo "  • Sensitive files are protected"
    echo "  • Local network access only"
    echo
    echo "Access autoFS:"
    echo "=============="
    echo ""
    echo "  • Primary URL: http://192.168.100.1:8080"
    if [[ "$PRIMARY_IP" != "192.168.100.1" && "$PRIMARY_IP" != "unknown" ]]; then
        echo "  • External URL: http://$PRIMARY_IP:8080"
    fi
else
    warn "AutoFS has some issues - check individual services"
fi

success "Professional UI upgrade completed successfully!"
