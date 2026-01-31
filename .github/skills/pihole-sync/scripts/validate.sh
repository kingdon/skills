#!/bin/bash

###########################################
# Part of Kingdon Skills - pihole-sync
###########################################
# Validates Pi-Hole dual-subnet DNS topology and sync status
# Requires SSH access to Pi-Hole hosts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Update these for your environment
PRIMARY_HOST="${PRIMARY_PIHOLE:-10.17.13.10}"
SECONDARY_HOST="${SECONDARY_PIHOLE:-10.17.14.10}"
PRIMARY_ROUTER="${PRIMARY_ROUTER:-10.17.13.1}"
SECONDARY_ROUTER="${SECONDARY_ROUTER:-10.17.14.1}"

echo -e "${BLUE}=== Pi-Hole Dual-Subnet Validation ===${NC}"
echo "Time: $(date)"
echo "Primary: $PRIMARY_HOST"
echo "Secondary: $SECONDARY_HOST"
echo ""

FAILURES=0
WARNINGS=0

# Step 1: Check network connectivity
echo -e "${BLUE}Step 1: Checking network connectivity...${NC}"
if ping -c 1 -W 2 "$PRIMARY_HOST" > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Primary Pi-Hole ($PRIMARY_HOST) reachable${NC}"
else
  echo -e "${RED}✗ Primary Pi-Hole ($PRIMARY_HOST) unreachable${NC}"
  FAILURES=$((FAILURES + 1))
fi

if ping -c 1 -W 2 "$SECONDARY_HOST" > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Secondary Pi-Hole ($SECONDARY_HOST) reachable${NC}"
else
  echo -e "${RED}✗ Secondary Pi-Hole ($SECONDARY_HOST) unreachable${NC}"
  FAILURES=$((FAILURES + 1))
fi
echo ""

# Step 2: Check DNS resolution
echo -e "${BLUE}Step 2: Checking DNS resolution...${NC}"
PRIMARY_DNS=$(dig @"$PRIMARY_HOST" google.com +short +time=2 2>/dev/null | head -1 || echo "")
if [ -n "$PRIMARY_DNS" ]; then
  echo -e "${GREEN}✓ Primary DNS resolving (google.com -> $PRIMARY_DNS)${NC}"
else
  echo -e "${RED}✗ Primary DNS not resolving${NC}"
  FAILURES=$((FAILURES + 1))
fi

SECONDARY_DNS=$(dig @"$SECONDARY_HOST" google.com +short +time=2 2>/dev/null | head -1 || echo "")
if [ -n "$SECONDARY_DNS" ]; then
  echo -e "${GREEN}✓ Secondary DNS resolving (google.com -> $SECONDARY_DNS)${NC}"
else
  echo -e "${RED}✗ Secondary DNS not resolving${NC}"
  FAILURES=$((FAILURES + 1))
fi
echo ""

# Step 3: Check blocking is working
echo -e "${BLUE}Step 3: Checking ad blocking...${NC}"
# Test a known ad domain - should return 0.0.0.0 or NXDOMAIN
PRIMARY_BLOCK=$(dig @"$PRIMARY_HOST" ads.google.com +short +time=2 2>/dev/null || echo "")
if [ "$PRIMARY_BLOCK" = "0.0.0.0" ] || [ -z "$PRIMARY_BLOCK" ]; then
  echo -e "${GREEN}✓ Primary blocking active (ads.google.com blocked)${NC}"
else
  echo -e "${YELLOW}⚠ Primary may not be blocking (got: $PRIMARY_BLOCK)${NC}"
  WARNINGS=$((WARNINGS + 1))
fi

SECONDARY_BLOCK=$(dig @"$SECONDARY_HOST" ads.google.com +short +time=2 2>/dev/null || echo "")
if [ "$SECONDARY_BLOCK" = "0.0.0.0" ] || [ -z "$SECONDARY_BLOCK" ]; then
  echo -e "${GREEN}✓ Secondary blocking active (ads.google.com blocked)${NC}"
else
  echo -e "${YELLOW}⚠ Secondary may not be blocking (got: $SECONDARY_BLOCK)${NC}"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Step 4: Check Pi-Hole API
echo -e "${BLUE}Step 4: Checking Pi-Hole API status...${NC}"
PRIMARY_API=$(curl -s "http://$PRIMARY_HOST/admin/api.php?summary" 2>/dev/null || echo "{}")
PRIMARY_STATUS=$(echo "$PRIMARY_API" | jq -r '.status // "offline"' 2>/dev/null || echo "error")
PRIMARY_QUERIES=$(echo "$PRIMARY_API" | jq -r '.dns_queries_today // 0' 2>/dev/null || echo "0")

if [ "$PRIMARY_STATUS" = "enabled" ]; then
  echo -e "${GREEN}✓ Primary Pi-Hole: enabled ($PRIMARY_QUERIES queries today)${NC}"
else
  echo -e "${RED}✗ Primary Pi-Hole status: $PRIMARY_STATUS${NC}"
  FAILURES=$((FAILURES + 1))
fi

SECONDARY_API=$(curl -s "http://$SECONDARY_HOST/admin/api.php?summary" 2>/dev/null || echo "{}")
SECONDARY_STATUS=$(echo "$SECONDARY_API" | jq -r '.status // "offline"' 2>/dev/null || echo "error")
SECONDARY_QUERIES=$(echo "$SECONDARY_API" | jq -r '.dns_queries_today // 0' 2>/dev/null || echo "0")

if [ "$SECONDARY_STATUS" = "enabled" ]; then
  echo -e "${GREEN}✓ Secondary Pi-Hole: enabled ($SECONDARY_QUERIES queries today)${NC}"
else
  echo -e "${RED}✗ Secondary Pi-Hole status: $SECONDARY_STATUS${NC}"
  FAILURES=$((FAILURES + 1))
fi
echo ""

# Step 5: Compare gravity databases (domain counts)
echo -e "${BLUE}Step 5: Checking Gravity DB sync...${NC}"
PRIMARY_DOMAINS=$(echo "$PRIMARY_API" | jq -r '.domains_being_blocked // 0' 2>/dev/null || echo "0")
SECONDARY_DOMAINS=$(echo "$SECONDARY_API" | jq -r '.domains_being_blocked // 0' 2>/dev/null || echo "0")

echo "Primary blocked domains: $PRIMARY_DOMAINS"
echo "Secondary blocked domains: $SECONDARY_DOMAINS"

if [ "$PRIMARY_DOMAINS" -eq "$SECONDARY_DOMAINS" ]; then
  echo -e "${GREEN}✓ Gravity databases in sync${NC}"
elif [ "$PRIMARY_DOMAINS" -gt 0 ] && [ "$SECONDARY_DOMAINS" -gt 0 ]; then
  DIFF=$((PRIMARY_DOMAINS - SECONDARY_DOMAINS))
  if [ "${DIFF#-}" -lt 100 ]; then  # Within 100 domains
    echo -e "${YELLOW}⚠ Gravity databases slightly out of sync (diff: $DIFF)${NC}"
    WARNINGS=$((WARNINGS + 1))
  else
    echo -e "${RED}✗ Gravity databases significantly out of sync (diff: $DIFF)${NC}"
    FAILURES=$((FAILURES + 1))
  fi
else
  echo -e "${YELLOW}⚠ Could not compare Gravity databases${NC}"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Step 6: Cross-subnet resolution test
echo -e "${BLUE}Step 6: Cross-subnet resolution test...${NC}"
# Test if we can resolve across subnets
CROSS_TEST=$(dig @"$SECONDARY_HOST" "pihole-primary.local" +short +time=2 2>/dev/null || echo "")
if [ -n "$CROSS_TEST" ]; then
  echo -e "${GREEN}✓ Cross-subnet local DNS working${NC}"
else
  echo -e "${YELLOW}⚠ Cross-subnet local DNS may not be configured${NC}"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Summary
echo -e "${BLUE}=== Validation Summary ===${NC}"
echo "Primary: $PRIMARY_HOST (Status: $PRIMARY_STATUS, Queries: $PRIMARY_QUERIES)"
echo "Secondary: $SECONDARY_HOST (Status: $SECONDARY_STATUS, Queries: $SECONDARY_QUERIES)"
echo ""

if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed - DNS topology healthy${NC}"
  exit 0
elif [ "$FAILURES" -eq 0 ]; then
  echo -e "${YELLOW}⚠ $WARNINGS warning(s), no critical failures${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAILURES failure(s), $WARNINGS warning(s)${NC}"
  echo ""
  echo "Troubleshooting tips:"
  echo "  - Check Container Manager on Synology NAS"
  echo "  - Verify SSH access: ssh admin@$PRIMARY_HOST"
  echo "  - Check Pi-Hole logs: docker logs pihole"
  exit 1
fi
