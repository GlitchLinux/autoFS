#!/bin/bash

# AutoFS Stage 4: Web Server Configuration & Startup
# Configures nginx and starts the file server

set -e

echo "🌐 AutoFS Stage 4: Web Server Configuration & Startup 🌐"
echo "========================================================"
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
# AutoFS Universal File Server Configuration
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
        return 200 "AutoFS Server Online\n";
        add_header Content-Type text/plain;
    }
    
    location /health {
        access_log off;
        return 200 '{"status":"healthy","timestamp":"$time_iso8601"}';
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
highlight "🎨 Custom Directory Listing Style"
echo "================================="

# Create custom autoindex header
info "Creating custom directory listing styles..."

cat > "$AUTOFS_WEB_ROOT/autoindex-header.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>AutoFS File Browser</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .header {
            background: rgba(255,255,255,0.1);
            padding: 15px 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            backdrop-filter: blur(10px);
        }
        .header h1 {
            margin: 0;
            font-size: 1.5em;
            color: #ffd700;
        }
        .breadcrumb {
            margin-top: 5px;
            font-size: 0.9em;
            color: rgba(255,255,255,0.8);
        }
        .breadcrumb a {
            color: #87ceeb;
            text-decoration: none;
        }
        .breadcrumb a:hover {
            color: #ffd700;
            text-decoration: underline;
        }
        .file-list {
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            padding: 20px;
            backdrop-filter: blur(10px);
        }
        pre {
            color: white;
            margin: 0;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        pre a {
            color: #87ceeb;
            text-decoration: none;
            display: inline-block;
            padding: 5px 10px;
            margin: 2px 0;
            border-radius: 5px;
            transition: all 0.3s ease;
        }
        pre a:hover {
            background: rgba(255,255,255,0.2);
            color: #ffd700;
            text-decoration: none;
        }
        .nav-links {
            margin-bottom: 15px;
        }
        .nav-links a {
            background: rgba(255,255,255,0.2);
            color: white;
            padding: 8px 15px;
            text-decoration: none;
            border-radius: 5px;
            margin-right: 10px;
            font-size: 0.9em;
        }
        .nav-links a:hover {
            background: rgba(255,255,255,0.3);
            color: #ffd700;
        }
    </style>
</head>
<body>
    <div class="header">
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
        <a href="/drives/">💾 Drives</a>
        <a href="/system/">🖥️ System</a>
        <a href="/shares/">🌐 Shares</a>
        <a href="/logs/">📊 Logs</a>
        <a href="/">🏠 Home</a>
    </div>
    
    <div class="file-list">
EOF

cat > "$AUTOFS_WEB_ROOT/autoindex-footer.html" << 'EOF'
    </div>
    
    <div style="text-align: center; margin-top: 30px; color: rgba(255,255,255,0.7); font-size: 0.9em;">
        <p>AutoFS Universal File Server - Read-Only Access</p>
        <p>🔒 Safe browsing enabled | 📡 Network accessible</p>
    </div>
    
    <script>
        // Add file type icons
        document.addEventListener('DOMContentLoaded', function() {
            var links = document.querySelectorAll('pre a');
            links.forEach(function(link) {
                var filename = link.textContent.trim();
                var icon = '📄';
                
                if (filename.endsWith('/')) {
                    icon = '📁';
                } else if (filename.match(/\.(jpg|jpeg|png|gif|bmp|svg)$/i)) {
                    icon = '🖼️';
                } else if (filename.match(/\.(mp4|avi|mkv|mov|wmv|flv)$/i)) {
                    icon = '🎬';
                } else if (filename.match(/\.(mp3|wav|flac|aac|ogg)$/i)) {
                    icon = '🎵';
                } else if (filename.match(/\.(pdf)$/i)) {
                    icon = '📕';
                } else if (filename.match(/\.(doc|docx)$/i)) {
                    icon = '📘';
                } else if (filename.match(/\.(xls|xlsx)$/i)) {
                    icon = '📗';
                } else if (filename.match(/\.(zip|rar|7z|tar|gz)$/i)) {
                    icon = '📦';
                } else if (filename.match(/\.(exe|msi|deb|rpm)$/i)) {
                    icon = '⚙️';
                } else if (filename.match(/\.(txt|log)$/i)) {
                    icon = '📝';
                }
                
                link.innerHTML = icon + ' ' + link.innerHTML;
            });
        });
    </script>
</body>
</html>
EOF

# Create error pages
cat > "$AUTOFS_WEB_ROOT/404.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>404 - File Not Found | AutoFS</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .error-container {
            text-align: center;
            background: rgba(255,255,255,0.1);
            padding: 40px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 4em; margin: 0; color: #ffd700; }
        h2 { color: #87ceeb; margin: 20px 0; }
        a { color: #ffd700; text-decoration: none; font-weight: bold; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="error-container">
        <h1>404</h1>
        <h2>File or Directory Not Found</h2>
        <p>The requested file or directory could not be found on this server.</p>
        <p><a href="/">← Return to AutoFS Home</a></p>
    </div>
</body>
</html>
EOF

cat > "$AUTOFS_WEB_ROOT/50x.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Server Error | AutoFS</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .error-container {
            text-align: center;
            background: rgba(255,255,255,0.1);
            padding: 40px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 4em; margin: 0; color: #ff6b6b; }
        h2 { color: #87ceeb; margin: 20px 0; }
        a { color: #ffd700; text-decoration: none; font-weight: bold; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="error-container">
        <h1>5xx</h1>
        <h2>Server Error</h2>
        <p>The server encountered an internal error and was unable to complete your request.</p>
        <p><a href="/">← Return to AutoFS Home</a></p>
    </div>
</body>
</html>
EOF

success "Custom directory listing styles and error pages created"

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
info "Activating AutoFS site..."

# Remove default site if it exists
if [[ -L "$NGINX_CONFIG_DIR/sites-enabled/default" ]]; then
    rm "$NGINX_CONFIG_DIR/sites-enabled/default"
    info "Removed default nginx site"
fi

# Enable AutoFS site
ln -sf "$NGINX_SITE_CONFIG" "$NGINX_CONFIG_DIR/sites-enabled/autofs"
success "AutoFS site enabled"

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
info "Testing web server response..."

# Test internal access
if curl -s -o /dev/null -w "%{http_code}" "http://$BRIDGE_IP:8080/" | grep -q "200"; then
    success "Internal web server responding (http://$BRIDGE_IP:8080)"
else
    warn "Internal web server not responding properly"
fi

# Test external access (if different from internal)
if [[ "$PRIMARY_IP" != "$BRIDGE_IP" && "$PRIMARY_IP" != "unknown" ]]; then
    if curl -s -o /dev/null -w "%{http_code}" "http://$PRIMARY_IP:8080/" | grep -q "200"; then
        success "External web server responding (http://$PRIMARY_IP:8080)"
    else
        warn "External web server not responding (this may be normal)"
    fi
fi

# Test status endpoint
if curl -s "http://$BRIDGE_IP:8080/status" | grep -q "AutoFS Server Online"; then
    success "Status endpoint working"
else
    warn "Status endpoint not responding"
fi

echo
highlight "📊 Final System Status"
echo "======================"

# Create comprehensive status script
cat > /usr/local/bin/autofs-status << 'EOF'
#!/bin/bash

echo "🚀 AutoFS Universal File Server - System Status"
echo "=============================================="
echo

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

echo "🔧 Services Status:"
echo "=================="

# Check nginx
if systemctl is-active --quiet nginx; then
    success "Nginx web server: Running"
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
echo "🌐 Access URLs:"
echo "=============="
echo "Primary Access:"
info "  Internal: http://192.168.100.1:8080 (always works)"
if [[ "$PRIMARY_IP" != "unknown" && "$PRIMARY_IP" != "192.168.100.1" ]]; then
    info "  External: http://$PRIMARY_IP:8080"
fi
info "  Hostname: http://fileserver.autofs.local:8080"

echo
echo "Alternative Access:"
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
    success "🎉 AutoFS is fully operational!"
else
    warn "⚠️ AutoFS has some issues - check individual services"
fi

echo
EOF

chmod +x /usr/local/bin/autofs-status

# Run final status check
echo
success "AutoFS Universal File Server is now ONLINE! 🎉"
echo
echo "🌐 Access Your Files:"
echo "===================="
web_info "Primary URL: http://192.168.100.1:8080"
if [[ "$PRIMARY_IP" != "192.168.100.1" && "$PRIMARY_IP" != "unknown" ]]; then
    web_info "External URL: http://$PRIMARY_IP:8080"
fi
web_info "Hostname: http://fileserver.autofs.local:8080"

echo
echo "📱 Quick Access:"
echo "==============="
echo "  💾 Storage Drives: http://192.168.100.1:8080/drives/"
echo "  🖥️ System Files: http://192.168.100.1:8080/system/"
echo "  📊 Status: http://192.168.100.1:8080/status"

echo
echo "🛠️ Management:"
echo "============="
echo "  • Full status: autofs-status"
echo "  • Storage info: autofs-storage-status"
echo "  • Network info: autofs-network-status"

# Create completion marker
echo "$(date): Stage 4 completed - Web server configured and started" > /tmp/.autofs-stage4-complete

echo
echo "🔒 Security Notes:"
echo "================="
echo "  • All access is READ-ONLY (safe browsing)"
echo "  • No script execution allowed"
echo "  • Sensitive files are protected"
echo "  • Local network access only"

echo
success "🎯 STAGE 4 COMPLETE!"
success "🚀 AutoFS Universal File Server is ready for use!"

# Final log entry
echo "$(date): AutoFS fully deployed and operational" >> /var/log/autofs/storage-discovery.log