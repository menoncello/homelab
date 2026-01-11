#!/bin/bash
# Test script for VictoriaMetrics deployment
# Run this after Xeon01 comes back online

set -e

echo "====================================="
echo "VictoriaMetrics Verification Script"
echo "====================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if service is running
echo "1. Checking VictoriaMetrics service status..."
docker service ps observability_victoria-metrics --no-trunc

echo ""
echo "2. Waiting for service to be ready (max 60 seconds)..."
for i in {1..12}; do
    VM_TASK=$(docker ps -q -f name=observability_victoria-metrics | head -1)
    if [ -n "$VM_TASK" ]; then
        echo -e "${GREEN}✓ VictoriaMetrics container is running${NC}"
        break
    fi
    echo "Waiting... ($i/12)"
    sleep 5
done

if [ -z "$VM_TASK" ]; then
    echo -e "${RED}✗ VictoriaMetrics container not found${NC}"
    exit 1
fi

echo ""
echo "3. Testing health endpoint..."
HEALTH=$(docker exec $VM_TASK wget -qO- http://localhost:8428/health)
if [ "$HEALTH" = "OK" ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${RED}✗ Health check failed${NC}"
    echo "Response: $HEALTH"
fi

echo ""
echo "4. Testing metrics endpoint..."
METRICS=$(docker exec $VM_TASK wget -qO- http://localhost:8428/metrics | grep -i "vm_" | head -5)
if [ -n "$METRICS" ]; then
    echo -e "${GREEN}✓ Metrics endpoint accessible${NC}"
    echo "Sample metrics:"
    echo "$METRICS"
else
    echo -e "${RED}✗ Metrics endpoint not accessible${NC}"
fi

echo ""
echo "5. Checking Prometheus service discovery targets..."
TARGETS=$(docker exec $VM_TASK wget -qO- http://localhost:8428/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | "\(.labels.job) - \(.health)"' 2>/dev/null || echo "N/A")

if [ "$TARGETS" != "N/A" ]; then
    echo -e "${GREEN}✓ Service discovery working${NC}"
    echo "Discovered targets:"
    echo "$TARGETS"
else
    echo -e "${YELLOW}⚠ Service discovery not yet available or jq not installed${NC}"
fi

echo ""
echo "6. Querying metrics for node-exporter..."
NODE_EXPORTER_UP=$(docker exec $VM_TASK wget -qO- "http://localhost:8428/api/v1/query?query=up{job='node-exporter'}" 2>/dev/null | jq -r '.data.result[] | select(.value[1] == "1") | .metric.job' 2>/dev/null || echo "")

if [ -n "$NODE_EXPORTER_UP" ]; then
    echo -e "${GREEN}✓ Node-exporter metrics being ingested${NC}"
else
    echo -e "${YELLOW}⚠ Node-exporter metrics not yet available${NC}"
fi

echo ""
echo "7. Querying metrics for cadvisor..."
CADVISOR_UP=$(docker exec $VM_TASK wget -qO- "http://localhost:8428/api/v1/query?query=up{job='cadvisor'}" 2>/dev/null | jq -r '.data.result[] | select(.value[1] == "1") | .metric.job' 2>/dev/null || echo "")

if [ -n "$CADVISOR_UP" ]; then
    echo -e "${GREEN}✓ cAdvisor metrics being ingested${NC}"
else
    echo -e "${YELLOW}⚠ cAdvisor metrics not yet available${NC}"
fi

echo ""
echo "8. Checking volume persistence..."
VOLUME_INFO=$(docker exec $VM_TASK ls -la /victoria 2>/dev/null || echo "N/A")
if [ "$VOLUME_INFO" != "N/A" ]; then
    echo -e "${GREEN}✓ Volume mounted and accessible${NC}"
    echo "Volume contents:"
    echo "$VOLUME_INFO"
else
    echo -e "${RED}✗ Volume not accessible${NC}"
fi

echo ""
echo "9. Viewing recent logs..."
docker service logs observability_victoria-metrics --tail 20

echo ""
echo "====================================="
echo "Verification Complete!"
echo "====================================="
echo ""
echo "Next steps:"
echo "- Access VictoriaMetrics UI: http://192.168.31.6:8428"
echo "- Check targets: http://192.168.31.6:8428/api/v1/targets"
echo "- Query metrics: http://192.168.31.6:8428/vmui"
echo ""
