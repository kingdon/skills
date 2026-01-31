```skill
---
name: pihole-sync
description: 'Validate dual-subnet Pi-Hole DNS topology, debug Gravity DB replication, test DNS failover, and generate Sunkworks episode notes documenting failures. Trigger with /pihole-status'
allowed-tools: ['read_file', 'run_in_terminal', 'grep_search', 'semantic_search', 'get_terminal_output', 'create_file', 'fetch_webpage']
tags: ['sunkworks', 'live-stream', 'failure-tolerant']
---

# Pi-Hole Synchronization Expert

**"Two Pi-Holes. Two subnets. Infinite ways to break DNS."**

I manage and troubleshoot dual-subnet Pi-Hole deployments in the Sunkworks home lab. This includes DD-WRT primary subnet, Mikrotik secondary subnet, Gravity DB replication between Synology NAS devices, and DNS failover testing—the actual content of that one episode, now perfected.

**Topology**: 
- Primary: DS923+ running Pi-Hole (10.17.13.0/24 - DD-WRT)
- Secondary: DS1517+ running Pi-Hole (10.17.14.0/24 - Mikrotik)
- Replication: Gravity Sync between instances

## Slash Command

### `/pihole-status`
Runs DNS topology validation:
1. Check Pi-Hole service status on both instances
2. Verify Gravity DB sync state
3. Test cross-subnet DNS resolution
4. Validate router DNS configuration

**Usage**: Type `/pihole-status` to validate Pi-Hole infrastructure.

**Script Verification**: Before executing, verify the script integrity:
```bash
sha256sum .github/skills/pihole-sync/scripts/validate.sh
# Expected: 713a1ef5bef89edb631b6d9f88323612cb6c92d45f9a23022feccdb50cb4d7e9
```

**Execute validation**:
```bash
bash .github/skills/pihole-sync/scripts/validate.sh
```

## When I Activate
- `/pihole-status` (slash command)
- "Check Pi-Hole"
- "DNS not working"
- "Gravity sync"
- "Pihole replication"
- "Dual subnet DNS"
- "DNS failover test"
- "DD-WRT DNS"
- "Mikrotik DNS"

## Network Topology

```
                    ┌─────────────────┐
                    │    Internet     │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
      ┌───────┴───────┐           ┌─────────┴────────┐
      │   DD-WRT      │           │     Mikrotik     │
      │  10.17.13.1   │           │    10.17.14.1    │
      │  (Primary)    │           │   (Secondary)    │
      └───────┬───────┘           └─────────┬────────┘
              │                             │
    ┌─────────┴─────────┐         ┌─────────┴─────────┐
    │  10.17.13.0/24    │         │  10.17.14.0/24    │
    │  Primary Subnet   │         │  Secondary Subnet │
    └─────────┬─────────┘         └─────────┬─────────┘
              │                             │
      ┌───────┴───────┐           ┌─────────┴────────┐
      │   DS923+      │◄────────► │     DS1517+      │
      │  Pi-Hole      │  Gravity  │    Pi-Hole       │
      │  10.17.13.10  │   Sync    │   10.17.14.10    │
      └───────────────┘           └──────────────────┘
```

## Expected Failure Modes

### DNS Resolution Failures
| Failure Mode | Symptoms | Est. Recovery Time |
|--------------|----------|-------------------|
| Pi-Hole service down | DNS timeout on all queries | 5-10 min |
| Container Manager crash | Pi-Hole unresponsive, DSM WebUI slow | 10-20 min |
| Gravity DB corruption | Blocklists not updating, sync fails | 20-30 min |
| Router DNS misconfiguration | Some devices work, others don't | 10-15 min |

### Replication Failures
| Failure Mode | Symptoms | Est. Recovery Time |
|--------------|----------|-------------------|
| SSH key expired | Sync auth failures | 10-15 min |
| Clock drift | Sync completes but old data | 5-10 min |
| Disk full on target | Sync fails, logs show no space | 15-30 min |
| Network partition | Subnets can't reach each other | 20-40 min |

### Failover Failures
| Failure Mode | Symptoms | Est. Recovery Time |
|--------------|----------|-------------------|
| Secondary not configured in router | No automatic failover | 5-10 min |
| TTL too high | Cached responses delay failover | Wait for TTL |
| Secondary out of sync | Failover works but wrong blocklist | 15-20 min |

## Core Capabilities

### 1. Pi-Hole Service Validation

#### Check Pi-Hole Status
```bash
# Primary instance (DS923+)
ssh admin@10.17.13.10 "docker exec pihole pihole status"

# Secondary instance (DS1517+)
ssh admin@10.17.14.10 "docker exec pihole pihole status"

# Check FTL (DNS resolver) process
ssh admin@10.17.13.10 "docker exec pihole pgrep -a pihole-FTL"
```

#### Query Statistics
```bash
# Get today's statistics
ssh admin@10.17.13.10 "docker exec pihole pihole -c -e"

# Check if Pi-Hole is responding to DNS
dig @10.17.13.10 google.com +short
dig @10.17.14.10 google.com +short
```

#### API Health Check
```bash
# Check Pi-Hole API (get summary)
curl -s "http://10.17.13.10/admin/api.php?summary" | jq .
curl -s "http://10.17.14.10/admin/api.php?summary" | jq .
```

### 2. Gravity DB Replication

#### Gravity Sync Status
```bash
# On primary Pi-Hole, check sync status
ssh admin@10.17.13.10 "docker exec pihole gravity-sync version"

# Check last sync timestamp
ssh admin@10.17.13.10 "docker exec pihole cat /etc/pihole/gravity.db.md5"
ssh admin@10.17.14.10 "docker exec pihole cat /etc/pihole/gravity.db.md5"
```

#### Manual Sync Trigger
```bash
# Push from primary to secondary
ssh admin@10.17.13.10 "docker exec pihole gravity-sync push"

# Pull from primary (run on secondary)
ssh admin@10.17.14.10 "docker exec pihole gravity-sync pull"

# Compare databases
ssh admin@10.17.13.10 "docker exec pihole pihole -g" # Update gravity
ssh admin@10.17.14.10 "docker exec pihole pihole -g" # Update gravity
```

#### Debug Replication Lag
```bash
# Check gravity.db modification times
ssh admin@10.17.13.10 "docker exec pihole stat /etc/pihole/gravity.db | grep Modify"
ssh admin@10.17.14.10 "docker exec pihole stat /etc/pihole/gravity.db | grep Modify"

# Compare domain counts
PRIMARY_COUNT=$(ssh admin@10.17.13.10 "docker exec pihole sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity'")
SECONDARY_COUNT=$(ssh admin@10.17.14.10 "docker exec pihole sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity'")
echo "Primary: $PRIMARY_COUNT, Secondary: $SECONDARY_COUNT"
```

### 3. Cross-Subnet DNS Testing

#### Test From Each Subnet
```bash
# From primary subnet device
dig @10.17.13.10 example.com +short    # Should resolve via primary Pi-Hole
dig @10.17.14.10 example.com +short    # Should resolve via secondary (cross-subnet)

# From secondary subnet device  
dig @10.17.14.10 example.com +short    # Should resolve via secondary Pi-Hole
dig @10.17.13.10 example.com +short    # Should resolve via primary (cross-subnet)
```

#### Verify Blocking Works
```bash
# Test that blocking works on both instances
dig @10.17.13.10 ads.google.com +short  # Should return 0.0.0.0 or NXDOMAIN
dig @10.17.14.10 ads.google.com +short  # Same result
```

#### Router DNS Configuration Check

**DD-WRT (Primary Subnet):**
```bash
# SSH to DD-WRT router
ssh root@10.17.13.1 "nvram get dhcp_dns"
# Expected: 10.17.13.10 10.17.14.10 (primary first, secondary backup)
```

**Mikrotik (Secondary Subnet):**
```bash
# SSH to Mikrotik
ssh admin@10.17.14.1 "/ip dns print"
# Check servers configured
ssh admin@10.17.14.1 "/ip dhcp-server network print"
# Verify DNS servers in DHCP
```

### 4. DNS Failover Testing

#### Simulate Primary Failure
```bash
#!/bin/bash
# failover-test.sh

echo "=== DNS Failover Test ==="

# Step 1: Baseline test
echo "Step 1: Testing primary DNS..."
PRIMARY_RESULT=$(dig @10.17.13.10 example.com +short +time=2 2>&1)
echo "Primary: $PRIMARY_RESULT"

# Step 2: Stop primary Pi-Hole (CAREFUL!)
echo "Step 2: Stopping primary Pi-Hole..."
ssh admin@10.17.13.10 "docker stop pihole"

# Step 3: Wait for cache to expire (or test immediately)
echo "Step 3: Testing failover to secondary..."
sleep 5
FAILOVER_RESULT=$(dig @10.17.14.10 example.com +short +time=2 2>&1)
echo "Secondary (failover): $FAILOVER_RESULT"

# Step 4: Test from client with both servers configured
echo "Step 4: Testing client DNS resolution..."
# This tests actual failover from client perspective
dig example.com +short +time=2

# Step 5: Restore primary
echo "Step 5: Restoring primary Pi-Hole..."
ssh admin@10.17.13.10 "docker start pihole"

echo "=== Failover Test Complete ==="
```

#### Measure Failover Time
```bash
#!/bin/bash
# measure-failover.sh

echo "Stopping primary Pi-Hole..."
ssh admin@10.17.13.10 "docker stop pihole"

START=$(date +%s.%N)
while ! dig @10.17.14.10 example.com +short +time=1 > /dev/null 2>&1; do
  sleep 0.5
done
END=$(date +%s.%N)

DURATION=$(echo "$END - $START" | bc)
echo "Failover detected after ${DURATION}s"

ssh admin@10.17.13.10 "docker start pihole"
```

### 5. Generate Episode Notes

```bash
#!/bin/bash
# generate-episode-notes.sh

DATE=$(date +%Y-%m-%d)
EPISODE_NUM=$1

cat << EOF > "sunkworks-episode-${EPISODE_NUM}-${DATE}.md"
# Sunkworks Episode ${EPISODE_NUM} Notes

**Date**: ${DATE}
**Topic**: Pi-Hole Dual-Subnet DNS

## Pre-Stream Status
$(curl -s "http://10.17.13.10/admin/api.php?summary" | jq -r '"Primary: \(.dns_queries_today) queries, \(.ads_blocked_today) blocked"')
$(curl -s "http://10.17.14.10/admin/api.php?summary" | jq -r '"Secondary: \(.dns_queries_today) queries, \(.ads_blocked_today) blocked"')

## What We Tried
1. 

## What Broke
- 

## What We Learned
- 

## Recovery Steps
\`\`\`bash
# Commands that fixed it
\`\`\`

## For Next Episode
- [ ] Follow-up item 1
- [ ] Follow-up item 2

## Chat Highlights
- 
EOF

echo "Created sunkworks-episode-${EPISODE_NUM}-${DATE}.md"
```

## Recovery Playbooks

### Playbook 1: "DNS Is Completely Down" (10-15 min)
```bash
# 1. Check if Pi-Hole containers are running
ssh admin@10.17.13.10 "docker ps | grep pihole"
ssh admin@10.17.14.10 "docker ps | grep pihole"

# 2. If not running, start them
ssh admin@10.17.13.10 "docker start pihole"
ssh admin@10.17.14.10 "docker start pihole"

# 3. If start fails, check Container Manager
ssh admin@10.17.13.10 "sudo synosystemctl status pkgctl-Docker"

# 4. Restart Container Manager if needed
ssh admin@10.17.13.10 "sudo synosystemctl restart pkgctl-Docker"

# 5. Wait and verify
sleep 30
dig @10.17.13.10 google.com +short
```

### Playbook 2: "Gravity Sync Broken" (15-20 min)
```bash
# 1. Check sync logs
ssh admin@10.17.13.10 "docker logs pihole 2>&1 | grep -i gravity"

# 2. Verify SSH connectivity between hosts
ssh admin@10.17.13.10 "ssh -o BatchMode=yes admin@10.17.14.10 'echo OK'"

# 3. Re-establish SSH keys if needed
ssh admin@10.17.13.10 "docker exec pihole gravity-sync configure"

# 4. Force full resync
ssh admin@10.17.13.10 "docker exec pihole gravity-sync push --force"

# 5. Verify sync
ssh admin@10.17.14.10 "docker exec pihole pihole -g"
```

### Playbook 3: "Cross-Subnet DNS Fails" (15-30 min)
```bash
# 1. Verify basic connectivity between subnets
ping -c 3 10.17.14.10  # From primary subnet
ping -c 3 10.17.13.10  # From secondary subnet

# 2. Check firewall rules on routers
# DD-WRT
ssh root@10.17.13.1 "iptables -L | grep -i dns"

# Mikrotik
ssh admin@10.17.14.1 "/ip firewall filter print where dst-port=53"

# 3. Ensure DNS port (53) is allowed between subnets
# DD-WRT: Add rule if missing
ssh root@10.17.13.1 "iptables -A FORWARD -p udp --dport 53 -j ACCEPT"

# 4. Test again
dig @10.17.14.10 example.com +short
```

## Configuration Reference

### Pi-Hole Docker Compose (DS923+)
```yaml
version: "3"
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    hostname: pihole-primary
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
    environment:
      TZ: 'America/New_York'
      WEBPASSWORD: '${PIHOLE_PASSWORD}'
      PIHOLE_DNS_: '1.1.1.1;8.8.8.8'
    volumes:
      - '/volume1/docker/pihole/etc-pihole:/etc/pihole'
      - '/volume1/docker/pihole/etc-dnsmasq.d:/etc/dnsmasq.d'
    restart: unless-stopped
```

### Gravity Sync Configuration
```bash
# /etc/gravity-sync/gravity-sync.conf (in container)
REMOTE_HOST='10.17.14.10'
REMOTE_USER='admin'
PIHOLE_DIR='/etc/pihole'
GRAVITY_FI='gravity.db'
CUSTOM_DNS='custom.list'
CNAME_CONF='05-pihole-custom-cname.conf'
```

### Router DHCP DNS Settings

**DD-WRT (dnsmasq):**
```
# Services > Additional DNSMasq Options
dhcp-option=6,10.17.13.10,10.17.14.10
```

**Mikrotik:**
```
/ip dhcp-server network
add address=10.17.14.0/24 dns-server=10.17.14.10,10.17.13.10 gateway=10.17.14.1
```

## Integration Points

- **SOS Emergency**: When DNS fails, network troubleshooting becomes critical
- **Prometheus Observer**: Monitor DNS query rates and block percentages
- **Post-Mortem Author**: Document DNS outages with resolution steps

## Sunkworks Episode Notes

*"The episode where we spent an hour debugging DNS, only to find the router was set to use 8.8.8.8."*

### Common Live-Stream DNS Debugging Sequence
1. "DNS is broken" → Check if it's actually DNS
2. Check Pi-Hole containers → Usually fine
3. Check router config → Often the culprit  
4. Check firewall rules → Almost always fine but we check anyway
5. Check the thing we changed 5 minutes ago → That was it

### Audience Participation Tips
- Ask chat "what would you check first?" 
- Share the Gravity Sync dashboard during troubleshooting
- Show the query logs to demonstrate real-time blocking
```
