# Pi-Hole Sync Procedures

Detailed validation commands and recovery playbooks for the dual-subnet Pi-Hole deployment.

## Pi-Hole Service Validation

### Check Pi-Hole Status
```bash
# Primary instance (DS923+)
ssh admin@10.17.13.10 "docker exec pihole pihole status"

# Secondary instance (DS1517+)
ssh admin@10.17.14.10 "docker exec pihole pihole status"

# Check FTL (DNS resolver) process
ssh admin@10.17.13.10 "docker exec pihole pgrep -a pihole-FTL"
```

### Query Statistics
```bash
# Get today's statistics
ssh admin@10.17.13.10 "docker exec pihole pihole -c -e"

# Check if Pi-Hole is responding to DNS
dig @10.17.13.10 google.com +short
dig @10.17.14.10 google.com +short
```

### API Health Check
```bash
# Check Pi-Hole API (get summary)
curl -s "http://10.17.13.10/admin/api.php?summary" | jq .
curl -s "http://10.17.14.10/admin/api.php?summary" | jq .
```

---

## Gravity DB Replication

### Gravity Sync Status
```bash
# On primary Pi-Hole, check sync status
ssh admin@10.17.13.10 "docker exec pihole gravity-sync version"

# Check last sync timestamp
ssh admin@10.17.13.10 "docker exec pihole cat /etc/pihole/gravity.db.md5"
ssh admin@10.17.14.10 "docker exec pihole cat /etc/pihole/gravity.db.md5"
```

### Manual Sync Trigger
```bash
# Push from primary to secondary
ssh admin@10.17.13.10 "docker exec pihole gravity-sync push"

# Pull from primary (run on secondary)
ssh admin@10.17.14.10 "docker exec pihole gravity-sync pull"

# Compare databases
ssh admin@10.17.13.10 "docker exec pihole pihole -g" # Update gravity
ssh admin@10.17.14.10 "docker exec pihole pihole -g" # Update gravity
```

### Debug Replication Lag
```bash
# Check gravity.db modification times
ssh admin@10.17.13.10 "docker exec pihole stat /etc/pihole/gravity.db | grep Modify"
ssh admin@10.17.14.10 "docker exec pihole stat /etc/pihole/gravity.db | grep Modify"

# Compare domain counts
PRIMARY_COUNT=$(ssh admin@10.17.13.10 "docker exec pihole sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity'")
SECONDARY_COUNT=$(ssh admin@10.17.14.10 "docker exec pihole sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity'")
echo "Primary: $PRIMARY_COUNT, Secondary: $SECONDARY_COUNT"
```

---

## Cross-Subnet DNS Testing

### Test From Each Subnet
```bash
# From primary subnet device
dig @10.17.13.10 example.com +short    # Should resolve via primary Pi-Hole
dig @10.17.14.10 example.com +short    # Should resolve via secondary (cross-subnet)

# From secondary subnet device  
dig @10.17.14.10 example.com +short    # Should resolve via secondary Pi-Hole
dig @10.17.13.10 example.com +short    # Should resolve via primary (cross-subnet)
```

### Verify Blocking Works
```bash
# Test that blocking works on both instances
dig @10.17.13.10 ads.google.com +short  # Should return 0.0.0.0 or NXDOMAIN
dig @10.17.14.10 ads.google.com +short  # Same result
```

### Router DNS Configuration Check

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

---

## DNS Failover Testing

### Simulate Primary Failure
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

### Measure Failover Time
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

---

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

---

## Generate Episode Notes

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
