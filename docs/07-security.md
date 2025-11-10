# 07 - Segurança e governança

Esta seção detalha como os controles de segurança foram implementados e como expandi-los.

## Infraestrutura

- **IRSA (IAM Roles for Service Accounts)**: cada componente que precisa de recursos AWS possui uma role dedicada criada via Terraform:
  - `external-dns`: política limitada a alterações apenas na zona pública informada.
  - `cert-manager`: acesso somente às ações `route53:ChangeResourceRecordSets` necessárias para desafios DNS-01.
  - `loki` e `tempo`: permissões `s3:PutObject`, `s3:GetObject`, `s3:ListBucket` apenas para os buckets definidos (`LOKI_S3_BUCKET`, `TEMPO_S3_BUCKET`).
  - `grafana`: leitura opcional em serviços (CloudWatch, S3) se habilitado.
- **Network design**: nodes em subnets privadas sem IP público; saída controlada via NAT Gateway.
- **Security Groups**: regras mínimas necessárias para o NLB e para comunicação interna do cluster.

## Kubernetes

- **Namespaces dedicados** (`security/namespaces`): separa demo, observabilidade, ingress e workloads de sistema.
- **Pod Security Admission** (`security/policies/pod-security-standards.yaml`): aplica o perfil `restricted` com exceções pontuais.
- **NetworkPolicies** (`security/policies/network-policies.yaml`): permitem apenas tráfego necessário (ingress ↔ demo, observabilidade ↔ cluster). A matriz de comunicação mínima está descrita abaixo.

| Origem | Destino | Motivo |
|--------|---------|--------|
| `ingress-nginx` | `demo` | Encaminhamento HTTP/HTTPS para a aplicação WhoAmI |
| `demo` | `monitoring` | Exportar métricas/OTLP para o collector |
| `monitoring` | `monitoring` | Comunicação interna Prometheus ↔ Alertmanager ↔ Loki ↔ Tempo |
| `kube-system` | `monitoring` | Scrapes de componentes do cluster |

- **Secrets**: parâmetros sensíveis como `GRAFANA_ADMIN_PASSWORD` e `SLACK_WEBHOOK_URL` são injetados via variáveis de ambiente/Secrets gerenciados pelo GitHub Actions OIDC. Para produção recomenda-se `SealedSecrets` ou `SOPS`.
- **TLS**: ingress-nginx reforçado com HSTS, TLS mínimo 1.2 e Cipher Suite moderna (config em `apps/values/ingress-nginx.yaml`). Certificados automáticos via cert-manager.

## Pipeline CI/CD

- **GitHub Actions OIDC**: nenhuma chave estática armazenada; a role `AWS_OIDC_ROLE_ARN` tem _session duration_ reduzida e permissões mínimas.
- **Validação de variáveis**: o workflow `deploy-apps.yml` falha rapidamente se algum segredo obrigatório estiver ausente.
- **Artefatos de teste**: resultados do k6 são publicados para auditoria (ver seção [06-tests-k6.md](./06-tests-k6.md)).

## Recomendações futuras

- Habilitar _image scanning_ via ECR ou Trivy integrado à pipeline.
- Adicionar políticas `Kyverno` ou `OPA Gatekeeper` para reforçar padrões (labels, recursos, securityContext).
- Ativar _audit logging_ do EKS para envio ao CloudWatch e integração com SIEM.

Esses controles garantem conformidade básica e reduzem o impacto de incidentes, mantendo o foco em disponibilidade e visibilidade.
