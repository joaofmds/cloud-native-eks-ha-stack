# Cloud Native EKS High Availability Stack

Stack completa de infraestrutura cloud-native na AWS com foco em alta disponibilidade, observabilidade e segurança.

## 🏗️ Arquitetura

### Componentes Principais

- **EKS (Kubernetes)**: Cluster gerenciado com 3 node groups distribuídos em 3 AZs
- **Observabilidade**: Stack completa com Prometheus, Grafana, Loki e Tempo
- **Segurança**: TLS automático (Let's Encrypt), Network Policies, Pod Security Standards
- **Alta Disponibilidade**: HPA, PDB, multi-AZ deployment

### Infraestrutura

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
├─────────────────────────────────────────────────────────────┤
│  VPC (10.20.0.0/16)                                         │
│  ├── 3 Public Subnets (us-east-1a/b/c)                     │
│  ├── 3 Private Subnets (us-east-1a/b/c)                    │
│  ├── NAT Gateway (HA)                                        │
│  └── VPC Endpoints (ECR, SSM, Logs, etc)                   │
│                                                              │
│  EKS Cluster (dev-eks)                                      │
│  ├── Control Plane (Managed)                                │
│  └── Node Groups                                            │
│      ├── general (t3.large, 3 nodes, ON_DEMAND)            │
│      └── spot (t3.medium/large, 2 nodes, SPOT)             │
│                                                              │
│  Ingress & DNS                                              │
│  ├── NGINX Ingress Controller                               │
│  ├── External DNS (Route53)                                 │
│  └── Cert Manager (Let's Encrypt)                           │
│                                                              │
│  Observability Stack                                         │
│  ├── Prometheus + Alertmanager                              │
│  ├── Grafana (dashboards)                                   │
│  ├── Loki (logs - S3 backend)                              │
│  └── Tempo (traces - S3 backend)                            │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Pré-requisitos

### Ferramentas

- AWS CLI v2+
- Terraform v1.5+
- kubectl v1.28+
- Helm v3.12+
- Helmfile v0.150+
- k6 (testes de carga)

### Credenciais AWS

```bash
aws configure
# ou
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."  # se usar SSO
```

### Domínio

Você precisa de um domínio público. Configure no Route53 ou use um provedor gratuito como cloudns.net.

## 🚀 Deploy

### 1. Backend do Terraform (State)

```bash
cd infra/terraform/tfstate
terraform init
terraform apply \
  -var="environment=dev" \
  -var="project_name=cloud-native-eks-ha-stack" \
  -var="owner=platform-team" \
  -var="application=tfstate" \
  -var="region=us-east-1"
```

### 2. Infraestrutura (VPC, EKS, IAM)

```bash
cd infra/terraform/envs/dev

# Configure backend
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "bry-project-tfstate-dev"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "bry-project-tfstate-lock-dev"
  }
}
EOF

# Initialize e aplique
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl

```bash
aws eks update-kubeconfig --name dev-eks --region us-east-1

# Verifique conectividade
kubectl get nodes
```

### 4. Exporte variáveis de ambiente

```bash
# Copie o template
cp .env.template .env

# Preencha com outputs do Terraform
cd infra/terraform/envs/dev
terraform output

# Edite .env com os valores
vim ../../.env

# Carregue as variáveis
source .env
```

### 5. Deploy das aplicações (Helmfile)

```bash
cd apps

# Valide
helmfile diff

# Aplique
helmfile sync
```

### 6. Verifique o deploy

```bash
# Todos os pods devem estar Running
kubectl get pods -A

# Verifique o Ingress
kubectl get ingress -A

# Acesse a aplicação
curl https://whoami.joaofmsouza.com.br
```

## 🔒 Segurança

### Implementações

1. **Network Policies**: Isolamento de tráfego entre namespaces
2. **Pod Security Standards**: Restricted mode para workloads
3. **TLS/SSL**: Certificados automáticos via Let's Encrypt
4. **IRSA**: IAM Roles para Service Accounts (zero credentials no código)
5. **Security Groups**: Controle granular de tráfego
6. **Private Subnets**: Nodes sem IP público
7. **VPC Endpoints**: Comunicação privada com serviços AWS
8. **Secrets Encryption**: KMS para secrets do Kubernetes

### Security Groups

- **Control Plane**: Apenas acesso dos nodes
- **Nodes**: Acesso restrito à VPC e internet via NAT
- **Load Balancer**: Público (HTTP/HTTPS)

## 📊 Observabilidade

### Dashboards Grafana

Acesse: `https://grafana.joaofmsouza.com.br` (após deploy)

- **Whoami SLI**: Latência, error rate, throughput
- **Node Exporter**: Métricas de infraestrutura
- **Kubernetes Cluster**: Visão geral do cluster

### Logs (Loki)

```bash
# Via Grafana Explore
# Filtrar por namespace
{namespace="demo"} |= "error"
```

### Traces (Tempo)

Habilitado via OpenTelemetry Collector (configuração em `apps/values/otel-collector.yaml`)

### Alertas

Configurados via PrometheusRules em `apps/observability/prometheus-rules/slo-whoami.yaml`:

- **HighErrorRate**: Error rate > 5%
- **HighLatency**: P95 > 500ms
- **LowAvailability**: Availability < 99%

## 🧪 Testes de Estresse

### Smoke Test (validação rápida)

```bash
k6 run k6/smoke.js -e BASE_URL=https://whoami.joaofmsouza.com.br
```

### Stress Test (carga pesada)

```bash
k6 run k6/stress.js -e BASE_URL=https://whoami.joaofmsouza.com.br
```

### Soak Test (longa duração)

```bash
k6 run k6/soak.js -e BASE_URL=https://whoami.joaofmsouza.com.br
```

### Resultados Esperados

Durante os testes, observe no Grafana:

- **HPA** escalando pods automaticamente
- **Métricas** de latência e throughput
- **Logs** sendo ingeridos no Loki
- **Alertas** disparando se thresholds forem ultrapassados

## 🔧 Troubleshooting

### Nodes não se juntam ao cluster

```bash
# Verifique o status
aws eks describe-nodegroup --cluster-name dev-eks --nodegroup-name general

# Logs do kubelet (via SSM)
aws ssm start-session --target INSTANCE_ID
sudo journalctl -u kubelet -n 100
```

### CoreDNS em DEGRADED

CoreDNS precisa de nodes para funcionar. Aguarde os nodes ficarem Ready:

```bash
kubectl get nodes
kubectl get pods -n kube-system | grep coredns
```

### Certificado SSL não provisiona

```bash
# Verifique cert-manager
kubectl get certificates -A
kubectl describe certificate whoami-tls -n demo

# Logs do cert-manager
kubectl logs -n cert-manager deployment/cert-manager -f
```

### Aplicação não responde

```bash
# Verifique pods
kubectl get pods -n demo
kubectl describe pod <pod-name> -n demo

# Verifique ingress
kubectl get ingress -n demo
kubectl describe ingress whoami -n demo

# Verifique DNS
nslookup whoami.joaofmsouza.com.br
```

## 📁 Estrutura do Projeto

```
.
├── apps/                       # Aplicações Kubernetes
│   ├── charts/                 # Helm charts customizados
│   ├── observability/          # Configurações de observabilidade
│   ├── values/                 # Values dos charts
│   └── helmfile.yaml           # Orquestração do deploy
├── infra/terraform/            # Infraestrutura como código
│   ├── envs/dev/               # Ambiente de dev
│   ├── modules/                # Módulos reutilizáveis
│   └── tfstate/                # Backend do state
├── k6/                         # Testes de carga
├── security/                   # Políticas de segurança
└── docs/                       # Documentação adicional
```

## 🎯 Decisões de Arquitetura

### Por que EKS Managed?

- **Simplicidade**: Control plane gerenciado pela AWS
- **Segurança**: Patches automáticos
- **Integração**: Nativo com serviços AWS (IAM, VPC, etc)

### Por que 3 AZs?

- **Alta disponibilidade**: Tolerância a falhas de zona
- **Distribuição**: Workloads distribuídos geograficamente

### Por que Spot + On-Demand?

- **Custo**: Spot instances economizam até 90%
- **Disponibilidade**: On-Demand para workloads críticos

### Por que Loki + Tempo em S3?

- **Custo**: S3 é muito mais barato que EBS
- **Durabilidade**: 99.999999999% de durabilidade
- **Escalabilidade**: Sem limites de storage

## 📚 Documentação Adicional

- [Observabilidade](docs/03-observability.md)
- [Testes K6](docs/06-tests-k6.md)

## 🤝 Contribuindo

Este projeto é parte de um desafio técnico. Feedback e sugestões são bem-vindos!

## 📝 Licença

MIT

## 👤 Autor

João Felipe - Platform Engineer
