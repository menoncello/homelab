#!/bin/bash

# Network Speed Test Script for Homelab
# Tests internet speed and inter-node throughput

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
POP_OS_IP="192.168.31.5"
XEON01_IP="192.168.31.6"
SSH_USER="eduardo"
IPERF_PORT=5201
TEST_DURATION=30

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Homelab Network Speed Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to test connectivity
test_connectivity() {
    local host=$1
    local name=$2

    echo -e "${YELLOW}Testing connectivity to ${name}...${NC}"
    if ping -c 3 -W 2 "$host" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ ${name} is reachable${NC}"
        return 0
    else
        echo -e "${RED}✗ ${name} is unreachable${NC}"
        return 1
    fi
}

# Function to test internet speed on remote host
test_internet_speed() {
    local host=$1
    local name=$2

    echo -e "\n${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Testing Internet Speed: ${name}${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"

    ssh "${SSH_USER}@${host}" "command -v speedtest-cli >/dev/null 2>&1" || {
        echo -e "${RED}speedtest-cli not found on ${name}${NC}"
        echo -e "${YELLOW}Install with: sudo apt install speedtest-cli -y${NC}"
        return 1
    }

    echo -e "${YELLOW}Running speedtest on ${name}...${NC}"
    ssh "${SSH_USER}@${host}" "speedtest-cli --simple"
    echo ""
}

# Function to setup iperf3 server
setup_iperf3_server() {
    local host=$1

    # Kill any existing iperf3 processes
    ssh "${SSH_USER}@${host}" "sudo pkill -9 iperf3" 2>/dev/null || true

    # Start iperf3 server in background
    ssh "${SSH_USER}@${host}" "nohup iperf3 -s -p ${IPERF_PORT} > /tmp/iperf3-server.log 2>&1 &" &

    # Wait for server to start
    sleep 2

    # Verify server is running
    if ssh "${SSH_USER}@${host}" "pgrep -x iperf3 >/dev/null"; then
        return 0
    else
        return 1
    fi
}

# Function to kill iperf3 server
kill_iperf3_server() {
    local host=$1
    ssh "${SSH_USER}@${host}" "sudo pkill -9 iperf3" 2>/dev/null || true
}

# Function to test iperf3 between hosts
test_iperf3() {
    local server_host=$1
    local server_name=$2
    local client_host=$3
    local client_name=$4

    echo -e "\n${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Testing: ${client_name} → ${server_name}${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"

    # Setup server
    if ! setup_iperf3_server "$server_host"; then
        echo -e "${RED}Failed to start iperf3 server on ${server_name}${NC}"
        return 1
    fi

    # Run client test
    echo -e "${YELLOW}Running iperf3 for ${TEST_DURATION}s...${NC}"
    ssh "${SSH_USER}@${client_host}" "iperf3 -c ${server_host} -p ${IPERF_PORT} -t ${TEST_DURATION}" || {
        echo -e "${RED}iperf3 test failed${NC}"
        kill_iperf3_server "$server_host"
        return 1
    }

    # Cleanup
    kill_iperf3_server "$server_host"
    echo ""
}

# Check local requirements
echo -e "${YELLOW}Checking local requirements...${NC}"

if ! command_exists iperf3; then
    echo -e "${RED}iperf3 not found locally${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}Install with: brew install iperf3${NC}"
    else
        echo -e "${YELLOW}Install with: sudo apt install iperf3 -y${NC}"
    fi
    exit 1
fi

echo -e "${GREEN}✓ iperf3 installed locally${NC}"
echo ""

# Test connectivity to all nodes
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Connectivity Test${NC}"
echo -e "${BLUE}========================================${NC}"

POP_OS_REACHABLE=false
XEON01_REACHABLE=false

if test_connectivity "$POP_OS_IP" "pop-os"; then
    POP_OS_REACHABLE=true
fi

if test_connectivity "$XEON01_IP" "xeon01"; then
    XEON01_REACHABLE=true
fi

# Test internet speed on each node
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Internet Speed Tests${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$POP_OS_REACHABLE" = true ]; then
    test_internet_speed "$POP_OS_IP" "pop-os"
fi

if [ "$XEON01_REACHABLE" = true ]; then
    test_internet_speed "$XEON01_IP" "xeon01"
fi

# Test local machine internet speed
echo -e "\n${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}Testing Internet Speed: Local Machine${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

if command_exists speedtest-cli; then
    echo -e "${YELLOW}Running speedtest locally...${NC}"
    speedtest-cli --simple
elif command_exists speedtest; then
    echo -e "${YELLOW}Running speedtest locally...${NC}"
    speedtest
else
    echo -e "${YELLOW}speedtest not found. Install with:${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "  brew tap teamookla/speedtest && brew install speedtest"
    else
        echo -e "  sudo apt install speedtest-cli -y"
    fi
fi

echo ""

# Test inter-node throughput
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Network Throughput Tests (Local)${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$POP_OS_REACHABLE" = true ] && [ "$XEON01_REACHABLE" = true ]; then
    # Test xeon01 → pop-os
    test_iperf3 "$POP_OS_IP" "pop-os" "$XEON01_IP" "xeon01"

    # Test pop-os → xeon01
    test_iperf3 "$XEON01_IP" "xeon01" "$POP_OS_IP" "pop-os"
fi

# Test local machine to nodes
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Network Throughput Tests (to Local)${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$POP_OS_REACHABLE" = true ]; then
    echo -e "\n${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Testing: Local → pop-os${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"

    setup_iperf3_server "$POP_OS_IP"
    echo -e "${YELLOW}Running iperf3 for ${TEST_DURATION}s...${NC}"
    iperf3 -c "$POP_OS_IP" -p "$IPERF_PORT" -t "$TEST_DURATION"
    kill_iperf3_server "$POP_OS_IP"
    echo ""
fi

if [ "$XEON01_REACHABLE" = true ]; then
    echo -e "\n${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Testing: Local → xeon01${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"

    setup_iperf3_server "$XEON01_IP"
    echo -e "${YELLOW}Running iperf3 for ${TEST_DURATION}s...${NC}"
    iperf3 -c "$XEON01_IP" -p "$IPERF_PORT" -t "$TEST_DURATION"
    kill_iperf3_server "$XEON01_IP"
    echo ""
fi

# Test nodes to local machine
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Network Throughput Tests (from Local)${NC}"
echo -e "${BLUE}========================================${NC}"

# Start iperf3 server locally
echo -e "${YELLOW}Starting iperf3 server locally...${NC}"
iperf3 -s -p "$IPERF_PORT" -D
sleep 2

if [ "$POP_OS_REACHABLE" = true ]; then
    echo -e "\n${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Testing: pop-os → Local${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"

    ssh "${SSH_USER}@${POP_OS_IP}" "iperf3 -c ${LOCAL_IP} -p ${IPERF_PORT} -t ${TEST_DURATION}" || {
        echo -e "${RED}Failed to connect to local iperf3 server${NC}"
        echo -e "${YELLOW}Make sure your firewall allows port ${IPERF_PORT}${NC}"
    }
    echo ""
fi

if [ "$XEON01_REACHABLE" = true ]; then
    echo -e "\n${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}Testing: xeon01 → Local${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"

    ssh "${SSH_USER}@${XEON01_IP}" "iperf3 -c ${LOCAL_IP} -p ${IPERF_PORT} -t ${TEST_DURATION}" || {
        echo -e "${RED}Failed to connect to local iperf3 server${NC}"
        echo -e "${YELLOW}Make sure your firewall allows port ${IPERF_PORT}${NC}"
    }
    echo ""
fi

# Kill local iperf3 server
pkill -9 iperf3 2>/dev/null || true

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Test Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}All tests finished!${NC}"
echo ""

# Network configuration summary
echo -e "${BLUE}Network Configuration:${NC}"
echo -e "  pop-os (Manager): ${POP_OS_IP}"
echo -e "  xeon01 (Worker):  ${XEON01_IP}"
echo -e "  Local Machine:    ${LOCAL_IP:-Unknown}"
echo ""

echo -e "${YELLOW}Note: Results show actual throughput. For 2.5Gbps networks, expect ~2.3-2.5 Gbps${NC}"
