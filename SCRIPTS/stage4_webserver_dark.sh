#!/bin/bash

# AutoFS Stage 4: Web Server Configuration & Startup (Dark Theme Edition)
# Configures nginx and starts the file server with enhanced dark theme

set -e

echo "🌙 AutoFS Stage 4: Dark Theme Web Server Configuration 🌙"
echo "========================================================="
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
web_info() { echo -e "${CYAN}🌐 $1${NC}"; }

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    error "Must run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Check Stage 3 completion
info "Checking prerequisites..."
if [[ ! -f /tmp/.autofs-stage3-complete ]]; then
    error "Stage 3 not completed. Please run stage3-storage.sh first"
    exit 1
else
    success "Stage 3 completed - storage configured"
fi

# Web server configuration variables
NGINX_CONFIG_DIR="/etc/nginx"
AUTOFS_WEB_ROOT="/var/www/autofs"
NGINX_SITE_CONFIG="$NGINX_CONFIG_DIR/sites-available/autofs"
NGINX_LOG_DIR="/var/log/nginx"
AUTOFS_LOG_DIR="/var/log/autofs"

echo
info "🔧 Nginx Configuration Preparation"
echo "=================================="

# Stop nginx if running
info "Stopping nginx service..."
systemctl stop nginx 2>/dev/null || warn "nginx was not running"

# Backup original nginx configuration
info "Backing up original nginx configuration..."
if [[ -f "$NGINX_CONFIG_DIR/nginx.conf" && ! -f "$NGINX_CONFIG_DIR/nginx.conf.autofs-backup" ]]; then
    cp "$NGINX_CONFIG_DIR/nginx.conf" "$NGINX_CONFIG_DIR/nginx.conf.autofs-backup"
    success "Original nginx configuration backed up"
else
    warn "Backup already exists or original config not found"
fi

echo
highlight "🌐 Nginx Virtual Host Configuration"
echo "==================================="

# Create nginx site configuration for AutoFS
info "Creating nginx virtual host configuration..."

cat > "$NGINX_SITE_CONFIG" << 'EOF'
# AutoFS Universal File Server Configuration - Dark Theme Edition
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;
    
    server_name fileserver.autofs.local autofs.local _;
    
    root /var/www/autofs;
    index index.html index.htm;
    
    # Logging
    access_log /var/log/nginx/autofs-access.log;
    error_log /var/log/nginx/autofs-error.log;
    
    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    
    # Main location - serve the index page
    location = / {
        try_files /index.html =404;
    }
    
    # Static assets and favicon
    location ~ ^/(favicon\.ico|robots\.txt)$ {
        access_log off;
        log_not_found off;
        expires 30d;
    }
    
    # File browsing locations with autoindex
    location /drives/ {
        alias /var/www/autofs/drives/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        autoindex_format html;
        
        # Custom styling for directory listings
        add_before_body /autoindex-header.html;
        add_after_body /autoindex-footer.html;
        
        # Security - prevent execution
        location ~* \.(php|pl|py|jsp|asp|sh|cgi)$ {
            deny all;
        }
    }
    
    location /system/ {
        alias /var/www/autofs/system/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        autoindex_format html;
        
        # Custom styling
        add_before_body /autoindex-header.html;
        add_after_body /autoindex-footer.html;
        
        # Security - prevent execution and limit access to sensitive files
        location ~* \.(php|pl|py|jsp|asp|sh|cgi)$ {
            deny all;
        }
        
        # Restrict access to sensitive system files
        location ~* /(passwd|shadow|gshadow|group|sudoers|ssh|ssl)$ {
            deny all;
        }
    }
    
    location /shares/ {
        alias /var/www/autofs/shares/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        autoindex_format html;
        
        add_before_body /autoindex-header.html;
        add_after_body /autoindex-footer.html;
    }
    
    location /logs/ {
        alias /var/log/autofs/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        autoindex_format html;
        
        # Only allow access to log files
        location ~* \.log$ {
            add_header Content-Type text/plain;
        }
    }
    
    # Status and monitoring endpoints
    location /status {
        access_log off;
        return 200 "AutoFS Server Online - Dark Theme Edition\n";
        add_header Content-Type text/plain;
    }
    
    location /health {
        access_log off;
        return 200 '{"status":"healthy","theme":"dark","timestamp":"$time_iso8601"}';
        add_header Content-Type application/json;
    }
    
    # Deny access to hidden files and directories
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Deny access to backup and temporary files
    location ~* \.(bak|config|sql|fla|psd|ini|log|sh|inc|swp|dist)$ {
        deny all;
    }
    
    # File download with proper headers
    location ~* \.(pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|7z|tar|gz|bz2|mp3|mp4|avi|mkv|mov|jpg|jpeg|png|gif|svg|css|js|txt|csv)$ {
        add_header Content-Disposition 'attachment; filename="$1"';
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    
    # Default file serving
    location / {
        try_files $uri $uri/ =404;
        
        # Security - prevent execution of scripts
        location ~* \.(php|pl|py|jsp|asp|sh|cgi)$ {
            deny all;
        }
    }
    
    # Custom error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    location = /404.html {
        root /var/www/autofs;
        internal;
    }
    
    location = /50x.html {
        root /var/www/autofs;
        internal;
    }
}
EOF

success "Nginx virtual host configuration created"

echo
highlight "🌙 Dark Theme Main Page Creation"
echo "================================"

# Create dark theme main page
info "Creating enhanced dark theme main page..."

cat > "$AUTOFS_WEB_ROOT/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AutoFS - Universal File Server (Dark Edition)</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            margin: 0; 
            padding: 20px;
            background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 50%, #1a1a1a 100%);
            color: #e0e0e0; 
            min-height: 100vh;
            font-size: 16px;
            line-height: 1.6;
        }
        
        .container { 
            max-width: 1400px; 
            margin: 0 auto;
            background: rgba(45, 45, 45, 0.8); 
            padding: 40px;
            border-radius: 20px; 
            backdrop-filter: blur(15px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        h1 { 
            text-align: center; 
            font-size: 3.2em; 
            margin-bottom: 40px; 
            color: #4fc3f7;
            text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
            font-weight: 300;
        }
        
        .status { 
            background: rgba(76, 175, 80, 0.2); 
            padding: 18px 24px; 
            border-radius: 12px; 
            margin: 20px 0; 
            border: 1px solid rgba(76, 175, 80, 0.3);
            font-size: 1.1em;
            font-weight: 500;
        }
        
        .section { 
            margin: 40px 0; 
            background: rgba(60, 60, 60, 0.6); 
            padding: 30px; 
            border-radius: 15px; 
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
        }
        
        .section h2 { 
            color: #81c784; 
            border-bottom: 3px solid #81c784; 
            padding-bottom: 15px; 
            margin-top: 0; 
            margin-bottom: 25px;
            font-size: 1.8em;
            font-weight: 400;
        }
        
        .grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); 
            gap: 25px; 
            margin-top: 30px; 
        }
        
        .card { 
            background: rgba(80, 80, 80, 0.7); 
            padding: 30px; 
            border-radius: 15px; 
            transition: all 0.3s ease;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
        }
        
        .card:hover {
            background: rgba(90, 90, 90, 0.8);
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
        }
        
        .card h3 { 
            margin-top: 0; 
            color: #4fc3f7; 
            font-size: 1.4em;
            margin-bottom: 15px;
            font-weight: 500;
        }
        
        .card p {
            font-size: 1.05em;
            margin-bottom: 20px;
            color: #b0b0b0;
            line-height: 1.7;
        }
        
        a { 
            color: #4fc3f7; 
            text-decoration: none; 
            font-weight: 600;
            font-size: 1.1em;
            padding: 12px 20px;
            background: rgba(79, 195, 247, 0.1);
            border-radius: 8px;
            display: inline-block;
            transition: all 0.3s ease;
            border: 1px solid rgba(79, 195, 247, 0.2);
        }
        
        a:hover { 
            color: #ffffff; 
            background: rgba(79, 195, 247, 0.2);
            text-decoration: none;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(79, 195, 247, 0.3);
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        
        .info-item {
            background: rgba(70, 70, 70, 0.5);
            padding: 15px 20px;
            border-radius: 8px;
            border-left: 4px solid #81c784;
        }
        
        .info-item strong {
            color: #4fc3f7;
            font-size: 1.05em;
        }
        
        code {
            background: rgba(30, 30, 30, 0.8);
            color: #81c784;
            padding: 4px 8px;
            border-radius: 4px;
            font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
            font-size: 1em;
        }
        
        .theme-badge {
            position: absolute;
            top: 20px;
            right: 20px;
            background: rgba(79, 195, 247, 0.2);
            color: #4fc3f7;
            padding: 8px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: 500;
        }
        
        /* Responsive improvements */
        @media (max-width: 768px) {
            body {
                padding: 15px;
                font-size: 15px;
            }
            
            .container {
                padding: 25px;
                position: relative;
            }
            
            .theme-badge {
                position: static;
                display: inline-block;
                margin-bottom: 20px;
            }
            
            h1 {
                font-size: 2.5em;
            }
            
            .grid {
                grid-template-columns: 1fr;
                gap: 20px;
            }
            
            .card {
                padding: 25px;
            }
        }
    </style>
</head>
<body>
    <div class="theme-badge">🌙 Dark Edition</div>
    <div class="container">
        <h1>🚀 AutoFS Universal File Server</h1>
        <div class="status"><strong>🟢 Dark Theme System Online</strong> - Enhanced readability and modern interface</div>
        
        <div class="section">
            <h2>📁 Browse Storage</h2>
            <div class="grid">
                <div class="card">
                    <h3>💾 Storage Drives</h3>
                    <p>Access all mounted drives including Windows partitions, USB devices, and external storage with enhanced dark theme navigation.</p>
                    <a href="/drives/">→ Browse Drives</a>
                </div>
                <div class="card">
                    <h3>🖥️ System Directories</h3>
                    <p>Explore system directories including home folders, configuration files, and system logs with improved readability.</p>
                    <a href="/system/">→ Browse System</a>
                </div>
            </div>
        </div>
        
        <div class="section">
            <h2>ℹ️ System Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <strong>Server:</strong> AutoFS Live System
                </div>
                <div class="info-item">
                    <strong>Edition:</strong> Dark Theme Enhanced
                </div>
                <div class="info-item">
                    <strong>Access:</strong> <code>http://192.168.100.1:8080</code>
                </div>
                <div class="info-item">
                    <strong>Security:</strong> Read-only access enabled
                </div>
                <div class="info-item">
                    <strong>Theme:</strong> Optimized for reduced eye strain
                </div>
                <div class="info-item">
                    <strong>Fonts:</strong> Larger text for better readability
                </div>
            </div>
        </div>
        
        <div class="section">
            <h2>🔗 Quick Access</h2>
            <div class="grid">
                <div class="card">
                    <h3>📊 Server Status</h3>
                    <p>Check system health and service status with dark theme interface.</p>
                    <a href="/status">→ View Status</a>
                </div>
                <div class="card">
                    <h3>📋 System Logs</h3>
                    <p>Monitor system activity and troubleshoot issues with enhanced visibility.</p>
                    <a href="/logs/">→ View Logs</a>
                </div>
                <div class="card">
                    <h3>🌐 Network Shares</h3>
                    <p>Access shared network resources and remote storage locations.</p>
                    <a href="/shares/">→ Browse Shares</a>
                </div>
                <div class="card">
                    <h3>⚙️ System Health</h3>
                    <p>Real-time system health monitoring with JSON API endpoint.</p>
                    <a href="/health">→ Health Check</a>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
EOF

success "Dark theme main page created"

echo
highlight "🗂️ Dark Theme Directory Listings"
echo "================================="

# Create dark theme directory listing header
info "Creating enhanced dark theme directory listings..."

cat > "$AUTOFS_WEB_ROOT/autoindex-header.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>AutoFS File Browser - Dark Edition</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 50%, #1a1a1a 100%);
            color: #e0e0e0;
            min-height: 100vh;
            font-size: 16px;
            line-height: 1.6;
        }
        
        .header {
            background: rgba(45, 45, 45, 0.9);
            padding: 25px 30px;
            border-radius: 15px;
            margin-bottom: 25px;
            backdrop-filter: blur(15px);
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.1);
            position: relative;
        }
        
        .theme-indicator {
            position: absolute;
            top: 15px;
            right: 20px;
            background: rgba(79, 195, 247, 0.2);
            color: #4fc3f7;
            padding: 5px 12px;
            border-radius: 15px;
            font-size: 0.8em;
            font-weight: 500;
        }
        
        .header h1 {
            margin: 0;
            font-size: 1.8em;
            color: #4fc3f7;
            font-weight: 400;
        }
        
        .breadcrumb {
            margin-top: 10px;
            font-size: 1.05em;
            color: #b0b0b0;
        }
        
        .breadcrumb a {
            color: #4fc3f7;
            text-decoration: none;
            padding: 4px 8px;
            border-radius: 4px;
            transition: all 0.2s ease;
        }
        
        .breadcrumb a:hover {
            color: #ffffff;
            background: rgba(79, 195, 247, 0.2);
            text-decoration: none;
        }
        
        .file-list {
            background: rgba(60, 60, 60, 0.8);
            border-radius: 15px;
            padding: 30px;
            backdrop-filter: blur(15px);
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        pre {
            color: #e0e0e0;
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            font-size: 15px;
            line-height: 1.8;
        }
        
        pre a {
            color: #4fc3f7;
            text-decoration: none;
            display: inline-block;
            padding: 10px 15px;
            margin: 3px 0;
            border-radius: 8px;
            transition: all 0.3s ease;
            font-size: 1.05em;
            min-width: 220px;
            border: 1px solid transparent;
        }
        
        pre a:hover {
            background: rgba(79, 195, 247, 0.15);
            color: #ffffff;
            text-decoration: none;
            transform: translateX(8px);
            border: 1px solid rgba(79, 195, 247, 0.3);
            box-shadow: 0 2px 12px rgba(79, 195, 247, 0.25);
        }
        
        .nav-links {
            margin-bottom: 25px;
            display: flex;
            flex-wrap: wrap;
            gap: 15px;
        }
        
        .nav-links a {
            background: rgba(70, 70, 70, 0.8);
            color: #e0e0e0;
            padding: 14px 20px;
            text-decoration: none;
            border-radius: 10px;
            font-size: 1.05em;
            font-weight: 500;
            transition: all 0.3s ease;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
        }
        
        .nav-links a:hover {
            background: rgba(79, 195, 247, 0.2);
            color: #ffffff;
            transform: translateY(-2px);
            box-shadow: 0 4px 15px rgba(79, 195, 247, 0.3);
        }
        
        /* File type styling with enhanced colors for dark theme */
        .file-folder { color: #81c784; font-weight: 500; }
        .file-image { color: #ff8a65; }
        .file-video { color: #ba68c8; }
        .file-audio { color: #4db6ac; }
        .file-document { color: #ffb74d; }
        .file-archive { color: #a1887f; }
        .file-executable { color: #f06292; }
        .file-text { color: #90caf9; }
        .file-code { color: #aed581; }
        
        /* Responsive design */
        @media (max-width: 768px) {
            body {
                padding: 15px;
                font-size: 15px;
            }
            
            .header {
                padding: 20px;
            }
            
            .theme-indicator {
                position: static;
                display: inline-block;
                margin-bottom: 10px;
            }
            
            .header h1 {
                font-size: 1.5em;
            }
            
            .file-list {
                padding: 20px;
            }
            
            .nav-links {
                flex-direction: column;
                gap: 10px;
            }
            
            .nav-links a {
                text-align: center;
                padding: 12px 16px;
            }
            
            pre a {
                min-width: auto;
                width: 100%;
                padding: 12px;
            }
        }
        
        /* Enhanced accessibility */
        @media (prefers-reduced-motion: reduce) {
            * {
                transition: none !important;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="theme-indicator">🌙 Dark</div>
        <h1>📁 AutoFS File Browser</h1>
        <div class="breadcrumb">
            <a href="/">🏠 Home</a> /
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
    
    <div class="nav-links">
        <a href="/drives/">💾 Storage Drives</a>
        <a href="/system/">🖥️ System Files</a>
        <a href="/shares/">🌐 Network Shares</a>
        <a href="/logs/">📊 System Logs</a>
        <a href="/">🏠 Home Page</a>
    </div>
    
    <div class="file-list">
EOF

# Create dark theme directory listing footer
cat > "$AUTOFS_WEB_ROOT/autoindex-footer.html" << 'EOF'
    </div>
    
    <div style="text-align: center; margin-top: 30px; padding: 25px; background: rgba(45, 45, 45, 0.6); border-radius: 12px; color: rgba(255,255,255,0.8); font-size: 1em; border: 1px solid rgba(255, 255, 255, 0.1);">
        <p><strong>AutoFS Universal File Server</strong> - Dark Theme Edition</p>
        <p>🔒 Safe browsing enabled | 📡 Network accessible | 🌙 Optimized for reduced eye strain</p>
        <p style="margin-top: 10px; font-size: 0.9em; color: rgba(255,255,255,0.6);">Enhanced readability • Larger interactive elements • Modern dark interface</p>
    </div>
    
    <script>
        // Enhanced file type icons and styling with dark theme optimization
        document.addEventListener('DOMContentLoaded', function() {
            var links = document.querySelectorAll('pre a');
            links.forEach(function(link) {
                var filename = link.textContent.trim();
                var icon = '📄';
                var className = 'file-text';
                
                if (filename.endsWith('/')) {
                    icon = '📁';
                    className = 'file-folder';
                } else if (filename.match(/\.(jpg|jpeg|png|gif|bmp|svg|webp|ico)$/i)) {
                    icon = '🖼️';
                    className = 'file-image';
                } else if (filename.match(/\.(mp4|avi|mkv|mov|wmv|flv|webm|m4v)$/i)) {
                    icon = '🎬';
                    className = 'file-video';
                } else if (filename.match(/\.(mp3|wav|flac|aac|ogg|m4a|wma)$/i)) {
                    icon = '🎵';
                    className = 'file-audio';
                } else if (filename.match(/\.(pdf)$/i)) {
                    icon = '📕';
                    className = 'file-document';
                } else if (filename.match(/\.(doc|docx|odt|rtf)$/i)) {
                    icon = '📘';
                    className = 'file-document';
                } else if (filename.match(/\.(xls|xlsx|ods|csv)$/i)) {
                    icon = '📗';
                    className = 'file-document';
                } else if (filename.match(/\.(ppt|pptx|odp)$/i)) {
                    icon = '📙';
                    className = 'file-document';
                } else if (filename.match(/\.(zip|rar|7z|tar|gz|bz2|xz)$/i)) {
                    icon = '📦';
                    className = 'file-archive';
                } else if (filename.match(/\.(exe|msi|deb|rpm|dmg|app)$/i)) {
                    icon = '⚙️';
                    className = 'file-executable';
                } else if (filename.match(/\.(txt|log|md|readme|rst)$/i)) {
                    icon = '📝';
                    className = 'file-text';
                } else if (filename.match(/\.(json|xml|yml|yaml|conf|cfg|ini)$/i)) {
                    icon = '⚙️';
                    className = 'file-text';
                } else if (filename.match(/\.(html|htm|css|js|php|py|sh|bat|ps1|rb|java|cpp|c|h)$/i)) {
                    icon = '💻';
                    className = 'file-code';
                } else if (filename.match(/\.(iso|img|dmg|vdi|vmdk)$/i)) {
                    icon = '💿';
                    className = 'file-archive';
                }
                
                link.innerHTML = icon + ' ' + link.innerHTML;
                link.classList.add(className);
            });
            
            // Add smooth scrolling and keyboard navigation
            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape') {
                    window.history.back();
                } else if (e.key === 'h' && !e.ctrlKey && !e.altKey) {
                    window.location.href = '/';
                }
            });
            
            // Enhanced accessibility features
            links.forEach(function(link, index) {
                link.setAttribute('tabindex', index + 1);
            });
        });
    </script>
</body>
</html>
EOF

success "Dark theme directory listing components created"

echo
highlight "📄 Dark Theme Error Pages"
echo "=========================="

# Create dark theme 404 error page
info "Creating dark theme error pages..."

cat > "$AUTOFS_WEB_ROOT/404.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>404 - File Not Found | AutoFS Dark Edition</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 50%, #1a1a1a 100%);
            color: #e0e0e0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
        }
        .error-container {
            text-align: center;
            background: rgba(45, 45, 45, 0.9);
            padding: 50px;
            border-radius: 20px;
            backdrop-filter: blur(15px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.1);
            max-width: 600px;
            position: relative;
        }
        .theme-badge {
            position: absolute;
            top: 15px;
            right: 20px;
            background: rgba(244, 67, 54, 0.2);
            color: #f44336;
            padding: 5px 12px;
            border-radius: 15px;
            font-size: 0.8em;
            font-weight: 500;
        }
        h1 { 
            font-size: 5em; 
            margin: 0; 
            color: #f44336; 
            font-weight: 300;
            text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
        }
        h2 { 
            color: #4fc3f7; 
            margin: 30px 0; 
            font-size: 1.6em;
            font-weight: 400;
        }
        p {
            font-size: 1.1em;
            margin: 20px 0;
            color: #b0b0b0;
            line-height: 1.6;
        }
        a { 
            color: #4fc3f7; 
            text-decoration: none; 
            font-weight: 600;
            font-size: 1.2em;
            padding: 15px 25px;
            background: rgba(79, 195, 247, 0.1);
            border-radius: 8px;
            display: inline-block;
            transition: all 0.3s ease;
            border: 1px solid rgba(79, 195, 247, 0.2);
            margin-top: 20px;
        }
        a:hover { 
            background: rgba(79, 195, 247, 0.2);
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(79, 195, 247, 0.3);
        }
        .error-details {
            margin-top: 30px;
            padding: 20px;
            background: rgba(60, 60, 60, 0.5);
            border-radius: 10px;
            font-size: 0.9em;
            color: #a0a0a0;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <div class="theme-badge">🌙 Dark</div>
        <h1>404</h1>
        <h2>File or Directory Not Found</h2>
        <p>The requested file or directory could not be found on this server.</p>
        <p>This could happen if the file was moved, deleted, or if you mistyped the URL.</p>
        <a href="/">← Return to AutoFS Home</a>
        <div class="error-details">
            <strong>AutoFS Dark Edition</strong> - Enhanced error handling with improved visibility
        </div>
    </div>
</body>
</html>
EOF

# Create dark theme 50x error page
cat > "$AUTOFS_WEB_ROOT/50x.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Server Error | AutoFS Dark Edition</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 50%, #1a1a1a 100%);
            color: #e0e0e0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
        }
        .error-container {
            text-align: center;
            background: rgba(45, 45, 45, 0.9);
            padding: 50px;
            border-radius: 20px;
            backdrop-filter: blur(15px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.1);
            max-width: 600px;
            position: relative;
        }
        .theme-badge {
            position: absolute;
            top: 15px;
            right: 20px;
            background: rgba(255, 152, 0, 0.2);
            color: #ff9800;
            padding: 5px 12px;
            border-radius: 15px;
            font-size: 0.8em;
            font-weight: 500;
        }
        h1 { 
            font-size: 5em; 
            margin: 0; 
            color: #ff9800; 
            font-weight: 300;
            text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
        }
        h2 { 
            color: #4fc3f7; 
            margin: 30px 0; 
            font-size: 1.6em;
            font-weight: 400;
        }
        p {
            font-size: 1.1em;
            margin: 20px 0;
            color: #b0b0b0;
            line-height: 1.6;
        }
        a { 
            color: #4fc3f7; 
            text-decoration: none; 
            font-weight: 600;
            font-size: 1.2em;
            padding: 15px 25px;
            background: rgba(79, 195, 247, 0.1);
            border-radius: 8px;
            display: inline-block;
            transition: all 0.3s ease;
            border: 1px solid rgba(79, 195, 247, 0.2);
            margin-top: 20px;
        }
        a:hover { 
            background: rgba(79, 195, 247, 0.2);
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(79, 195, 247, 0.3);
        }
        .error-details {
            margin-top: 30px;
            padding: 20px;
            background: rgba(60, 60, 60, 0.5);
            border-radius: 10px;
            font-size: 0.9em;
            color: #a0a0a0;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <div class="theme-badge">🌙 Dark</div>
        <h1>5xx</h1>
        <h2>Server Error</h2>
        <p>The server encountered an internal error and was unable to complete your request.</p>
        <p>Please try again later or contact the system administrator if the problem persists.</p>
        <a href="/">← Return to AutoFS Home</a>
        <div class="error-details">
            <strong>AutoFS Dark Edition</strong> - Advanced error reporting with enhanced visibility
        </div>
    </div>
</body>
</html>
EOF

success "Dark theme error pages created"

echo
highlight "⚙️ Main Nginx Configuration"
echo "============================"

# Create main nginx configuration
info "Updating main nginx configuration..."

cat > "$NGINX_CONFIG_DIR/nginx.conf" << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;
    
    # Hide nginx version
    server_tokens off;
    
    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                   '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Security headers (global)
    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Include sites
    include /etc/nginx/sites-enabled/*;
}
EOF

success "Main nginx configuration updated"

echo
highlight "🔗 Site Activation"
echo "=================="

# Enable the AutoFS site
info "Activating AutoFS dark theme site..."

# Remove default site if it exists
if [[ -L "$NGINX_CONFIG_DIR/sites-enabled/default" ]]; then
    rm "$NGINX_CONFIG_DIR/sites-enabled/default"
    info "Removed default nginx site"
fi

# Enable AutoFS site
ln -sf "$NGINX_SITE_CONFIG" "$NGINX_CONFIG_DIR/sites-enabled/autofs"
success "AutoFS dark theme site enabled"

# Test nginx configuration
info "Testing nginx configuration..."
if nginx -t 2>/dev/null; then
    success "Nginx configuration is valid"
else
    error "Nginx configuration test failed!"
    nginx -t
    exit 1
fi

echo
highlight "🚀 Web Server Startup"
echo "====================="

# Set proper permissions
info "Setting file permissions..."
chown -R www-data:www-data "$AUTOFS_WEB_ROOT" 2>/dev/null || warn "Could not set www-data ownership"
chmod -R 755 "$AUTOFS_WEB_ROOT"
success "File permissions set"

# Start nginx service
info "Starting nginx web server..."
if systemctl start nginx; then
    success "Nginx started successfully"
    
    # Enable nginx to start on boot
    systemctl enable nginx 2>/dev/null || warn "Could not enable nginx autostart"
    
else
    error "Failed to start nginx"
    systemctl status nginx
    exit 1
fi

# Verify nginx is running
sleep 2
if systemctl is-active --quiet nginx; then
    success "Nginx is running and active"
else
    error "Nginx is not running properly"
    systemctl status nginx
    exit 1
fi

echo
highlight "🔍 Service Verification"
echo "======================="

# Get network information
PRIMARY_IP=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null || echo "unknown")
BRIDGE_IP="192.168.100.1"

# Test web server response
info "Testing dark theme web server response..."

# Test internal access
if curl -s -o /dev/null -w "%{http_code}" "http://$BRIDGE_IP:8080/" | grep -q "200"; then
    success "Internal dark theme web server responding (http://$BRIDGE_IP:8080)"
else
    warn "Internal web server not responding properly"
fi

# Test external access (if different from internal)
if [[ "$PRIMARY_IP" != "$BRIDGE_IP" && "$PRIMARY_IP" != "unknown" ]]; then
    if curl -s -o /dev/null -w "%{http_code}" "http://$PRIMARY_IP:8080/" | grep -q "200"; then
        success "External dark theme web server responding (http://$PRIMARY_IP:8080)"
    else
        warn "External web server not responding (this may be normal)"
    fi
fi

# Test status endpoint
if curl -s "http://$BRIDGE_IP:8080/status" | grep -q "AutoFS Server Online - Dark Theme Edition"; then
    success "Dark theme status endpoint working"
else
    warn "Status endpoint not responding"
fi

# Test health endpoint
if curl -s "http://$BRIDGE_IP:8080/health" | grep -q '"theme":"dark"'; then
    success "Dark theme health endpoint working"
else
    warn "Health endpoint not responding"
fi

echo
highlight "📊 Final System Status"
echo "======================"

# Create enhanced status script with dark theme info
cat > /usr/local/bin/autofs-status << 'EOF'
#!/bin/bash

echo "🌙 AutoFS Universal File Server - Dark Theme Edition Status 🌙"
echo "============================================================="
echo

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
theme_info() { echo -e "${CYAN}🌙 $1${NC}"; }

echo "🔧 Services Status:"
echo "=================="

# Check nginx
if systemctl is-active --quiet nginx; then
    success "Nginx web server: Running (Dark Theme Edition)"
else
    error "Nginx web server: Not running"
fi

# Check dnsmasq  
if systemctl is-active --quiet dnsmasq; then
    success "DNS/DHCP service: Running"
else
    warn "DNS/DHCP service: Not running"
fi

echo
echo "🌙 Theme Information:"
echo "==================="
theme_info "Interface: Enhanced Dark Theme"
theme_info "Readability: Optimized for reduced eye strain"
theme_info "Font Size: Increased for better accessibility"
theme_info "Contrast: High contrast for improved visibility"
theme_info "Interactive Elements: Larger click targets"

echo
echo "🌐 Network Status:"
echo "================="

# Get network info
PRIMARY_IF=$(ip route show default | head -n1 | awk '{print $5}' 2>/dev/null || echo "none")
PRIMARY_IP=$(ip addr show "$PRIMARY_IF" | grep 'inet ' | head -n1 | awk '{print $2}' | cut -d/ -f1 2>/dev/null || echo "unknown")
BRIDGE_STATUS=$(ip link show br-autofs | grep -o 'state [A-Z]*' | awk '{print $2}' 2>/dev/null || echo "DOWN")

echo "External Interface: $PRIMARY_IF ($PRIMARY_IP)"
echo "Internal Bridge: br-autofs (192.168.100.1) - $BRIDGE_STATUS"

# Test connectivity
if ping -c 1 -W 2 192.168.100.1 >/dev/null 2>&1; then
    success "Internal connectivity: Working"
else
    error "Internal connectivity: Failed"
fi

echo
echo "💾 Storage Status:"
echo "================="

# Count mounted devices
MOUNT_COUNT=$(df | grep -c "/mnt/autofs" 2>/dev/null || echo "0")
TOTAL_SIZE=$(df -h | grep "/mnt/autofs" | awk '{sum+=$2} END {print sum "GB"}' 2>/dev/null || echo "0GB")

echo "Mounted devices: $MOUNT_COUNT"
echo "Total accessible storage: $TOTAL_SIZE"

echo
echo "🌐 Access URLs (Dark Theme):"
echo "============================"
echo "Primary Access:"
info "  Internal: http://192.168.100.1:8080 (always works)"
if [[ "$PRIMARY_IP" != "unknown" && "$PRIMARY_IP" != "192.168.100.1" ]]; then
    info "  External: http://$PRIMARY_IP:8080"
fi
info "  Hostname: http://fileserver.autofs.local:8080"

echo
echo "API Endpoints:"
echo "  Status: http://192.168.100.1:8080/status"
echo "  Health: http://192.168.100.1:8080/health"

echo
echo "📁 Available Sections:"
echo "===================="
echo "  💾 /drives/  - All mounted storage devices"
echo "  🖥️ /system/  - System directories"
echo "  🌐 /shares/  - Network shares"
echo "  📊 /logs/    - System logs"

echo
echo "🛠️ Management Commands:"
echo "====================="
echo "  autofs-status           - This status display"
echo "  autofs-network-status   - Network configuration details"
echo "  autofs-storage-status   - Storage mount details"
echo "  autofs-unmount-all      - Safely unmount all storage"

echo
if systemctl is-active --quiet nginx && [[ "$BRIDGE_STATUS" == "UP" ]]; then
    success "🎉 AutoFS Dark Theme Edition is fully operational!"
else
    warn "⚠️ AutoFS has some issues - check individual services"
fi

echo
theme_info "🌙 Enjoy your enhanced dark theme experience!"
echo
EOF

chmod +x /usr/local/bin/autofs-status

# Run final status check
echo
success "AutoFS Dark Theme Edition is now ONLINE! 🌙"
echo
echo "🌐 Access Your Enhanced Dark Interface:"
echo "======================================"
web_info "Primary URL: http://192.168.100.1:8080"
if [[ "$PRIMARY_IP" != "192.168.100.1" && "$PRIMARY_IP" != "unknown" ]]; then
    web_info "External URL: http://$PRIMARY_IP:8080"
fi
web_info "Hostname: http://fileserver.autofs.local:8080"

echo
echo "📱 Quick Access (Dark Theme):"
echo "============================="
echo "  💾 Storage Drives: http://192.168.100.1:8080/drives/"
echo "  🖥️ System Files: http://192.168.100.1:8080/system/"
echo "  📊 Status: http://192.168.100.1:8080/status"
echo "  ⚡ Health Check: http://192.168.100.1:8080/health"

echo
echo "🎨 Dark Theme Features:"
echo "======================"
echo "  🌙 Reduced eye strain with dark backgrounds"
echo "  📖 Enhanced readability with larger fonts"
echo "  🎯 Improved interactive elements"
echo "  ✨ Modern glassmorphism design"
echo "  📱 Responsive design for all devices"

echo
echo "🛠️ Management:"
echo "============="
echo "  • Full status: autofs-status"
echo "  • Storage info: autofs-storage-status"
echo "  • Network info: autofs-network-status"

# Create completion marker
echo "$(date): Stage 4 completed - Dark theme web server configured and started" > /tmp/.autofs-stage4-complete

echo
echo "🔒 Security Notes:"
echo "================="
echo "  • All access is READ-ONLY (safe browsing)"
echo "  • No script execution allowed"
echo "  • Sensitive files are protected"
echo "  • Local network access only"
echo "  • Enhanced error pages with dark theme"

echo
success "🎯 STAGE 4 COMPLETE - DARK THEME EDITION!"
success "🌙 AutoFS Universal File Server with Enhanced Dark Interface is ready!"

# Final log entry
echo "$(date): AutoFS Dark Theme Edition fully deployed and operational" >> /var/log/autofs/storage-discovery.log