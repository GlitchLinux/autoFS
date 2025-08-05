#!/bin/bash

# AutoFS True Dark Theme Application Script
# Applies a proper dark theme like Google/Claude - clean, modern, dark backgrounds

set -e

echo "🌚 AutoFS True Dark Theme Application 🌚"
echo "========================================"
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

# Check if AutoFS is installed
if [[ ! -d "$AUTOFS_WEB_ROOT" ]]; then
    error "AutoFS web root not found at $AUTOFS_WEB_ROOT"
    echo "Please run the AutoFS installation stages first"
    exit 1
fi

info "Applying TRUE dark theme like Google/Claude interfaces..."

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
info "🌚 Creating TRUE Dark Theme Main Page"
echo "====================================="

# Create true dark theme main page (like Google/Claude)
cat > "$AUTOFS_WEB_ROOT/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AutoFS - Universal File Server</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #1a1a1a;
            color: #e8eaed;
            min-height: 100vh;
            font-size: 16px;
            line-height: 1.5;
            padding: 20px;
        }
        
        .container { 
            max-width: 1200px;
            margin: 0 auto;
            background: #202124;
            border-radius: 12px;
            padding: 32px;
            box-shadow: 0 4px 16px rgba(0,0,0,0.3);
            border: 1px solid #303134;
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding-bottom: 24px;
            border-bottom: 1px solid #303134;
        }
        
        h1 { 
            font-size: 2.8em;
            color: #e8eaed;
            font-weight: 400;
            margin-bottom: 12px;
        }
        
        .subtitle {
            color: #9aa0a6;
            font-size: 1.1em;
            font-weight: 400;
        }
        
        .status { 
            background: #137333;
            color: #e8f5e8;
            padding: 12px 20px;
            border-radius: 8px;
            margin: 24px 0;
            font-size: 1em;
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }
        
        .section { 
            margin: 32px 0;
            background: #292a2d;
            padding: 24px;
            border-radius: 8px;
            border: 1px solid #303134;
        }
        
        .section h2 { 
            color: #e8eaed;
            font-size: 1.5em;
            font-weight: 500;
            margin-bottom: 16px;
            padding-bottom: 8px;
            border-bottom: 1px solid #3c4043;
        }
        
        .grid { 
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        
        .card { 
            background: #3c4043;
            border: 1px solid #5f6368;
            border-radius: 8px;
            padding: 20px;
            transition: all 0.2s ease;
        }
        
        .card:hover {
            background: #48494c;
            border-color: #8ab4f8;
            transform: translateY(-1px);
        }
        
        .card h3 { 
            color: #e8eaed;
            font-size: 1.2em;
            font-weight: 500;
            margin-bottom: 12px;
        }
        
        .card p {
            color: #9aa0a6;
            font-size: 0.95em;
            line-height: 1.4;
            margin-bottom: 16px;
        }
        
        .btn {
            background: #8ab4f8;
            color: #1a1a1a;
            padding: 10px 16px;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 500;
            font-size: 0.95em;
            display: inline-block;
            transition: all 0.2s ease;
            border: none;
            cursor: pointer;
        }
        
        .btn:hover {
            background: #aecbfa;
            text-decoration: none;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 16px;
            margin-top: 20px;
        }
        
        .info-item {
            background: #3c4043;
            padding: 16px;
            border-radius: 6px;
            border-left: 3px solid #8ab4f8;
        }
        
        .info-item strong {
            color: #e8eaed;
            display: block;
            margin-bottom: 4px;
        }
        
        .info-item span {
            color: #9aa0a6;
            font-size: 0.9em;
        }
        
        code {
            background: #2d2e30;
            color: #8ab4f8;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Roboto Mono', monospace;
            font-size: 0.9em;
        }
        
        .theme-indicator {
            position: absolute;
            top: 20px;
            right: 20px;
            background: #292a2d;
            color: #9aa0a6;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.8em;
            border: 1px solid #3c4043;
        }
        
        /* Responsive */
        @media (max-width: 768px) {
            body { padding: 16px; }
            .container { padding: 20px; }
            h1 { font-size: 2.2em; }
            .grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="theme-indicator">🌚 True Dark</div>
    <div class="container">
        <div class="header">
            <h1>🚀 AutoFS Universal File Server</h1>
            <div class="subtitle">Modern file server with clean dark interface</div>
            <div class="status">
                <span>🟢</span>
                <span>System Online - True Dark Theme Active</span>
            </div>
        </div>
        
        <div class="section">
            <h2>📁 Browse Storage</h2>
            <div class="grid">
                <div class="card">
                    <h3>💾 Storage Drives</h3>
                    <p>Access all mounted drives including Windows partitions, USB devices, and external storage.</p>
                    <a href="/drives/" class="btn">Browse Drives</a>
                </div>
                <div class="card">
                    <h3>🖥️ System Directories</h3>
                    <p>Explore system directories including home folders and configuration files.</p>
                    <a href="/system/" class="btn">Browse System</a>
                </div>
            </div>
        </div>
        
        <div class="section">
            <h2>ℹ️ System Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <strong>Server</strong>
                    <span>AutoFS Live System</span>
                </div>
                <div class="info-item">
                    <strong>Theme</strong>
                    <span>True Dark Mode</span>
                </div>
                <div class="info-item">
                    <strong>Access</strong>
                    <span><code>http://192.168.100.1:8080</code></span>
                </div>
                <div class="info-item">
                    <strong>Security</strong>
                    <span>Read-only access enabled</span>
                </div>
            </div>
        </div>
        
        <div class="section">
            <h2>🔗 Quick Access</h2>
            <div class="grid">
                <div class="card">
                    <h3>📊 Server Status</h3>
                    <p>Check real-time system health and service status.</p>
                    <a href="/status" class="btn">View Status</a>
                </div>
                <div class="card">
                    <h3>📋 System Logs</h3>
                    <p>Monitor system activity and troubleshoot issues.</p>
                    <a href="/logs/" class="btn">View Logs</a>
                </div>
                <div class="card">
                    <h3>🌐 Network Shares</h3>
                    <p>Access shared network resources and remote storage.</p>
                    <a href="/shares/" class="btn">Browse Shares</a>
                </div>
                <div class="card">
                    <h3>⚡ Health Check</h3>
                    <p>Real-time system health monitoring endpoint.</p>
                    <a href="/health" class="btn">Health API</a>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
EOF

success "True dark theme main page created"

echo
info "🗂️ Creating True Dark Directory Listings"
echo "========================================"

# Create true dark theme directory listing
cat > "$AUTOFS_WEB_ROOT/autoindex-header.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>AutoFS File Browser</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #1a1a1a;
            color: #e8eaed;
            min-height: 100vh;
            font-size: 15px;
            line-height: 1.4;
            padding: 20px;
        }
        
        .header {
            background: #202124;
            border: 1px solid #303134;
            border-radius: 8px;
            padding: 20px 24px;
            margin-bottom: 20px;
        }
        
        .header h1 {
            color: #e8eaed;
            font-size: 1.5em;
            font-weight: 500;
            margin-bottom: 8px;
        }
        
        .breadcrumb {
            color: #9aa0a6;
            font-size: 0.95em;
        }
        
        .breadcrumb a {
            color: #8ab4f8;
            text-decoration: none;
            padding: 2px 4px;
            border-radius: 3px;
            transition: background 0.2s ease;
        }
        
        .breadcrumb a:hover {
            background: #3c4043;
            text-decoration: none;
        }
        
        .nav-links {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 20px;
        }
        
        .nav-links a {
            background: #292a2d;
            color: #e8eaed;
            padding: 10px 16px;
            text-decoration: none;
            border-radius: 6px;
            font-size: 0.9em;
            font-weight: 500;
            border: 1px solid #3c4043;
            transition: all 0.2s ease;
        }
        
        .nav-links a:hover {
            background: #3c4043;
            border-color: #8ab4f8;
        }
        
        .file-list {
            background: #202124;
            border: 1px solid #303134;
            border-radius: 8px;
            padding: 20px;
        }
        
        pre {
            color: #e8eaed;
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 14px;
            line-height: 1.6;
        }
        
        pre a {
            color: #8ab4f8;
            text-decoration: none;
            display: block;
            padding: 8px 12px;
            margin: 2px 0;
            border-radius: 4px;
            transition: all 0.2s ease;
            font-size: 14px;
            border: 1px solid transparent;
        }
        
        pre a:hover {
            background: #292a2d;
            border-color: #3c4043;
            text-decoration: none;
            transform: translateX(4px);
        }
        
        /* File type colors for dark theme */
        .file-folder { color: #fdd663; }
        .file-image { color: #ff8a80; }
        .file-video { color: #ce93d8; }
        .file-audio { color: #80cbc4; }
        .file-document { color: #ffcc02; }
        .file-archive { color: #bcaaa4; }
        .file-executable { color: #f48fb1; }
        .file-text { color: #81d4fa; }
        .file-code { color: #a5d6a7; }
        
        .theme-indicator {
            position: absolute;
            top: 20px;
            right: 20px;
            background: #292a2d;
            color: #9aa0a6;
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 0.75em;
            border: 1px solid #3c4043;
        }
        
        /* Responsive */
        @media (max-width: 768px) {
            body { padding: 16px; }
            .header { padding: 16px; }
            .nav-links { flex-direction: column; }
            .file-list { padding: 16px; }
            .theme-indicator {
                position: static;
                display: inline-block;
                margin-bottom: 16px;
            }
        }
    </style>
</head>
<body>
    <div class="theme-indicator">🌚 True Dark</div>
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

# Create true dark theme directory listing footer
cat > "$AUTOFS_WEB_ROOT/autoindex-footer.html" << 'EOF'
    </div>
    
    <div style="text-align: center; margin-top: 24px; padding: 16px; background: #292a2d; border-radius: 6px; color: #9aa0a6; font-size: 0.9em; border: 1px solid #3c4043;">
        <p><strong style="color: #e8eaed;">AutoFS Universal File Server</strong> - True Dark Theme</p>
        <p style="margin-top: 8px;">🔒 Safe browsing • 📡 Network accessible • 🌚 Clean dark interface</p>
    </div>
    
    <script>
        // File type icons and styling
        document.addEventListener('DOMContentLoaded', function() {
            var links = document.querySelectorAll('pre a');
            links.forEach(function(link) {
                var filename = link.textContent.trim();
                var icon = '📄';
                var className = 'file-text';
                
                if (filename.endsWith('/')) {
                    icon = '📁';
                    className = 'file-folder';
                } else if (filename.match(/\.(jpg|jpeg|png|gif|bmp|svg|webp)$/i)) {
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
                    icon = '📝';
                    className = 'file-text';
                } else if (filename.match(/\.(json|xml|yml|yaml|conf|cfg)$/i)) {
                    icon = '⚙️';
                    className = 'file-text';
                } else if (filename.match(/\.(html|htm|css|js|php|py|sh|bat)$/i)) {
                    icon = '💻';
                    className = 'file-code';
                }
                
                link.innerHTML = icon + ' ' + link.innerHTML;
                link.classList.add(className);
            });
            
            // Keyboard shortcuts
            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape') {
                    window.history.back();
                } else if (e.key === 'h' && !e.ctrlKey && !e.altKey) {
                    window.location.href = '/';
                }
            });
        });
    </script>
</body>
</html>
EOF

success "True dark theme directory listings created"

echo
info "📄 Creating True Dark Error Pages"
echo "================================="

# Create true dark 404 page
cat > "$AUTOFS_WEB_ROOT/404.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>404 - Not Found | AutoFS</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a1a;
            color: #e8eaed;
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
            padding: 40px;
            border-radius: 12px;
            border: 1px solid #303134;
            max-width: 500px;
            width: 100%;
        }
        h1 { 
            font-size: 4em;
            color: #ea4335;
            font-weight: 400;
            margin: 0 0 16px 0;
        }
        h2 { 
            color: #e8eaed;
            font-weight: 500;
            margin-bottom: 16px;
            font-size: 1.5em;
        }
        p {
            color: #9aa0a6;
            margin-bottom: 24px;
            line-height: 1.4;
        }
        .btn {
            background: #8ab4f8;
            color: #1a1a1a;
            padding: 12px 20px;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 500;
            display: inline-block;
            transition: background 0.2s ease;
        }
        .btn:hover {
            background: #aecbfa;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <h1>404</h1>
        <h2>Not Found</h2>
        <p>The requested file or directory could not be found.</p>
        <a href="/" class="btn">← Back to Home</a>
    </div>
</body>
</html>
EOF

# Create true dark 50x page
cat > "$AUTOFS_WEB_ROOT/50x.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Server Error | AutoFS</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a1a;
            color: #e8eaed;
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
            padding: 40px;
            border-radius: 12px;
            border: 1px solid #303134;
            max-width: 500px;
            width: 100%;
        }
        h1 { 
            font-size: 4em;
            color: #fbbc04;
            font-weight: 400;
            margin: 0 0 16px 0;
        }
        h2 { 
            color: #e8eaed;
            font-weight: 500;
            margin-bottom: 16px;
            font-size: 1.5em;
        }
        p {
            color: #9aa0a6;
            margin-bottom: 24px;
            line-height: 1.4;
        }
        .btn {
            background: #8ab4f8;
            color: #1a1a1a;
            padding: 12px 20px;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 500;
            display: inline-block;
            transition: background 0.2s ease;
        }
        .btn:hover {
            background: #aecbfa;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <h1>5xx</h1>
        <h2>Server Error</h2>
        <p>The server encountered an error and could not complete your request.</p>
        <a href="/" class="btn">← Back to Home</a>
    </div>
</body>
</html>
EOF

success "True dark error pages created"

echo
info "🔧 Setting Permissions and Restarting Server"
echo "============================================="

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
        success "True dark theme web server is responding"
    else
        warn "Web server may not be fully ready yet"
    fi
else
    error "Failed to restart nginx"
    exit 1
fi

echo
success "🌚 TRUE Dark Theme Successfully Applied!"
echo
echo "🎨 What Changed:"
echo "  • Background: Now true dark (#1a1a1a) like Google/Claude"
echo "  • Cards: Clean dark grey (#202124, #292a2d)"
echo "  • Text: Proper contrast (#e8eaed, #9aa0a6)"
echo "  • Accent: Google-like blue (#8ab4f8)"
echo "  • Borders: Subtle dark borders (#303134)"
echo "  • No more purple/blue gradients!"
echo
echo "🌐 Access Your TRUE Dark Interface:"
echo "  📱 Main: http://192.168.100.1:8080"
echo "  📁 Drives: http://192.168.100.1:8080/drives/"
echo "  🖥️ System: http://192.168.100.1:8080/system/"
echo
success "🎯 Now you have a PROPER dark theme like Google and Claude! 🌚"
