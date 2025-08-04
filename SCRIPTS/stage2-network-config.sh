#!/bin/bash

# AutoFS Stage 2: Network Configuration & NAT Bridge Setup
# Creates universal network compatibility with internal static IP

set -e

echo "🌉 AutoFS Stage 2: Network Configuration 🌉"
echo "=============================================="
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

# Check Stage 1 completion
info "Checking prerequisites..."
if [[ ! -f /tmp/.autofs-stage1-complete ]]; then
    # Try to verify Stage 1 by checking key packages
    warn "Stage 1 marker file not found, verifying installation manually..."
    
    missing_packages=()
    for pkg in nginx dnsmasq bridge-utils iptables; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" && ! command -v "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        error "Stage 1 not completed. Missing packages: ${missing_packages[*]}"
        echo "Please run stage1-dependencies.sh first"
        exit 1
    else
        success "Key packages detected, proceeding despite missing marker file"
        echo "$(date): Stage 1 verified retrospectively" > /tmp/.autofs-stage1-complete
    fi
else
    success "All prerequisites met"
fi

echo
info "🔍 Network Discovery Phase"
echo "=========================="

# Wait for network connectivity
info "Waiting for network connectivity (timeout: 2 minutes)..."
timeout=120
count=0
while ! ping -c 1 8.8.8.8 >/dev/null 2>&1; do
    if [[ $count -ge $timeout ]]; then
        error "No network connectivity after 2 minutes"
        echo "Please check network connection and try again"
        exit 1
    fi
    sleep 2
    ((count += 2))
    echo -n "."
done
echo
success "Network connectivity confirmed"

# Detect primary network interface and configuration
info "Detecting network configuration..."

# Find the primary interface (with default route)
PRIMARY_INTERFACE=$(ip route show default | head -n1 | awk '{print $5}' 2>/dev/null || echo "")
if [[ -z "$PRIMARY_INTERFACE" ]]; then
    error "Could not detect primary network interface"
    echo "Available interfaces:"
    ip link show | grep "^[0-9]" | awk '{print $2}' | tr -d ':'
    exit 1
fi

# Get IP address, gateway, and network info
PRIMARY_IP=$(ip addr show "$PRIMARY_INTERFACE" | grep 'inet ' | head -n1 | awk '{print $2}' | cut -d/ -f1)
PRIMARY_SUBNET=$(ip route show dev "$PRIMARY_INTERFACE" | grep 'proto kernel' | head -n1 | awk '{print $1}')
GATEWAY_IP=$(ip route show default | head -n1 | awk '{print $3}')
DNS_SERVERS=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')

if [[ -z "$PRIMARY_IP" ]]; then
    error "Could not get IP address for $PRIMARY_INTERFACE"
    exit 1
fi

success "External network detected:"
echo "   Interface: $PRIMARY_INTERFACE"
echo "   IP: $PRIMARY_IP"
echo "   Subnet: $PRIMARY_SUBNET"
echo "   Gateway: $GATEWAY_IP"
echo "   DNS: $DNS_SERVERS"

# Determine network type for informational purposes
if [[ $PRIMARY_IP =~ ^10\. ]]; then
    NETWORK_TYPE="🏢 Corporate/Enterprise (10.x.x.x)"
elif [[ $PRIMARY_IP =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
    NETWORK_TYPE="🏢 Corporate/Enterprise (172.x.x.x)"
elif [[ $PRIMARY_IP =~ ^192\.168\. ]]; then
    NETWORK_TYPE="🏠 Home/Small office (192.168.x.x)"
else
    NETWORK_TYPE="🌐 Public/Other network"
fi

info "$NETWORK_TYPE"

echo
info "🌉 NAT Bridge Creation Phase"
echo "============================"

# Internal bridge configuration
BRIDGE_NAME="br-autofs"
BRIDGE_IP="192.168.100.1"
BRIDGE_SUBNET="192.168.100.0/24"
INTERNAL_DHCP_RANGE="192.168.100.10,192.168.100.50"

info "Creating internal NAT bridge network..."

# Create bridge interface if it doesn't exist
if ! ip link show "$BRIDGE_NAME" >/dev/null 2>&1; then
    info "Creating bridge interface: $BRIDGE_NAME"
    ip link add name "$BRIDGE_NAME" type bridge
    ip addr add "$BRIDGE_IP/24" dev "$BRIDGE_NAME"
    ip link set dev "$BRIDGE_NAME" up
    success "Bridge interface created: $BRIDGE_NAME"
else
    warn "Bridge $BRIDGE_NAME already exists, using existing configuration"
fi

# Verify bridge configuration
BRIDGE_STATUS=$(ip addr show "$BRIDGE_NAME" | grep 'inet ' | awk '{print $2}' || echo "NOT_CONFIGURED")
if [[ "$BRIDGE_STATUS" == "192.168.100.1/24" ]]; then
    success "Internal bridge network created:"
    echo "   Bridge: $BRIDGE_NAME"
    echo "   Internal IP: $BRIDGE_IP/24"
else
    error "Bridge configuration failed"
    exit 1
fi

echo
info "🔄 IP Forwarding & NAT Configuration"
echo "===================================="

# Enable IP forwarding
info "Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1 >/dev/null
success "IP forwarding enabled"

# Configure iptables NAT rules
info "Setting up NAT translation rules..."

# Clear any existing rules for our bridge
iptables -t nat -D POSTROUTING -s 192.168.100.0/24 -o "$PRIMARY_INTERFACE" -j MASQUERADE 2>/dev/null || true
iptables -t nat -D PREROUTING -i "$PRIMARY_INTERFACE" -p tcp --dport 8080 -j DNAT --to-destination 192.168.100.1:8080 2>/dev/null || true
iptables -D FORWARD -i "$BRIDGE_NAME" -o "$PRIMARY_INTERFACE" -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i "$PRIMARY_INTERFACE" -o "$BRIDGE_NAME" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

# Add NAT rules
iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o "$PRIMARY_INTERFACE" -j MASQUERADE
iptables -t nat -A PREROUTING -i "$PRIMARY_INTERFACE" -p tcp --dport 8080 -j DNAT --to-destination 192.168.100.1:8080
iptables -A FORWARD -i "$BRIDGE_NAME" -o "$PRIMARY_INTERFACE" -j ACCEPT
iptables -A FORWARD -i "$PRIMARY_INTERFACE" -o "$BRIDGE_NAME" -m state --state RELATED,ESTABLISHED -j ACCEPT

success "Outbound NAT (MASQUERADE) configured"
success "Inbound NAT (DNAT) configured for port 8080"
success "NAT rules configured for transparent bridging"

echo
info "🔧 Internal Network Services"
echo "============================"

# Configure dnsmasq for internal network
info "Configuring internal DNS/DHCP services..."

# Create dnsmasq configuration for our bridge
cat > /etc/dnsmasq.d/autofs-bridge.conf << EOF
# AutoFS Internal Bridge Network Configuration
interface=$BRIDGE_NAME
bind-interfaces
domain-needed
bogus-priv
dhcp-range=$INTERNAL_DHCP_RANGE,12h
dhcp-option=option:router,$BRIDGE_IP
dhcp-option=option:dns-server,$BRIDGE_IP
domain=autofs.local
local=/autofs.local/
address=/fileserver.autofs.local/$BRIDGE_IP
address=/autofs.local/$BRIDGE_IP
EOF

# Restart dnsmasq to apply configuration
if systemctl restart dnsmasq 2>/dev/null; then
    success "Internal DNS/DHCP service configured and started"
else
    warn "Could not start dnsmasq service (may not be critical)"
fi

# Configure local hostname resolution
info "Setting up local hostname resolution..."
if ! grep -q "fileserver.autofs.local" /etc/hosts; then
    echo "$BRIDGE_IP fileserver.autofs.local autofs.local" >> /etc/hosts
    success "Local hostname resolution configured"
fi

echo
info "📊 Network Status Verification"
echo "=============================="

# Create network status monitoring script
cat > /usr/local/bin/autofs-network-status << 'EOF'
#!/bin/bash
echo "AutoFS Network Status"
echo "===================="
echo
echo "External Network:"
PRIMARY_IF=$(ip route show default | head -n1 | awk '{print $5}')
PRIMARY_IP=$(ip addr show "$PRIMARY_IF" | grep 'inet ' | head -n1 | awk '{print $2}' | cut -d/ -f1)
echo "  Interface: $PRIMARY_IF"
echo "  IP: $PRIMARY_IP"
echo "  Gateway: $(ip route show default | head -n1 | awk '{print $3}')"
echo
echo "Internal Bridge:"
echo "  Interface: br-autofs"
echo "  IP: 192.168.100.1/24"
echo "  Status: $(ip link show br-autofs | grep -o 'state [A-Z]*' | awk '{print $2}')"
echo
echo "NAT Rules Status:"
echo "  MASQUERADE: $(iptables -t nat -L POSTROUTING | grep -c MASQUERADE)"
echo "  DNAT Port 8080: $(iptables -t nat -L PREROUTING | grep -c '8080')"
echo
echo "Services:"
echo "  dnsmasq: $(systemctl is-active dnsmasq 2>/dev/null || echo 'not running')"
echo "  IP forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
echo
echo "Access URLs (once web server is running):"
echo "  External: http://$PRIMARY_IP:8080"
echo "  Internal: http://192.168.100.1:8080"
echo "  Hostname: http://fileserver.autofs.local:8080"
EOF

chmod +x /usr/local/bin/autofs-network-status

# Test basic connectivity
info "Testing network configuration..."
if ping -c 1 192.168.100.1 >/dev/null 2>&1; then
    success "Internal bridge connectivity verified"
else
    warn "Internal bridge connectivity test failed"
fi

if ping -c 1 "$GATEWAY_IP" >/dev/null 2>&1; then
    success "External gateway connectivity verified"
else
    warn "External gateway connectivity test failed"
fi

echo
info "🎉 Stage 2 Summary"
echo "=================="
success "Network configuration completed successfully!"
echo
echo "Configuration Details:"
echo "  • External Network: $PRIMARY_IP ($NETWORK_TYPE)"
echo "  • Internal Bridge: 192.168.100.1/24"
echo "  • NAT Translation: Transparent bridging enabled"
echo "  • DNS/DHCP: Internal services configured"
echo "  • Port Forwarding: 8080 → 192.168.100.1:8080"
echo
echo "Access URLs (when web server is running):"
echo "  🌐 External: http://$PRIMARY_IP:8080"
echo "  🏠 Internal: http://192.168.100.1:8080 (always works)"
echo "  📝 Hostname: http://fileserver.autofs.local:8080"
echo
echo "Management Commands:"
echo "  • Check status: autofs-network-status"
echo "  • View NAT rules: iptables -t nat -L"
echo "  • Monitor traffic: iptables -t nat -L -v"
echo
info "Ready for Stage 3: Storage Discovery"

# Create completion marker
echo "$(date): Stage 2 completed - Network configured with NAT bridge" > /tmp/.autofs-stage2-complete

echo
success "🎯 STAGE 2 COMPLETE!"
echo "Next: Run Stage 3 for storage discovery and mounting"
