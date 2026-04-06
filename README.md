# GCP Terraform Interview Practice

Practice Terraform configs for a Google Cloud Engineer role (DoD/IC).
Each phase builds on the previous one, adding complexity incrementally.

## Architecture Overview

```mermaid
graph TB
    subgraph "GCP Project: tf-gcp-practice-0406"
        subgraph "Global VPC: dev-vpc"
            subgraph "us-east4 Region"
                SUBNET["Subnet: dev-private-subnet<br/>10.0.1.0/24<br/>private_ip_google_access = true"]
                PODS["Secondary Range: pods<br/>10.10.0.0/16"]
                SVCS["Secondary Range: services<br/>10.20.0.0/20"]

                subgraph "Cloud NAT"
                    ROUTER["Cloud Router: dev-router"]
                    NAT["Cloud NAT: dev-nat<br/>AUTO_ONLY"]
                end
            end

            subgraph "Firewall Rules (VPC-level)"
                FW1["allow-internal<br/>TCP/UDP/ICMP from 10.x.x.x<br/>Priority: 1000"]
                FW2["allow-iap-ssh<br/>TCP:22 from 35.235.240.0/20<br/>Priority: 1000"]
                FW3["deny-all-ingress<br/>ALL from 0.0.0.0/0<br/>Priority: 65534"]
            end
        end

        ROUTE["Route: 0.0.0.0/0 → internet-gateway"]
        GAPI["Google APIs<br/>(Cloud Storage, BigQuery, etc.)"]
    end

    INTERNET["Internet"]
    IAP["Identity-Aware Proxy<br/>(35.235.240.0/20)"]
    ADMIN["Admin/Engineer"]

    SUBNET --> |"private_ip_google_access"| GAPI
    SUBNET --> ROUTER --> NAT --> ROUTE --> INTERNET
    ADMIN --> IAP --> |"SSH via IAP tunnel"| SUBNET
```

## Phases

| Phase | Description | Status |
|-------|-------------|--------|
| [01-networking](phases/01-networking/) | VPC, subnets, firewall rules, Cloud NAT | Applied |
| [02-compute](phases/02-compute/) | Compute Engine + custom service account | Pending |
| [03-database](phases/03-database/) | Cloud SQL + private VPC peering | Pending |
| [04-gke](phases/04-gke/) | Private GKE cluster + Workload Identity | Pending |
| [05-modules](phases/05-modules/) | Refactor into reusable modules | Pending |
| [06-cicd](phases/06-cicd/) | Cloud Build CI/CD pipeline | Pending |

## GCP vs AWS Quick Reference

| Concept | GCP | AWS |
|---------|-----|-----|
| VPC scope | **Global** | Regional |
| Subnet scope | **Regional** (all zones) | Per-AZ |
| Firewall | VPC-level, **target tags** | Security groups per-ENI |
| Private API access | `private_ip_google_access` | VPC Gateway Endpoints |
| NAT | Cloud NAT (managed) | NAT Gateway |
| SSH without public IP | **IAP tunneling** | SSM Session Manager |
| Instance identity | **Service accounts** | Instance profiles/roles |
| K8s pod identity | **Workload Identity** | IRSA |
| Account isolation | **Projects** | AWS Accounts |
| GovCloud equivalent | **Assured Workloads** | AWS GovCloud |
| Org hierarchy | Org → Folders → Projects | Org → OUs → Accounts |

## Security Checklist (DoD/FedRAMP)

Every Terraform config in this repo follows these patterns:

- [x] `auto_create_subnetworks = false` — no default subnets
- [x] `private_ip_google_access = true` — private access to Google APIs
- [x] No `access_config` on VMs — no public IPs
- [x] IAP for SSH — no bastion hosts, IAM-authenticated access
- [x] VPC flow logs enabled — NIST 800-53 AU controls
- [x] `ipv4_enabled = false` on Cloud SQL — no public database endpoint
- [x] Dedicated service accounts — never use default compute SA
- [x] `sensitive = true` on secrets — no passwords in plan output
- [x] `.id` references — proper Terraform dependency tracking
- [x] `for_each` over `count` — stable resource addressing
