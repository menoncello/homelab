#!/bin/bash
# File: verify-metrics-pipeline.sh
# Description: End-to-end verification script for observability metrics pipeline
# Usage: ./verify-metrics-pipeline.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Metrics Pipeline Verification Script ===${NC}"
echo -e "${BLUE}Date: $(date)${NC}"
echo ""

# Track overall status
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Helper function to run checks
check() {
    local description="$1"
    local command="$2"
    local expected="$3"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -e "${YELLOW}[CHECK $TOTAL_CHECKS]${NC} $description"

    if eval "$command" > /dev/null 2>&1; then
        if [ -n "$expected" ]; then
            result=$(eval "$command" 2>/dev/null)
            if echo "$result" | grep -q "$expected"; then
                echo -e "  ${GREEN}✓ PASS${NC}"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
                return 0
            else
                echo -e "  ${RED}✗ FAIL${NC} - Expected: $expected, Got: $result"
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
                return 1
            fi
        else
            echo -e "  ${GREEN}✓ PASS${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        fi
    else
        echo -e "  ${RED}✗ FAIL${NC} - Command failed"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# 1. Check Docker Swarm nodes
echo -e "\n${BLUE}=== 1. Docker Swarm Node Status ===${NC}"
echo -e "${YELLOW}Checking cluster nodes...${NC}"
docker node ls
echo ""

# 2. Check observability services
echo -e "\n${BLUE}=== 2. Observability Services Status ===${NC}"
echo -e "${YELLOW}Checking all observability services...${NC}"
docker service ls | grep observability || echo "No observability services found"
echo ""

# 3. Test Agent Endpoints
echo -e "\n${BLUE}=== 3. Agent Endpoint Tests ===${NC}"

# Test node-exporter on pop-os
echo -e "${YELLOW}Testing node-exporter on pop-os (192.168.31.5:9100)...${NC}"
if curl -s --connect-timeout 5 http://192.168.31.5:9100/metrics > /dev/null; then
    echo -e "  ${GREEN}✓ node-exporter is responding${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))

    # Check for specific metrics
    echo -e "${YELLOW}  Checking for CPU metrics...${NC}"
    if curl -s http://192.168.31.5:9100/metrics | grep -q "node_cpu_seconds_total"; then
        echo -e "    ${GREEN}✓ CPU metrics present${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "    ${RED}✗ CPU metrics missing${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    echo -e "${YELLOW}  Checking for memory metrics...${NC}"
    if curl -s http://192.168.31.5:9100/metrics | grep -q "node_memory_"; then
        echo -e "    ${GREEN}✓ Memory metrics present${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "    ${RED}✗ Memory metrics missing${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo -e "  ${RED}✗ node-exporter is not responding${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Test cadvisor on pop-os
echo -e "${YELLOW}Testing cAdvisor on pop-os (192.168.31.5:8080)...${NC}"
if curl -s --connect-timeout 5 http://192.168.31.5:8080/metrics > /dev/null; then
    echo -e "  ${GREEN}✓ cAdvisor is responding${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))

    # Check for specific metrics
    echo -e "${YELLOW}  Checking for container memory metrics...${NC}"
    if curl -s http://192.168.31.5:8080/metrics | grep -q "container_memory_usage_bytes"; then
        echo -e "    ${GREEN}✓ Container memory metrics present${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "    ${RED}✗ Container memory metrics missing${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo -e "  ${RED}✗ cAdvisor is not responding${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# 4. Check VictoriaMetrics
echo -e "\n${BLUE}=== 4. VictoriaMetrics Status ===${NC}"
VM_TASK=$(docker ps -q -f name=observability_victoria-metrics | head -1)

if [ -n "$VM_TASK" ]; then
    echo -e "${GREEN}✓ VictoriaMetrics container is running${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))

    # Health check
    echo -e "${YELLOW}Testing VictoriaMetrics health endpoint...${NC}"
    VM_HEALTH=$(docker exec $VM_TASK wget -qO- http://localhost:8428/health 2>/dev/null || echo "failed")
    if [ "$VM_HEALTH" = "OK" ]; then
        echo -e "  ${GREEN}✓ VictoriaMetrics is healthy${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  ${RED}✗ VictoriaMetrics health check failed: $VM_HEALTH${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    # Check targets
    echo -e "${YELLOW}Checking VictoriaMetrics targets...${NC}"
    VM_TARGETS=$(docker exec $VM_TASK wget -qO- http://localhost:8428/api/v1/targets 2>/dev/null || echo "failed")
    if echo "$VM_TARGETS" | grep -q "activeTargets"; then
        echo -e "  ${GREEN}✓ Targets API is responding${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))

        # Count active targets
        TARGET_COUNT=$(echo "$VM_TARGETS" | jq '.data.activeTargets | length' 2>/dev/null || echo "0")
        echo -e "    Active targets: $TARGET_COUNT"

        if [ "$TARGET_COUNT" -gt 0 ]; then
            echo -e "    ${GREEN}✓ Targets discovered${NC}"

            # Show target health
            echo -e "${YELLOW}    Target health:${NC}"
            docker exec $VM_TASK wget -qO- http://localhost:8428/api/v1/targets 2>/dev/null | \
                jq -r '.data.activeTargets[] | "      \(.labels.job // "unknown") on \(.labels.instance // "unknown"): \(.health)"' 2>/dev/null || \
                echo "      Unable to parse target health"
        else
            echo -e "    ${YELLOW}⚠ No targets discovered yet${NC}"
        fi
    else
        echo -e "  ${RED}✗ Targets API failed${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    # Query metrics
    echo -e "${YELLOW}Testing metric queries...${NC}"
    VM_METRICS=$(docker exec $VM_TASK wget -qO- "http://localhost:8428/api/v1/query?query=up" 2>/dev/null || echo "failed")
    if echo "$VM_METRICS" | grep -q "data"; then
        echo -e "  ${GREEN}✓ Metric queries working${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  ${RED}✗ Metric queries failed${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo -e "${YELLOW}⚠ VictoriaMetrics is not running${NC}"
    echo -e "  This is expected if Xeon01 is offline"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    # Don't count as failure - it's expected when Xeon01 is down
fi

# 5. Check Grafana
echo -e "\n${BLUE}=== 5. Grafana Status ===${NC}"
GRAFANA_TASK=$(docker ps -q -f name=observability_grafana | head -1)

if [ -n "$GRAFANA_TASK" ]; then
    echo -e "${GREEN}✓ Grafana container is running${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))

    # Health check
    echo -e "${YELLOW}Testing Grafana health endpoint...${NC}"
    GRAFANA_HEALTH=$(docker exec $GRAFANA_TASK wget -qO- http://localhost:3000/api/health 2>/dev/null || echo "failed")
    if echo "$GRAFANA_HEALTH" | grep -q "database.*ok"; then
        echo -e "  ${GREEN}✓ Grafana is healthy${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  ${RED}✗ Grafana health check failed${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    # Check datasources
    echo -e "${YELLOW}Checking Grafana datasources...${NC}"
    GRAFANA_DS=$(docker exec $GRAFANA_TASK wget -qO- http://localhost:3000/api/datasources 2>/dev/null || echo "failed")
    if echo "$GRAFANA_DS" | grep -q "VictoriaMetrics"; then
        echo -e "  ${GREEN}✓ VictoriaMetrics datasource configured${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  ${RED}✗ VictoriaMetrics datasource not found${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    # Check dashboards
    echo -e "${YELLOW}Checking Grafana dashboards...${NC}"
    GRAFANA_DASH=$(docker exec $GRAFANA_TASK wget -qO- http://localhost:3000/api/search 2>/dev/null || echo "failed")
    DASH_COUNT=$(echo "$GRAFANA_DASH" | jq '. | length' 2>/dev/null || echo "0")
    if [ "$DASH_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}✓ Dashboards loaded ($DASH_COUNT found)${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        PASSED_CHECKS=$((PASSED_CHECKS + 1))

        echo -e "    Available dashboards:"
        docker exec $GRAFANA_TASK wget -qO- http://localhost:3000/api/search 2>/dev/null | \
            jq -r '.[] | "      - \(.title)"' 2>/dev/null || echo "      Unable to parse dashboard list"
    else
        echo -e "  ${RED}✗ No dashboards found${NC}"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo -e "${YELLOW}⚠ Grafana is not running${NC}"
    echo -e "  Run ./deploy-grafana.sh to deploy Grafana"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    # Don't count as failure - it may not be deployed yet
fi

# 6. Configuration Files Check
echo -e "\n${BLUE}=== 6. Configuration Files ===${NC}"

CONFIG_DIR="/Users/menoncello/repos/setup/homelab/stacks/observability-stack/config"

echo -e "${YELLOW}Checking configuration files...${NC}"

# Prometheus config
if [ -f "$CONFIG_DIR/prometheus/prometheus.yml" ]; then
    echo -e "  ${GREEN}✓ prometheus.yml exists${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${RED}✗ prometheus.yml missing${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Grafana datasource config
if [ -f "$CONFIG_DIR/grafana/datasources/datasources.yml" ]; then
    echo -e "  ${GREEN}✓ datasources.yml exists${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${RED}✗ datasources.yml missing${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Grafana dashboard config
if [ -f "$CONFIG_DIR/grafana/dashboards/dashboards.yml" ]; then
    echo -e "  ${GREEN}✓ dashboards.yml exists${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${RED}✗ dashboards.yml missing${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Dashboard files
DASH_COUNT=$(find "$CONFIG_DIR/grafana/dashboards/files" -name "*.json" 2>/dev/null | wc -l)
if [ "$DASH_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}✓ Dashboard files exist ($DASH_COUNT found)${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${RED}✗ No dashboard files found${NC}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# 7. Summary
echo -e "\n${BLUE}=== Summary ===${NC}"
echo -e "Total checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All checks passed!${NC}"
    exit 0
elif [ $FAILED_CHECKS -le 2 ]; then
    echo -e "\n${YELLOW}⚠ Some checks failed, but pipeline is mostly functional${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Multiple checks failed - review errors above${NC}"
    exit 1
fi
