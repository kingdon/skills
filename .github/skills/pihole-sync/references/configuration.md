# Pi-Hole Configuration Reference

Docker Compose, Gravity Sync, and router configuration for the dual-subnet Pi-Hole deployment.

## Pi-Hole Docker Compose (DS923+)

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

## Pi-Hole Docker Compose (DS1517+ - Secondary)

```yaml
version: "3"
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    hostname: pihole-secondary
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

---

## Gravity Sync Configuration

```bash
# /etc/gravity-sync/gravity-sync.conf (in container)
REMOTE_HOST='10.17.14.10'
REMOTE_USER='admin'
PIHOLE_DIR='/etc/pihole'
GRAVITY_FI='gravity.db'
CUSTOM_DNS='custom.list'
CNAME_CONF='05-pihole-custom-cname.conf'
```

### Gravity Sync Setup Commands

```bash
# Install gravity-sync on primary
docker exec -it pihole bash
curl -sSL https://gravity.vmstan.com | bash

# Configure remote host
gravity-sync configure

# Test sync
gravity-sync compare

# Push to secondary
gravity-sync push
```

---

## Router DHCP DNS Settings

### DD-WRT (Primary Subnet - 10.17.13.0/24)

**dnsmasq configuration:**
```
# Services > Additional DNSMasq Options
dhcp-option=6,10.17.13.10,10.17.14.10
```

**nvram settings:**
```bash
# Set DNS servers for DHCP
nvram set dhcp_dns="10.17.13.10 10.17.14.10"
nvram commit
```

### Mikrotik (Secondary Subnet - 10.17.14.0/24)

```routeros
# Set DHCP DNS servers
/ip dhcp-server network
add address=10.17.14.0/24 dns-server=10.17.14.10,10.17.13.10 gateway=10.17.14.1

# Verify configuration
/ip dhcp-server network print

# Set router's own DNS
/ip dns set servers=10.17.14.10,10.17.13.10
```

---

## Firewall Rules for Cross-Subnet DNS

### DD-WRT iptables

```bash
# Allow DNS from secondary subnet to primary Pi-Hole
iptables -A FORWARD -s 10.17.14.0/24 -d 10.17.13.10 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -s 10.17.14.0/24 -d 10.17.13.10 -p tcp --dport 53 -j ACCEPT

# Allow DNS from primary subnet to secondary Pi-Hole
iptables -A FORWARD -s 10.17.13.0/24 -d 10.17.14.10 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -s 10.17.13.0/24 -d 10.17.14.10 -p tcp --dport 53 -j ACCEPT
```

### Mikrotik Firewall

```routeros
# Allow DNS between subnets
/ip firewall filter
add chain=forward src-address=10.17.13.0/24 dst-address=10.17.14.10 dst-port=53 protocol=udp action=accept
add chain=forward src-address=10.17.13.0/24 dst-address=10.17.14.10 dst-port=53 protocol=tcp action=accept
add chain=forward src-address=10.17.14.0/24 dst-address=10.17.13.10 dst-port=53 protocol=udp action=accept
add chain=forward src-address=10.17.14.0/24 dst-address=10.17.13.10 dst-port=53 protocol=tcp action=accept
```

---

## Synology Container Manager Notes

### Enable SSH
1. DSM Control Panel → Terminal & SNMP
2. Enable SSH service
3. Set port (default 22)

### Docker Commands via SSH

```bash
# List containers
docker ps -a

# View Pi-Hole logs
docker logs pihole -f

# Execute command in container
docker exec -it pihole bash

# Restart container
docker restart pihole

# Check Container Manager service
sudo synosystemctl status pkgctl-Docker
sudo synosystemctl restart pkgctl-Docker
```

### Volume Paths

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `/volume1/docker/pihole/etc-pihole` | `/etc/pihole` | Pi-Hole config, gravity.db |
| `/volume1/docker/pihole/etc-dnsmasq.d` | `/etc/dnsmasq.d` | dnsmasq custom config |
