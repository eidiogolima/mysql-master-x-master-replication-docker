# MySQL Master x Master Replication - Copilot Instructions

## Project Overview
This project implements MySQL Master x Master bidirectional replication using Docker Compose with GTID (Global Transaction IDs). The architecture ensures high availability with automatic failover and data synchronization between two MySQL 8.0 instances.

## Architecture & Key Components

### Environment Structure
- **`dev/`** - Local development environment (single machine, two containers)
- **`prod/server-1/`** - Production Master 1 (typically 192.168.1.10:3306)
- **`prod/server-2/`** - Production Master 2 (typically 192.168.1.20:3306)

### Critical Configuration Files
- **MySQL configs**: `my-config-1.cnf` (server-id=1, auto-increment-offset=1) and `my-config-2.cnf` (server-id=2, auto-increment-offset=2)
- **Docker Compose**: Each environment has its own `docker-compose.yml` with health checks
- **Environment vars**: `.env` files must be **identical** across both servers (DB_ROOT_PASSWORD, DB_PASSWORD)

### Auto-increment Conflict Prevention
```ini
# Master 1: IDs 1,3,5,7... (odd numbers)
auto-increment-increment = 2
auto-increment-offset = 1

# Master 2: IDs 2,4,6,8... (even numbers)  
auto-increment-increment = 2
auto-increment-offset = 2
```

## Developer Workflows

### Setup Replication (Critical Process)
```bash
# Development
cd dev/ && ./setup-replication.sh mysql-master-2

# Production - Server 1
cd prod/server-1/exec && ./setup-replication.sh 192.168.1.20

# Production - Server 2  
cd prod/server-2/exec && ./setup-replication.sh 192.168.1.10
```

### Monitoring & Troubleshooting
```bash
# Check replication status
./check-replication.sh

# View container logs
docker logs mysql-master-1

# MySQL CLI access
docker exec -it mysql-master-1 mysql -uroot -pteste123

# Test resilience (dev only)
cd dev/ && ./test-failover-resilience.sh
```

### Required MySQL Permissions
The replication user needs these **exact** permissions:
```sql
GRANT REPLICATION SLAVE ON *.* TO 'replicador'@'%';
GRANT SELECT ON *.* TO 'replicador'@'%';
GRANT REPLICATION CLIENT ON *.* TO 'replicador'@'%';  -- Critical for SHOW MASTER STATUS
```

## Project-Specific Patterns

### GTID-Based Replication
- Uses `MASTER_AUTO_POSITION=1` (not binlog positions)
- Both masters configured with `gtid_mode=ON` and `enforce_gtid_consistency=ON`
- `log-slave-updates=1` enables bidirectional propagation

### Container Health Dependencies
```yaml
depends_on:
  mysql-master-1:
    condition: service_healthy  # Critical - wait for MySQL ready
```

### Network Isolation
- MySQL ports only exposed in production (`ports: 3306:3306`)
- Development uses internal Docker network only
- phpMyAdmin on port 8085 is the **only** external access point

### Error Recovery Patterns
Common replication states and fixes:
- `Slave_IO_Running: Connecting` → Check network/firewall/permissions
- `Slave_SQL_Running: No` → Check `Last_SQL_Error`, may need to skip error or reset replication
- `Seconds_Behind_Master: NULL` → Replication not started, run setup script

## File Naming Conventions
- **Note**: `prod/server-1/myql/` has typo (should be `mysql/`) but is used consistently
- Container names: `mysql-master-1`, `mysql-master-2`
- Volume names: `mysql-master-1-data`, `mysql-master-2-data`
- Config files: `my-config-1.cnf`, `my-config-2.cnf`

## Testing & Validation
- Use `test-failover-resilience.sh` for comprehensive testing
- Validates recovery from single server failure (1 minute)
- Tests recovery from simultaneous dual server failure
- Expects zero data loss and automatic sync

## Security Notes
- Default credentials: root/teste123, replicador/teste123 (change in production!)
- Firewall setup: Only allow specific IPs to port 3306
- No SSL configured (add for production)

## Common Gotchas
- Always use **identical** `.env` files across servers
- Check that `server-id` values are unique (1 vs 2)
- Ensure `auto-increment-offset` differs between masters
- Verify all containers are `healthy` before running setup scripts
- Run setup scripts **after** containers are fully ready (health checks pass)