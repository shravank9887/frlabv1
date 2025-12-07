# ForgeRock / Ping Identity Learning Environment

Docker-based learning environment for ForgeRock / Ping Identity products.

## 🎯 Overview

This repository contains Docker-based setups for learning and experimenting with ForgeRock / Ping Identity products including:

- **PingDS (Directory Server)** - LDAP directory service
- **PingAM (Access Manager)** - Identity and Access Management
- Replication configurations
- Integration examples

## 📁 Project Structure

```
fr/
├── sndbx1/                 # Main sandbox environment
│   ├── docker-compose.yaml # Docker orchestration
│   ├── pingds/            # PingDS configuration
│   │   ├── Dockerfile
│   │   ├── config/
│   │   ├── scripts/
│   │   ├── notes/         # Learning materials & guides
│   │   ├── sample-users.ldif
│   │   └── sample-groups.ldif
│   ├── pingam/            # PingAM configuration
│   │   ├── Dockerfile
│   │   ├── config/
│   │   ├── scripts/
│   │   └── notes/         # Learning materials & guides
│   └── shared-certs/      # Shared SSL/TLS certificates
├── ds/                    # DS reference materials
├── installfiles/          # Installation packages (not committed)
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Docker Desktop
- Docker Compose
- 4GB+ RAM available
- Ports available: 1389, 1636, 4444, 8080, 8081, 8443

### 1. Start PingDS

```bash
cd sndbx1
docker-compose up -d pingds

# Wait for healthy status
docker ps
```

### 2. Import Sample Data

```bash
# Import users
docker cp pingds/sample-users.ldif pingds:/tmp/
docker exec pingds /opt/opendj/bin/ldapmodify \
  --hostname pingds --port 1636 --useSSL --trustAll \
  --bindDN "cn=Directory Manager" --bindPassword "Passw0rd123" \
  --filename /tmp/sample-users.ldif

# Import groups
docker cp pingds/sample-groups.ldif pingds:/tmp/
docker exec pingds /opt/opendj/bin/ldapmodify \
  --hostname pingds --port 1636 --useSSL --trustAll \
  --bindDN "cn=Directory Manager" --bindPassword "Passw0rd123" \
  --filename /tmp/sample-groups.ldif
```

### 3. Verify Setup

```bash
# Search for users
docker exec pingds /opt/opendj/bin/ldapsearch \
  --hostname pingds --port 1636 --useSSL --trustAll \
  --bindDN "cn=Directory Manager" --bindPassword "Passw0rd123" \
  --baseDN "ou=identities" \
  "(objectClass=inetOrgPerson)" dn cn mail
```

## 📚 Documentation

### PingDS

Comprehensive guides available in `sndbx1/pingds/notes/`:

- **LDAP_STRUCTURE_GUIDE.md** - Directory structure and best practices
- **SAMPLE_DATA_GUIDE.md** - Sample users and groups
- **LDAP_COMMANDS.md** - Common LDAP operations
- **REPLICATION_CONCEPTS.md** - Replication theory
- **REPLICATION_COMMANDS.md** - Replication command reference
- **REPLICATION_SETUP_GUIDE.md** - Step-by-step replication setup
- **REPLICATION_QUICK_REFERENCE.md** - Cheat sheet

### PingAM

Comprehensive guides available in `sndbx1/pingam/notes/`:

- **PINGAM_OVERVIEW.md** - Architecture and concepts
- **DATA_STORES_PREPARATION.md** - Preparing DS for AM
- **PINGAM_INSTALLATION_GUIDE.md** - Step-by-step installation
- **PINGAM_QUICK_REFERENCE.md** - Command cheat sheet

## 🔧 Configuration

### Default Credentials

| Service | User | Password |
|---------|------|----------|
| **PingDS** | `cn=Directory Manager` | `Passw0rd123` |
| **PingAM** | `amAdmin` | `Passw0rd123` |
| **Sample Users** | `uid=jdoe` | `TestUser@2024` |

### Network Configuration

All services run on the `fr-net` Docker network.

### Port Mapping

| Service | Container Port | Host Port | Protocol |
|---------|---------------|-----------|----------|
| PingDS | 1389 | 1389 | LDAP |
| PingDS | 1636 | 1636 | LDAPS |
| PingDS | 4444 | 4444 | Admin |
| PingAM | 8080 | 8081 | HTTP |
| PingAM | 8443 | 8444 | HTTPS |

## 🧪 Sample Data

The repository includes sample organizational data:

- **10 Users** with realistic attributes (Engineering, QA, Product, HR, IT)
- **10 Groups** representing teams and roles
- **Organizational Structure** following LDAP best practices

### Sample Users

- `jdoe` - Engineering Manager
- `jsmith` - Senior Developer
- `bjohnson` - DevOps Engineer
- `awilliams` - QA Lead
- `cbrown` - Product Manager
- And more...

## 🔐 Security Notes

**⚠️ FOR DEVELOPMENT/LEARNING ONLY**

This setup uses:
- Default passwords (change for production!)
- Self-signed certificates
- Simplified security configurations

**Never use this configuration in production!**

## 🛠️ Common Commands

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f pingds
docker-compose logs -f pingam

# Stop services
docker-compose down

# Restart a service
docker restart pingds

# Enter container
docker exec -it pingds bash
docker exec -it pingam bash

# Check status
docker ps
```

## 📖 Learning Path

### Beginner

1. Start with PingDS setup
2. Understand LDAP structure (`LDAP_STRUCTURE_GUIDE.md`)
3. Import and query sample data
4. Practice LDAP search operations

### Intermediate

1. Set up PingAM container
2. Connect AM to DS data stores
3. Configure authentication
4. Test user authentication

### Advanced

1. Configure replication (`REPLICATION_SETUP_GUIDE.md`)
2. Set up multi-master topology
3. Implement OAuth 2.0 / OIDC
4. Configure federation

## 🤝 Contributing

This is a personal learning repository. Feel free to fork and adapt for your own learning!

## 📝 License

This project is for educational purposes only.

ForgeRock and Ping Identity are trademarks of their respective owners.

## 🔗 Resources

- [Ping Identity Documentation](https://docs.pingidentity.com/)
- [PingDS Documentation](https://docs.pingidentity.com/pingds/)
- [PingAM Documentation](https://docs.pingidentity.com/pingam/)
- [ForgeRock Community](https://community.pingidentity.com/)

## 📧 Contact

Created as part of ForgeRock / Ping Identity learning journey.

---

**Happy Learning! 🚀**
