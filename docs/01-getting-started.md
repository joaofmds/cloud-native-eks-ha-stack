# 01 - Guia de inicialização rápida

Este passo a passo consolida tudo o que é necessário para provisionar a infraestrutura, publicar os manifests e validar o ambiente em alta disponibilidade.

## 1. Pré-requisitos locais

| Ferramenta | Versão mínima | Observações |
|------------|----------------|-------------|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | 2.13 | Necessário para `aws eks update-kubeconfig` e autenticação. |
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | 1.5 | Utilizado nos módulos em `infra/terraform`. |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | 1.28 | Compatível com a versão do EKS gerenciado. |
| [Helm](https://helm.sh/docs/intro/install/) | 3.12 | Requerido para os charts descritos pelo Helmfile. |
| [Helmfile](https://github.com/helmfile/helmfile) | 0.150 | Orquestra as releases em `apps/helmfile.yaml`. |
| [k6](https://k6.io/docs/get-started/installation/) | 0.47 | Executa os cenários de carga em `k6/`. |

> Dica: o diretório `Makefile` contém alvos (`make infra-plan`, `make apps-diff`, `make k6-stress`) que encadeiam esses binários.

## 2. Organização do repositório

```
├── infra/terraform        # Módulos de VPC, EKS, IAM, S3, Route53
├── apps/                  # Helmfile + values (ingress, observabilidade, aplicações)
├── security/              # NetworkPolicies, Pod Security Admission, HPA/PDB
├── k6/                    # Cenários smoke/stress/soak
└── docs/                  # Referências operacionais (você está aqui!)
```

Os diretórios seguem a ordem de execução: Terraform → Helmfile → segurança adicional (kubectl apply) → k6.

## 3. Variáveis e segredos

1. Copie o template de ambiente e preencha com os _outputs_ do Terraform:
   ```bash
   cp .env.template .env
   # preencha os valores e depois exporte
   source .env
   ```
2. Os mesmos nomes devem ser cadastrados como **GitHub Secrets** para a pipeline `deploy-apps.yml`:

| Variável | Descrição | Origem |
|----------|-----------|--------|
| `AWS_EKS_CLUSTER_NAME` | Nome do cluster EKS | `terraform output cluster_name` |
| `AWS_OIDC_ROLE_ARN` | Role assumida pela pipeline | IAM / Terraform `oidc_role_arn` |
| `PUBLIC_HOSTED_ZONE` | Domínio público (ex.: `example.com`) | Route53 ou provedor escolhido |
| `PUBLIC_HOSTED_ZONE_ID` | Zone ID associado ao domínio | Route53 |
| `ACME_EMAIL` | E-mail utilizado pelo Let's Encrypt | Política de segurança |
| `CERT_MANAGER_IAM_ROLE_ARN` | Role IRSA do cert-manager (DNS-01) | `terraform output cert_manager_role_arn` |
| `EXTERNAL_DNS_IAM_ROLE_ARN` | Role IRSA do external-dns | `terraform output external_dns_role_arn` |
| `LOKI_IAM_ROLE_ARN` | Role IRSA do Loki (S3) | `terraform output loki_role_arn` |
| `TEMPO_IAM_ROLE_ARN` | Role IRSA do Tempo (S3) | `terraform output tempo_role_arn` |
| `GRAFANA_IAM_ROLE_ARN` | Role IRSA do Grafana (CloudWatch/Loki opcional) | `terraform output grafana_role_arn` |
| `LOKI_S3_BUCKET` | Bucket S3 para objetos Loki | `terraform output loki_bucket_name` |
| `TEMPO_S3_BUCKET` | Bucket S3 para traces Tempo | `terraform output tempo_bucket_name` |
| `GRAFANA_ADMIN_PASSWORD` | Senha administrativa do Grafana | Definida manualmente |
| `SLACK_WEBHOOK_URL` | Webhook usado pelo Alertmanager | Administrador do Slack |

> Todos esses valores são consumidos pelo Helmfile através de `requiredEnv`. Sem eles o deploy falha imediatamente (veja a seção 6).

## 4. Provisionamento da infraestrutura

1. **Backend do estado Terraform** (`infra/terraform/tfstate`)
   ```bash
   cd infra/terraform/tfstate
   terraform init
   terraform apply -var-file=dev.tfvars
   ```
2. **Recursos de ambiente** (`infra/terraform/envs/dev`)
   ```bash
   cd infra/terraform/envs/dev
   terraform init
   terraform plan -var-file=dev.tfvars
   terraform apply -var-file=dev.tfvars
   ```
3. **Atualize o kubeconfig**
   ```bash
   aws eks update-kubeconfig --name <cluster> --region <aws_region>
   kubectl get nodes
   ```

## 5. Deploy das aplicações

1. Carregue as variáveis exportadas anteriormente (`source .env`).
2. Execute o Helmfile:
   ```bash
   cd apps
   helmfile apply
   ```
3. Aplique as políticas adicionais:
   ```bash
   kubectl apply -f security/namespaces
   kubectl apply -f security/policies
   ```

A ordem garante que o ingress-nginx esteja disponível antes do cert-manager/external-dns, que por sua vez liberam TLS e DNS para Grafana e WhoAmI.

## 6. Validações pós-deploy

- **Pods saudáveis**:
  ```bash
  kubectl get pods -A
  ```
- **Ingress + certificado**:
  ```bash
  kubectl get ingress -n demo
  kubectl describe certificate whoami-tls -n demo
  ```
- **DNS**: confirme que o `A record` foi criado no provedor.
- **HTTPS**: acesse `https://whoami.$PUBLIC_HOSTED_ZONE` e verifique qual pod respondeu.
- **Observabilidade**: visite o dashboard _WhoAmI SLI_ no Grafana e confira logs no Loki / traces no Tempo.

## 7. Testes de carga e alta disponibilidade

1. Execute `k6` conforme descrito em [06-tests-k6.md](./06-tests-k6.md).
2. Simule falha de zona / dreno de nó:
   ```bash
   kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
   kubectl get pods -n demo -owide
   ```
3. Mate propositalmente um pod do ingress e do whoami para observar o `HPA` e o `PDB` reagindo:
   ```bash
   kubectl delete pod -n ingress-nginx -l app.kubernetes.io/component=controller
   kubectl delete pod -n demo -l app.kubernetes.io/name=whoami
   ```
4. Acompanhe métricas e alertas durante os testes. Use os links rápidos do dashboard para abrir logs (Loki) e traces (Tempo).

## 8. DNS gratuito e alternativas de validação de certificado

- **Freenom / ClouDNS**: ambos permitem criar um domínio gratuito apontando para registros A/AAAA e TXT. Configure o `Hosted Zone ID` fornecido por eles nos secrets `PUBLIC_HOSTED_ZONE` e `PUBLIC_HOSTED_ZONE_ID`.
- **Validação HTTP-01**: caso não possua acesso a um provedor DNS com API, altere `values/cluster-issuer.yaml` para usar HTTP-01 e crie manualmente um record CNAME apontando para o ingress.
- **Ambiente local (Minikube/K3s)**: troque o módulo Terraform por `infra/local/` (em construção) e utilize `mkcert` para gerar certificados locais.

Com esses passos você terá o mesmo fluxo executado na demonstração em vídeo: infraestrutura como código, aplicação publicada com TLS e stack de observabilidade ligada a alertas e runbooks.
