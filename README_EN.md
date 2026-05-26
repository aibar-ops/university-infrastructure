# 🏛️ Buketov University — Kubernetes Infrastructure

**Production-grade Kubernetes infrastructure** for Karaganda Buketov University (Kazakhstan).

> Designed, architected and built from scratch by **Aibar Abil** — Systems / DevOps Engineer.

---

## 📊 Infrastructure Scale

| Parameter | Value |
|---|---|
| 🖥️ Physical Servers | 27 |
| ☁️ Virtual Machines (Proxmox) | 100+ |
| 🟢 Kubernetes Nodes | 24 |
| 📦 Running Pods | 114+ |
| 🌐 Production Websites | 50+ |
| 👥 End Users | 10,000+ (students, faculty, staff) |
| 💾 NFS Storage | 1024+ GB |
| 🤖 AWX Managed Hosts | 103 |

---

## 📅 Project Timeline

| Date | Milestone |
|---|---|
| **January 2025** | Joined as Systems Administrator |
| **2025** | Deep study of existing university infrastructure |
| **December 2025** | Designed new architecture (High-Level Design) |
| **Jan — Mar 20, 2026** | Built Kubernetes cluster from scratch (**first K8s experience**) |
| **Mar 20 — May 1, 2026** | Break |
| **May 2026 — present** | Stabilization, site migration to GitOps + CI/CD |

> **The entire Kubernetes cluster was designed and deployed in ~3 months of active development — as a first Kubernetes project, with no prior experience.**

---

## 🎯 About This Project

This repository contains the full Kubernetes infrastructure I designed and implemented for the university.

Before late 2025 I had no Kubernetes experience. Within 3–4 months of active development I delivered a stable, highly available, and secure enterprise-grade infrastructure — alone, without a mentor, in a real production environment serving 10,000+ users.

---

## 🏗️ Cluster Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER v1.29.15                  │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   k8s-1      │  │   k8s-2      │  │   k8s-3      │          │
│  │ control-plane│  │ control-plane│  │ control-plane│          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│          HA Cluster — 3 control plane nodes + etcd              │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    WORKER NODES                         │   │
│  │                                                         │   │
│  │  [awx] [awx-2]        → AWX / Ansible Automation       │   │
│  │  [gitea]              → CI/CD (Gitea + Kaniko runners) │   │
│  │  [ns1][ns2][ns3][ns4] → PowerDNS (internal/external)  │   │
│  │  [site-1..site-7]     → University websites            │   │
│  │  [grafana-new]        → Grafana dashboards             │   │
│  │  [influx-new]         → InfluxDB telemetry             │   │
│  │  [wazuh-new]          → Wazuh SIEM                     │   │
│  │  [zabbix-new]         → Zabbix monitoring              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  CNI: Calico  │  Ingress: NGINX DaemonSet  │  RBAC: Rancher    │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
  ┌─────────────┐    ┌──────────────┐    ┌──────────────┐
  │  containerd │    │  NFS Server  │    │   Proxmox    │
  │  DB Cluster │    │  1024+ GB    │    │  5-node HCI  │
  │  (isolated) │    │  (file store)│    │  100+ VMs    │
  └─────────────┘    └──────────────┘    └──────────────┘
```

---

## 🔄 CI/CD Pipeline

```
Developer pushes code
        │
        ▼
┌───────────────┐
│     Gitea     │  ← Self-hosted Git (source control)
│  (namespace:  │
│    gitea)     │
└───────┬───────┘
        │ webhook trigger
        ▼
┌───────────────┐
│ Gitea Runner  │  ← Act Runner pods inside K8s
│  (namespace:  │
│ gitea-runner) │
└───────┬───────┘
        │ smart build logic:
        │ Dockerfile changed? → full Kaniko build
        │ PHP/JS only?        → rollout restart (code from NFS)
        ▼
┌───────────────┐
│    Kaniko     │  ← Docker image build inside K8s
│  (ephemeral   │     no Docker daemon required
│   build pod)  │
└───────┬───────┘
        │ push image to Gitea registry
        ▼
┌───────────────┐
│  Kubernetes   │  ← Rolling update (zero downtime)
│  Deployment   │     maxUnavailable: 0
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  Ingress NGINX│  ← Traffic routing + SSL termination
│  + PowerDNS   │
└───────────────┘
```

---

## 🗄️ Database Isolation

All databases are intentionally **kept outside Kubernetes** in a dedicated containerd cluster:

```
┌─────────────────────────────────────────────┐
│           DATABASE ISOLATION LAYER          │
│                                             │
│  ┌─────────────────┐                        │
│  │  _internal_db   │ ← AWX, Gitea,          │
│  │                 │   PowerAdmin           │
│  └─────────────────┘                        │
│                                             │
│  ┌─────────────────┐                        │
│  │  university-db  │ ← All university       │
│  │                 │   websites             │
│  └─────────────────┘                        │
│                                             │
│  ┌─────────────────┐                        │
│  │  telemetry-db   │ ← InfluxDB,            │
│  │                 │   Zabbix, Wazuh        │
│  └─────────────────┘                        │
│                                             │
│  Dashboards managed through K8s Ingress     │
│  Data stored on isolated NFS server         │
└─────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
university-infrastructure/
│
├── awx/                          # AWX Ansible Automation Platform
│   ├── awx-instance.yaml         # HA config (2 web + 2 task replicas)
│   ├── awx-ingress.yaml
│   └── awx-quota.yaml
│
├── gitea/                        # Gitea SCM + CI/CD
│   ├── values.example.yaml       # Helm values template (no secrets)
│   ├── runner.yaml               # Gitea Act Runner
│   └── rbac.yaml
│
├── ingress/                      # Ingress NGINX
│   ├── ingress-ds.yaml           # DaemonSet with hostNetwork
│   └── ingress.yaml
│
├── pdns/                         # PowerDNS
│   ├── pdns-internal.yaml        # Internal DNS
│   ├── pdns-external.yaml        # External DNS
│   ├── pdns-admin-svc.yaml
│   └── pdns-ingress.yaml
│
├── sites/                        # University websites
│   ├── karnu-buketov.edu.kz/     # Main university website
│   │   ├── app-deployment.yaml   # HPA + RollingUpdate + NFS mounts
│   │   ├── app-ingress.yaml      # Sticky sessions, CORS
│   │   ├── Dockerfile            # PHP 7.4-fpm-alpine, non-root
│   │   ├── nginx.conf            # Optimized nginx config
│   │   └── pipeline.yaml         # Smart Kaniko CI/CD workflow
│   ├── abiturient/
│   ├── olympiads/
│   ├── talapker/
│   ├── jastar/
│   └── laureat/
│
├── telemetria/                   # Monitoring & SIEM
│   ├── grafana/
│   ├── influxdb/
│   ├── zabbix/
│   ├── wazuh/
│   └── vector.yaml
│
├── phpmyadmin/                   # DB Management UI (Basic Auth + cookie auth)
├── kube/                         # Cluster bootstrap configs
└── .gitignore                    # Secrets, keys, .env excluded
```

---

## 🛠️ Tech Stack

### Orchestration & Containers
- **Kubernetes** v1.29.15 — HA cluster, 3 control plane nodes
- **Calico CNI** — network policies and traffic routing
- **containerd** — container runtime
- **Rancher** v2.13.3 — cluster management UI
- **Helm** — package manager

### CI/CD & Automation
- **Gitea** v1.21.11 — self-hosted Git + container registry
- **Kaniko** — daemonless image builds inside Kubernetes
- **AWX / Ansible** — automation for 103 managed hosts

### Networking & DNS
- **Ingress NGINX** — DaemonSet with hostNetwork (bare metal)
- **PowerDNS** — split-horizon DNS (internal + external)
- **Calico NetworkPolicy** — pod-level traffic isolation

### Monitoring & Security
- **Zabbix** — infrastructure monitoring
- **Grafana + InfluxDB** — metrics and dashboards
- **Wazuh** — SIEM (in development)
- **Vector** — log aggregation

### Storage
- **NFS Server** — 1024+ GB persistent storage
- **containerd DB cluster** — isolated database layer
- **MySQL / MariaDB / PostgreSQL** — RDBMS

---

## ⚙️ Key Architecture Decisions

### 1. HA Control Plane
Three control plane nodes with etcd quorum. Loss of one node does not affect cluster operation.

### 2. Databases Outside Kubernetes
Databases are intentionally isolated in a separate containerd cluster. This decouples data persistence from cluster lifecycle and simplifies backup/restore operations.

### 3. NFS Isolated from Cluster
Media files, documents and static assets live on a dedicated NFS server. Kubernetes only mounts volumes — data is physically independent of the cluster.

### 4. Ingress as DaemonSet
Ingress NGINX runs as a DaemonSet with `hostNetwork: true` — L7 load balancing on every node without an external LoadBalancer. Designed for bare metal environments.

### 5. Smart CI/CD Pipeline
Pipeline checks which files changed before deciding to rebuild:
- `Dockerfile` or `nginx.conf` changed → full Kaniko image rebuild
- PHP / JS / CSS only → `rollout restart` (code pulled from NFS mount, no rebuild needed)

This cuts average pipeline time significantly for code-only changes.

### 6. HPA Autoscaling
Critical sites scale automatically from 2 to 7 replicas at 70% CPU load. Combined with `maxUnavailable: 0` rolling updates — zero downtime for users.

### 7. Namespace / Taint / Label Isolation
Every component runs in a dedicated namespace. Taints ensure pods are scheduled only on their designated nodes — no accidental co-location of unrelated workloads.

---

## 🔐 Security

- All credentials managed via Kubernetes Secrets (migration to Vault planned)
- TLS certificates on all public endpoints
- phpMyAdmin protected by Ingress Basic Auth + cookie-based DB auth
- Calico NetworkPolicy — implicit deny, allow only from Ingress NGINX
- Non-root containers (`runAsUser: 1000`) where possible
- Admin paths (`/admin`, `/admin-edit`) restricted to internal network via `whitelist-source-range`
- Wazuh SIEM for security event monitoring

---

## 📈 Component Status

| Component | Status | Namespace |
|---|---|---|
| Kubernetes HA Cluster | ✅ Production | kube-system |
| AWX / Ansible | ✅ Production | awx |
| Gitea CI/CD | ✅ Production | gitea |
| Ingress NGINX | ✅ Production | ingress-nginx |
| PowerDNS (internal + external) | ✅ Production | powerdns |
| University Websites | ✅ Production | university-sites |
| Zabbix Monitoring | ✅ Production | zabbix |
| Grafana + InfluxDB | ✅ Production | telemetria / monitoring |
| phpMyAdmin | ✅ Production | university-sites |
| Wazuh SIEM | 🔧 In Development | wazuh |
| Moodle LMS | 🔧 In Development | university-sites |

---

## 👤 Author

**Aibar Abil** — Systems Engineer / DevOps  
Karaganda Buketov University  
📧 abilaibar@gmail.com  
📍 Karaganda, Kazakhstan — open to relocation

> This entire infrastructure was designed and built from scratch in 2025–2026.  
> The Kubernetes cluster was deployed in ~3 months of active development as a first K8s project.  
> This repository contains sanitized, production-ready architectural templates. No real secrets, private keys, or internal IP addresses are exposed.

---

*Karaganda Buketov University IT Infrastructure — 2026*
