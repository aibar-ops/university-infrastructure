# 🏛️ Buketov University — Enterprise Kubernetes Infrastructure

> Production-grade infrastructure for Karaganda Buketov University  
> Designed, built and maintained by **Aibar Abil** — Systems/DevOps Engineer

---

## 📊 Масштаб инфраструктуры

| Параметр | Значение |
|---|---|
| 🖥️ Физических серверов | 27 |
| ☁️ Виртуальных машин (Proxmox) | 100+ |
| 🟢 Kubernetes нод | 24 |
| 📦 Подов в кластере | 114+ |
| 🌐 Production сайтов | 50+ |
| 👥 Пользователей | 10 000+ (студенты, преподаватели, сотрудники) |
| 💾 Данных на NFS | 259 ГБ |
| 🤖 AWX хостов под управлением | 103 |

---

## 🏗️ Архитектура кластера

```
┌─────────────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER v1.29.15                  │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   k8s-1      │  │   k8s-2      │  │   k8s-3      │          │
│  │ control-plane│  │ control-plane│  │ control-plane│          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│          HA кластер — 3 control plane ноды + etcd               │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    WORKER NODES                         │   │
│  │                                                         │   │
│  │  [awx] [awx-2]     → AWX / Ansible Automation          │   │
│  │  [gitea]           → CI/CD (Gitea + Kaniko runners)    │   │
│  │  [ns1][ns2][ns3][ns4] → PowerDNS (internal/external)  │   │
│  │  [site-1..site-7]  → University websites               │   │
│  │  [grafana-new]     → Grafana dashboards                │   │
│  │  [influx-new]      → InfluxDB telemetry                │   │
│  │  [wazuh-new]       → Wazuh SIEM                        │   │
│  │  [zabbix-new]      → Zabbix monitoring                 │   │
│  │  [bd-zabbix]       → Database node                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  CNI: Calico  │  Ingress: NGINX DaemonSet  │  RBAC: Rancher    │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
  ┌─────────────┐    ┌──────────────┐    ┌──────────────┐
  │  containerd │    │  NFS Server  │    │   Proxmox    │
  │  DB Cluster │    │   501 ГБ     │    │  5-node HCI  │
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
│     Gitea     │  ← Source control
│  (namespace:  │     gitea.karnu-buketov.edu.kz
│    gitea)     │
└───────┬───────┘
        │ webhook trigger
        ▼
┌───────────────┐
│ Gitea Runner  │  ← Runner pods внутри K8s
│  (namespace:  │
│ gitea-runner) │
└───────┬───────┘
        │ запуск
        ▼
┌───────────────┐
│    Kaniko     │  ← Сборка Docker образа внутри K8s
│  (build pod)  │     без Docker daemon
└───────┬───────┘
        │ push image
        ▼
┌───────────────┐
│  Kubernetes   │  ← Деплой обновлённого образа
│  Deployment   │     rolling update
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  Ingress NGINX│  ← Маршрутизация трафика
│  + PowerDNS   │     SSL termination
└───────────────┘
```

---

## 🗄️ Изоляция баз данных

Все БД вынесены **за пределы Kubernetes** в отдельный containerd кластер:

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
│  │  university-db  │ ← Все сайты            │
│  │  (phpMyAdmin:   │   университета         │
│  │  pma.karnu-     │                        │
│  │  buketov.edu.kz)│                        │
│  └─────────────────┘                        │
│                                             │
│  ┌─────────────────┐                        │
│  │  telemetry-db   │ ← InfluxDB,            │
│  │                 │   Zabbix, Wazuh        │
│  └─────────────────┘                        │
│                                             │
│  Управление через дашборды внутри кластера  │
│  Данные на NFS — отдельный сервер           │
└─────────────────────────────────────────────┘
```

---

## 📁 Структура репозитория

```
university-infrastructure/
│
├── awx/                          # AWX Ansible Automation Platform
│   ├── awx-instance.yaml         # HA конфигурация (2 web + 2 task реплики)
│   ├── awx-ingress.yaml
│   ├── awx-quota.yaml
│   └── awx-postgres-secret.yaml  # (секреты в .gitignore)
│
├── gitea/                        # Gitea SCM + CI/CD
│   ├── values.yaml               # Helm values (credentials → env)
│   ├── runner.yaml               # Gitea Act Runner
│   └── rbac.yaml
│
├── ingress/                      # Ingress NGINX
│   ├── ingress-ds.yaml           # DaemonSet с hostNetwork
│   └── ingress.yaml
│
├── pdns/                         # PowerDNS
│   ├── pdns-internal.yaml        # Внутренний DNS
│   ├── pdns-external.yaml        # Внешний DNS
│   ├── pdns-admin-svc.yaml
│   ├── pdns-ingress.yaml
│   └── pdns-secrets.yaml         # (секреты в .gitignore)
│
├── sites/                        # University websites
│   ├── abiturient/               # Сайт абитуриентов
│   ├── karnu-buketov.edu.kz/     # Главный сайт
│   ├── olympiads/                # Олимпиады
│   ├── talapker/                 # Талапкер
│   ├── jastar/                   # Жастар
│   └── laureat/                  # Лауреат
│
├── telemetria/                   # Мониторинг и SIEM
│   ├── grafana/
│   ├── influxdb/
│   ├── zabbix/
│   ├── wazuh/
│   └── vector.yaml
│
├── phpmyadmin/                   # DB Management UI
├── kube/                         # Cluster configuration
│   ├── kube-apiserver.yaml
│   ├── operator.yaml
│   └── rancher-values.yaml
│
└── ssl/                          # TLS сертификаты (приватные ключи в .gitignore)
```

---

## 🛠️ Технический стек

### Оркестрация и контейнеры
- **Kubernetes** v1.29.15 — HA кластер, 3 control plane
- **Calico CNI** — сетевые политики и маршрутизация трафика
- **containerd** — container runtime
- **Rancher** v2.13.3 — управление кластером
- **Helm** — пакетный менеджер

### CI/CD и автоматизация
- **Gitea** v1.21.11 — self-hosted Git + issue tracker
- **Kaniko** — сборка образов без Docker daemon
- **AWX** (Ansible) — автоматизация 103 хостов

### Сеть и DNS
- **Ingress NGINX** — DaemonSet с hostNetwork
- **PowerDNS** — internal + external DNS серверы
- **Calico** — сетевая политика внутри кластера

### Мониторинг и безопасность
- **Zabbix** — инфраструктурный мониторинг
- **Grafana + InfluxDB** — метрики и дашборды
- **Wazuh** — SIEM (в разработке)
- **Vector** — агрегация логов

### Хранилище
- **NFS Server** — 501 ГБ, персистентное хранилище
- **containerd DB cluster** — изолированные БД
- **MySQL / MariaDB / PostgreSQL** — СУБД

---

## ⚙️ Ключевые архитектурные решения

### 1. HA Control Plane
Три control plane ноды обеспечивают отказоустойчивость кластера. При потере одной ноды кластер продолжает работу.

### 2. База данных вне Kubernetes
БД намеренно вынесены в containerd кластер отдельно от Kubernetes. Это защищает данные от сбоев внутри кластера и упрощает backup.

### 3. NFS отдельно от кластера
Файловое хранилище (фото, видео, документы) находится на выделенном NFS сервере. Kubernetes только монтирует тома, данные физически изолированы.

### 4. Ingress как DaemonSet
Ingress NGINX развёрнут как DaemonSet с `hostNetwork: true`. Это обеспечивает L7 балансировку на каждой ноде без внешнего LoadBalancer.

### 5. HPA автомасштабирование
Для критичных сайтов настроен HPA до 7 реплик при нагрузке 70%+. Кластер автоматически масштабируется под пиковый трафик.

### 6. Изоляция через namespace/taint/label
Каждый компонент изолирован в отдельном namespace. Taints гарантируют что поды запускаются только на предназначенных нодах.

---

## 🔐 Безопасность

- Все секреты через Kubernetes Secrets (миграция на `.env` → Vault в планах)
- TLS сертификаты на всех публичных эндпоинтах
- phpMyAdmin доступен только через Ingress с аутентификацией
- Wazuh SIEM для мониторинга безопасности
- Сетевые политики через Calico

---

## 📈 Статус компонентов

| Компонент | Статус | Namespace |
|---|---|---|
| Kubernetes HA | ✅ Production | kube-system |
| AWX / Ansible | ✅ Production | awx |
| Gitea CI/CD | ✅ Production | gitea |
| Ingress NGINX | ✅ Production | ingress-nginx |
| PowerDNS | ✅ Production | powerdns |
| University Sites | ✅ Production | university-sites |
| Zabbix | ✅ Production | zabbix |
| Grafana + InfluxDB | ✅ Production | telemetria / monitoring |
| phpMyAdmin | ✅ Production | university-sites |
| Wazuh SIEM | 🔧 In Development | wazuh |
| Moodle | 🔧 In Development | university-sites |

---

## 👤 Автор

**Айбар Абил** — Systems Engineer / DevOps  
Карагандинский университет им. Букетова  
📧 abilaibar@gmail.com  
📍 Казахстан, Караганда

> Вся инфраструктура спроектирована и построена с нуля в 2025–2026 году.  
> Kubernetes кластер развёрнут за 3 месяца активной разработки.

---

*Karaganda Buketov University IT Infrastructure — 2026*
