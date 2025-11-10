# 02 - Arquitetura, decisões e trade-offs

Este documento resume a arquitetura lógica da solução, os componentes AWS/Kubernetes envolvidos e os motivos das escolhas em relação a disponibilidade, custo e operabilidade.

## Visão de alto nível

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            AWS Account / VPC (10.20.0.0/16)                 │
│                                                                             │
│  ┌───────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │ Public Subnet │    │ Public Subnet│    │ Public Subnet│                  │
│  │   us-east-1a  │    │   us-east-1b │    │   us-east-1c │                  │
│  │  NLB + EIPs   │    │  NLB + EIPs  │    │  NLB + EIPs  │                  │
│  └───────────────┘    └──────────────┘    └──────────────┘                  │
│        ▲                   ▲                   ▲                            │
│        │                   │                   │                            │
│        ▼                   ▼                   ▼                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     Managed EKS Control Plane (HA)                    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│        ▲                   ▲                   ▲                            │
│        │                   │                   │                            │
│  ┌───────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │ Private Subnet│    │ Private Subnet│    │ Private Subnet│                │
│  │   us-east-1a  │    │   us-east-1b │    │   us-east-1c │                  │
│  │ NodeGroup A   │    │ NodeGroup B  │    │ NodeGroup C  │                  │
│  │ (on-demand)   │    │ (spot mix)   │    │ (spot mix)   │                  │
│  └───────────────┘    └──────────────┘    └──────────────┘                  │
│        │                   │                   │                            │
│        ▼                   ▼                   ▼                            │
│  ┌─────────────────────┐ ┌────────────────────┐ ┌─────────────────────┐     │
│  │ ingress-nginx       │ │ observability      │ │ workloads demo      │     │
│  │ (IRSA + HPA + PDB)  │ │ (Prom/Graf/Loki/   │ │ (whoami + policies) │     │
│  │                     │ │ Tempo + OTel)      │ │                     │     │
│  └─────────────────────┘ └────────────────────┘ └─────────────────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Componentes principais

| Camada | Componentes | Motivo da escolha |
|--------|-------------|-------------------|
| Rede | VPC customizada com 3 subnets públicas + 3 privadas, NAT Gateways redundantes, VPC Endpoints (ECR, SSM, Logs) | Garante tráfego interno privado, redução de custo com data transfer e suporte a clusters privados. |
| Compute | EKS gerenciado, 3 node groups (1 on-demand, 2 spot com _mixed instances_, distribuição por zona) | Equilíbrio entre custo e resiliência; `topologySpreadConstraints` + `podAntiAffinity` asseguram HA real. |
| Entrada | `ingress-nginx` usando NLB IP-mode + cross-zone | Permite controle total das features do NGINX (mTLS, rewrites, rate-limit) e integra com OpenTelemetry/Prometheus nativamente. |
| DNS/TLS | `external-dns` + `cert-manager` (Let's Encrypt DNS-01) | Automatiza criação de registros e certificados válidos para produção. |
| Observabilidade | `kube-prometheus-stack`, `Loki`, `Tempo`, `OpenTelemetry Collector`, dashboards customizados | Stack _unificada_ de métricas, logs e traces com integração Tempo ↔ Grafana ↔ Loki. |
| Dados | Buckets S3 dedicados (Loki chunks + Tempo blocks) com versionamento e lifecycle | Barato, durável e desacoplado dos nós do cluster; facilita retenção e restores. |
| Segurança | IRSA (least privilege), NetworkPolicies, Pod Security Admission, TLS forte | Atende requisitos mínimos de Zero Trust interno. |

## Decisões e trade-offs

| Tema | Decisão | Alternativas consideradas | Trade-offs |
|------|---------|---------------------------|------------|
| Ingress Controller | `ingress-nginx` + NLB IP target | AWS Load Balancer Controller (ALB) | NGINX oferece maior flexibilidade (snippets, Lua, rate limiting). NLB mantém IP estático. Porém, demanda manutenção de chart próprio. |
| Observabilidade | Stack Grafana OSS (Prometheus/Loki/Tempo) | AWS Managed Prometheus + CloudWatch | OSS evita lock-in e reduz custo, mas exige gestão de upgrades e armazenamento S3. |
| Armazenamento de logs/traces | S3 + IRSA | EFS, DynamoDB | S3 é barato e suporta alta durabilidade; acesso via IRSA garante _least privilege_. Exige configurar lifecycle e compressão. |
| Segurança TLS | Let's Encrypt DNS-01 | HTTP-01, ACM | DNS-01 funciona para domínios privados e wildcard; requer permissões Route53 bem definidas. |
| Alta disponibilidade | 3 zonas, HPA, PDB, PodTopologySpread | 2 zonas, sem constraints | 3 zonas reduz blast radius mas aumenta custo mínimo (3 NAT). TopologySpread evita concentração mas pode reprovaar agendamentos em caso de falta de capacidade. |
| Deploy IaC | Terraform + Helmfile + GitHub Actions | AWS CDK, ArgoCD | Terraform/Helmfile são ferramentas conhecidas e fáceis de revisar. ArgoCD daria _GitOps_ completo, porém aumentaria o tempo de setup. |

## Fluxo de dados observabilidade

1. **Métricas**: Prometheus coleta do Kubernetes e do ingress-nginx. Exemplars são habilitados e permitem clicar do gráfico para um trace no Tempo.
2. **Logs**: Promtail envia para Loki, armazenado em S3. Grafana possui _Explore_ e _LogQL_ pré-configurado.
3. **Traces**: O ingress-nginx emite spans via OTLP → OpenTelemetry Collector → Tempo. A aplicação pode ser instrumentada opcionalmente para gerar spans filho.
4. **Alertas**: Alertmanager possui rotas para Slack (crítico, warning, SLO). Os alertas incluem links para runbooks e dashboards.

## Governança e operação

- **Pipelines**: `deploy-apps.yml` autentica via OIDC, valida variáveis obrigatórias e aplica o Helmfile. Um job opcional executa os cenários k6.
- **Runbooks**: Cada alerta possui URL apontando para [05-runbooks.md](./05-runbooks.md).
- **SLOs**: Definidos em [04-slos.md](./04-slos.md) com orçamentos de erro e janelas de observação.

Esse design prioriza alta disponibilidade e visibilidade ponta a ponta, mantendo complexidade aceitável para um time reduzido operar o ambiente.
