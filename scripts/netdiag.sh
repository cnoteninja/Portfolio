#!/usr/bin/env bash
# netdiag.sh — all-in-one network diagnostic
# Answers "is it the network or the server?" in about ten seconds.
# From years of network monitoring: check local, then gateway, then DNS, then the world.
#
# Usage: ./netdiag.sh [host]   (default host: 8.8.8.8)

set -u
TARGET="${1:-8.8.8.8}"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
head() { echo -e "\n${CYAN}== $1 ==${NC}"; }

head "NETWORK DIAGNOSTIC — target: $TARGET"

# --- Local interface & gateway ---
head "Local interface"
if command -v ip >/dev/null 2>&1; then
    ip -brief addr show
    GATEWAY=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')
else
    ifconfig 2>/dev/null | head -20
    GATEWAY=""
fi
[ -n "${GATEWAY:-}" ] && echo "Default gateway: $GATEWAY"

# --- Ping ladder: gateway -> public DNS -> target ---
head "Ping tests"
for h in "${GATEWAY:-}" "8.8.8.8" "$TARGET"; do
    [ -z "$h" ] && continue
    OUT=$(ping -c 2 -W 2 "$h" 2>/dev/null)
    if [ $? -eq 0 ]; then
        AVG=$(echo "$OUT" | awk -F'/' '/rtt|round-trip/ {print $5}')
        ok "ping $h — avg ${AVG:-?} ms"
    else
        fail "ping $h — no reply"
    fi
done

# --- DNS ---
head "DNS resolution"
if getent hosts google.com >/dev/null 2>&1 || nslookup google.com >/dev/null 2>&1; then
    ok "DNS resolves google.com"
else
    fail "DNS resolution failed — check DNS server settings"
fi
grep -v '^#' /etc/resolv.conf 2>/dev/null | grep nameserver || true

# --- Public IP ---
head "Public IP"
PUB=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || true)
[ -n "$PUB" ] && ok "Public IP: $PUB" || warn "Could not determine public IP"

# --- Port check ---
head "Port check ($TARGET:443)"
if timeout 5 bash -c ">/dev/tcp/$TARGET/443" 2>/dev/null; then
    ok "$TARGET:443 reachable"
else
    fail "$TARGET:443 not reachable"
fi

# --- Route trace (first 8 hops) ---
if command -v traceroute >/dev/null 2>&1; then
    head "Traceroute (first 8 hops)"
    traceroute -m 8 -w 2 "$TARGET" 2>/dev/null | head -12
elif command -v tracepath >/dev/null 2>&1; then
    head "Tracepath (first 8 hops)"
    tracepath -m 8 "$TARGET" 2>/dev/null | head -12
fi

echo -e "\n${CYAN}== DONE ==${NC}\n"
