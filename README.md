# Docker Container Security Hardening \& Cloud Infrastructure Project

**MSc Cybersecurity | Coventry University | Cloud Infrastructure and Operations**

\---

## Overview

This project demonstrates a full security transformation of a vulnerable, manually-operated Docker environment into a production-ready, hardened container infrastructure — aligned with CIS Docker Benchmark, OWASP Container Security standards, and NIST SP 800-190.

The work covers threat identification, container hardening, secrets management, vulnerability scanning integration, network segmentation, logging architecture, and a production-grade cloud deployment strategy on AWS EKS. All security controls are implemented as Infrastructure as Code using Docker Compose, with automated validation scripting.

\---

## Key Security Outcomes

|Metric|Before|After|
|-|-|-|
|Base Image Size|\~600MB (CentOS 7 EOL)|\~50MB (Alpine Linux 3.19)|
|Attack Surface|High — 4 exposed ports|Minimal — 1 port (HTTP only)|
|User Execution Context|Root (UID 0)|Non-root dedicated users|
|Container Privileges|`--privileged=true`|ALL capabilities dropped|
|Credential Handling|Hard-coded in Makefiles|Docker secrets (file-based injection)|
|Root Filesystem|Fully writable|Read-only + tmpfs|
|Vulnerability Status|Multiple HIGH/CRITICAL CVEs|Zero known critical vulnerabilities|
|Resource Controls|None|CPU and memory limits enforced|
|Monitoring|None|Health checks + structured logging|

\---

## Project Structure

```
├── SECURITY\_ANALYSIS\_REPORT.md        # 2,500+ word threat analysis
├── SECURITY\_IMPLEMENTATION\_GUIDE.md   # Full hardening walkthrough
├── README-DOCKER-COMPOSE.md           # Compose migration guide
├── README-CLOUD-DEPLOYMENT.md         # AWS EKS production strategy
├── docker-compose.hardened.yml        # Security-hardened orchestration
├── manage-secure.sh                   # Automated security management
├── dbserver/
│   ├── Dockerfile.hardened            # Hardened MariaDB container
│   └── mysqld-hardened.cnf            # Secure database configuration
├── webserver/
│   ├── Dockerfile.hardened            # Hardened Nginx/PHP-FPM container
│   └── configfiles/
│       ├── nginx-hardened.conf        # Security headers + rate limiting
│       ├── php-hardened.ini           # Dangerous functions disabled
│       └── docker-entrypoint-hardened.sh
├── secrets/                           # Docker secrets storage
│   ├── db\_root\_password.txt
│   └── db\_user\_password.txt
└── logs/
    ├── nginx/
    └── mysql/
```

\---

## Part A — Security Analysis

### Threat Identification

The original prototype used a Makefile-driven workflow with CentOS 7 base images, no orchestration, and no security controls. Six critical vulnerabilities were identified and documented:

1. **EOL Base Images** — CentOS 7 reached end of life June 2024; no upstream patches available.
2. **Privileged Execution** — Database container launched with `--privileged=true`, breaking kernel-level isolation.
3. **Root User Processes** — Both containers ran as UID 0, violating least privilege.
4. **Excessive Port Exposure** — SSH (22) and Docker daemon (2375) exposed alongside HTTP.
5. **Hard-coded Credentials** — Passwords embedded directly in Makefiles and environment variables.
6. **No Resource Limits** — Unlimited CPU and memory, enabling denial-of-service via resource exhaustion.

### Docker Compose Migration

The system was migrated from ad-hoc Makefile execution to a declarative Docker Compose architecture, providing:

* Version-controlled Infrastructure as Code with auditable security controls
* Automated dependency management via health checks and `depends\_on` rules
* Network segmentation isolating front-end and back-end traffic
* Single-command deployment, teardown, and validation

### Container Image Hardening

**Web Container**

* Migrated from CentOS 7 (\~600MB) to Alpine Linux 3.19 (\~50MB) — 92% size reduction
* Multi-stage build: separate build and runtime stages, eliminating compilers and tooling from the final image
* Non-root user created at build time: `webuser` (UID 1001)
* Read-only root filesystem with tmpfs mounts for writable paths

**Database Container**

* Official MariaDB 10.11 on Alpine base
* Non-root `mysql` user execution
* Hardened `mysqld.cnf`: disabled local infile, skip-show-database, connection limits enforced

**Runtime Controls (Docker Compose)**

```yaml
security\_opt:
  - no-new-privileges:true
  - apparmor:docker-nginx
  - seccomp:seccomp.json
cap\_drop:
  - ALL
cap\_add:
  - NET\_BIND\_SERVICE
read\_only: true
tmpfs:
  - /tmp:rw,noexec,nosuid,size=100m
```

### Vulnerability Scanning

A multi-stage scanning pipeline was designed and integrated using **Trivy** as the primary scanner and **Snyk** as a complementary tool:

* **Pre-commit** — Local developer scans before push
* **Build-time** — Automated Trivy image and config scans; pipeline fails on HIGH/CRITICAL findings
* **Configuration** — Trivy config scans on Dockerfiles and Compose files
* **Runtime** — Periodic registry re-scans triggered by CVE database updates

Remediation severity matrix:

|Severity|Required Action|
|-|-|
|Critical / High|Block deployment immediately; patch or rebuild|
|Medium|Fix within SLA|
|Low|Track for routine maintenance|

### Docker Host \& Daemon Security

* Docker daemon hardened with TLS authentication, user namespace remapping (`userns-remap: default`), and `no-new-privileges` at runtime
* AppArmor custom profile applied to Nginx container restricting write access to `/proc/sys` and `/sys`
* Custom seccomp policy limiting available syscalls to the application's minimum required set
* Inter-container communication restricted to required paths only (web → database)

### Logging, Monitoring \& Incident Response

**Multi-layer logging architecture:**

* Application logs: Nginx access/error, PHP error logs
* Container logs: Docker JSON log driver (stdout/stderr)
* System logs: Docker daemon and host OS events
* Security logs: Authentication attempts, privilege escalation events

**ELK Stack** proposed for centralised log management (Elasticsearch, Logstash, Kibana).

**Prometheus + Grafana** for metrics and alerting covering:

* CPU throttling and OOM events
* Failed login counters
* Abnormal request volume spikes
* Seccomp/AppArmor violation events

**Incident response capabilities:**

* Container isolation and reconstruction from known-good images
* Forensic snapshotting of container filesystems
* Structured log retention (90-day minimum)
* SIEM integration path via Logstash → Splunk / Elastic SIEM / Wazuh

\---

## Part B — Practical Implementation

### Running the Hardened Environment

```bash
# Security pre-flight check
./manage-secure.sh security-check

# Build hardened images
./manage-secure.sh build

# Start secure services
./manage-secure.sh up

# Verify non-root execution
docker-compose -f docker-compose.hardened.yml exec web whoami
# Expected: webuser

docker-compose -f docker-compose.hardened.yml exec db whoami
# Expected: mysql

# Verify read-only filesystem
docker-compose -f docker-compose.hardened.yml exec web touch /test.txt
# Expected: Permission denied

# Full security report
./manage-secure.sh security-report
```

### Web Server Hardening (Nginx)

Security headers enforced:

```nginx
add\_header X-Frame-Options DENY always;
add\_header X-Content-Type-Options nosniff always;
add\_header X-XSS-Protection "1; mode=block" always;
add\_header Strict-Transport-Security "max-age=31536000" always;
add\_header Content-Security-Policy "default-src 'self'" always;
```

Rate limiting applied:

```nginx
limit\_req\_zone $binary\_remote\_addr zone=login:10m rate=5r/m;
limit\_conn\_zone $binary\_remote\_addr zone=conn\_limit\_per\_ip:10m;
```

### PHP Hardening

```ini
expose\_php = Off
allow\_url\_fopen = Off
allow\_url\_include = Off
disable\_functions = exec,passthru,shell\_exec,system,proc\_open
```

### Secrets Management

Credentials removed from environment variables and Makefiles. All sensitive data injected at runtime via Docker secrets:

```yaml
secrets:
  db\_root\_password:
    file: ./secrets/db\_root\_password.txt
  db\_user\_password:
    file: ./secrets/db\_user\_password.txt
```

\---

## Part C — Cloud Deployment Strategy (AWS EKS)

### Platform Justification

Docker Compose cannot provide the scalability, resilience, or cluster-level security controls required for production. Three deployment models were evaluated — IaaS, PaaS, and CaaS. **AWS EKS (Container as a Service)** was selected as the natural progression from Compose-based development.

Key reasons:

* Managed Kubernetes control plane with native IAM roles for service accounts (IRSA)
* Supports all Part A security controls via Kubernetes `PodSecurityContext`
* Deep integration with CloudWatch, ECR, KMS, and VPC
* Native Horizontal Pod Autoscaler and Cluster Autoscaler

### High-Availability Architecture

* Multi-AZ EKS cluster across three availability zones in `us-west-2`
* Worker nodes in private subnets; ALB in public subnets
* Pod anti-affinity rules distributing workloads across nodes
* RDS MariaDB Multi-AZ with automatic failover (\~60 seconds)
* Network policies enforcing zero-trust inter-service communication

**Part A controls mapped to Kubernetes equivalents:**

|Docker Hardening Control|Kubernetes Equivalent|
|-|-|
|Non-root user|`runAsNonRoot: true`|
|Read-only filesystem|`readOnlyRootFilesystem: true`|
|Drop ALL capabilities|`capabilities: { drop: \["ALL"] }`|
|Docker secrets|Kubernetes Secrets + AWS KMS encryption|
|AppArmor / seccomp|Pod annotations with restrictive profiles|

### CI/CD Pipeline

```
Code Commit → Build (multi-stage Dockerfile) → Test → Trivy Scan
→ Security Gate → Push to ECR → Deploy to EKS → Rollout Validation
```

Pipeline security controls:

* Trivy image scan with `--exit-code 1` on HIGH/CRITICAL findings
* SBOM generation via Syft for software transparency
* Cosign image signing and attestation
* OPA/Conftest policy checks on Kubernetes manifests before deployment

### Estimated Monthly Cost (GBP, us-west-2)

|Component|Estimated Cost|
|-|-|
|EKS Control Plane|£58|
|Worker Nodes (t3.medium × 3)|£72|
|RDS MariaDB Multi-AZ|£52–£65|
|Application Load Balancer|£19|
|NAT Gateway (2×)|£52 + data|
|CloudWatch|£8–£24|
|ECR Storage|£2–£4|
|**Total Baseline**|**£270–£315/month**|

Cost optimisation strategies: Reserved Instances (40–60% compute saving), Spot Instances for CI/staging, VPC endpoints to eliminate NAT data fees, Aurora Serverless v2 for variable database workloads.

\---

## Compliance

* **CIS Docker Benchmark v1.6.0** — All applicable controls implemented
* **OWASP Top 10 Container Security Risks** — Defence-in-depth strategy applied
* **NIST SP 800-190** — Application Container Security Guide followed throughout

\---

## Technologies Used

**Containerisation:** Docker, Docker Compose, Alpine Linux, MariaDB, Nginx, PHP-FPM

**Security Tools:** Trivy, Snyk, AppArmor, Seccomp, Docker Secrets

**Monitoring \& Logging:** Prometheus, Grafana, ELK Stack (Elasticsearch, Logstash, Kibana)

**Cloud \& Orchestration:** AWS EKS, AWS RDS, AWS ECR, AWS ALB, Kubernetes, GitHub Actions

\---

## Academic Context

This project was completed as part of the **Cloud Infrastructure and Operations** module at Coventry University (MSc Cybersecurity, 2025–2026). Module grade: **85%**.

The accompanying security analysis report (2,500+ words) covers threat modelling, container hardening methodology, vulnerability management pipeline design, host and daemon security, and full logging and incident response architecture.

