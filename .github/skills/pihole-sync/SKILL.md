---
name: pihole-sync
description: 'Validate dual-subnet Pi-Hole DNS topology, debug Gravity DB replication, test DNS failover, and generate Sunkworks episode notes documenting failures. Trigger with /pihole-status'
allowed-tools: ['read_file', 'run_in_terminal', 'grep_search', 'semantic_search', 'get_terminal_output', 'create_file', 'fetch_webpage']
---

# Pi-Hole Synchronization Expert

**"Two Pi-Holes. Two subnets. Infinite ways to break DNS."**

I manage and troubleshoot dual-subnet Pi-Hole deployments in the Sunkworks home lab. This includes DD-WRT primary subnet, Mikrotik secondary subnet, Gravity DB replication between Synology NAS devices, and DNS failover testing.

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

## Quick Reference

### Check Pi-Hole Status
```bash
# Primary instance (DS923+)
ssh admin@10.17.13.10 "docker exec pihole pihole status"

# Secondary instance (DS1517+)
ssh admin@10.17.14.10 "docker exec pihole pihole status"

# Quick DNS test
dig @10.17.13.10 google.com +short
dig @10.17.14.10 google.com +short
```

### Check Gravity Sync
```bash
# Compare database hashes (should match)
ssh admin@10.17.13.10 "docker exec pihole cat /etc/pihole/gravity.db.md5"
ssh admin@10.17.14.10 "docker exec pihole cat /etc/pihole/gravity.db.md5"
```

### Emergency Recovery
```bash
# Restart Pi-Hole containers
ssh admin@10.17.13.10 "docker restart pihole"
ssh admin@10.17.14.10 "docker restart pihole"

# Force gravity sync
ssh admin@10.17.13.10 "docker exec pihole gravity-sync push --force"
```

## Detailed References

For detailed procedures and configuration, see:
- [procedures.md](references/procedures.md) - Full recovery playbooks, validation commands
- [configuration.md](references/configuration.md) - Docker compose, Gravity Sync, router settings

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
