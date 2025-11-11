# Cloud Native EKS High Availability Stack

Infraestrutura completa para disponibilizar uma aplicação web em Kubernetes (EKS) com foco em alta disponibilidade, observabilidade ponta a ponta e segurança operacional.

## Documentação principal

1. [01 - Guia de inicialização rápida](docs/01-getting-started.md)
2. [02 - Arquitetura, decisões e trade-offs](docs/02-architecture.md)
3. [03 - Observabilidade e acesso às ferramentas](docs/03-observability.md)
4. [04 - Metas de SLO e orçamentos de erro](docs/04-slos.md)
5. [05 - Runbooks operacionais](docs/05-runbooks.md)
6. [06 - Testes de performance com k6](docs/06-tests-k6.md)
7. [07 - Segurança e governança](docs/07-security.md)

## Componentes-chave

- **Infraestrutura**: Terraform modular (VPC, EKS multi-AZ, IRSA, S3 para Loki/Tempo, Route53/ACM/ACME) + pipelines GitHub Actions com OIDC.
- **Entrega**: Helmfile orquestrando `ingress-nginx`, `cert-manager`, `external-dns`, `kube-prometheus-stack`, `Loki`, `Tempo`, `OpenTelemetry Collector` e WhoAmI.
- **Segurança**: NetworkPolicies, Pod Security Admission (profile `restricted`), TLS automático (Let's Encrypt DNS-01) e roles IAM com privilégio mínimo.
- **Observabilidade**: métricas (Prometheus + Alertmanager), logs (Loki), traces (Tempo) e dashboards Grafana com exemplars → trace.
- **Alta disponibilidade**: node groups espalhados em 3 AZs, HPA, PDB, topology spread constraints, testes de falha e dreno documentados.
- **Notificações**: Alertmanager com rotas reais para Slack (`critical`, `warning`, `slo`) e runbooks versionados neste repositório.

## Fluxo resumido de deploy

1. **Provisionamento**: siga o [Guia de inicialização rápida](docs/01-getting-started.md) para preparar backend Terraform, aplicar os módulos (`infra/terraform/tfstate` → `infra/terraform/envs/dev`) e atualizar o kubeconfig.
2. **Configuração de variáveis**: copie `.env.template`, preencha com os outputs do Terraform e exporte. Registre os mesmos valores como _GitHub Secrets_ (veja tabela no guia).
3. **Aplicação**: execute `helmfile apply` em `apps/` e aplique as políticas adicionais em `security/`.
4. **Validação**: confira `kubectl get ingress`, acesse `https://whoami.$PUBLIC_HOSTED_ZONE`, abra Grafana (`https://grafana.$PUBLIC_HOSTED_ZONE`) e valide alertas/logs/traces.

## Observabilidade e resposta a incidentes

- SLOs definidos em [04-slos.md](docs/04-slos.md) são monitorados por Prometheus/Alertmanager.
- Alertas enviam notificações para Slack com links diretos para dashboards e [runbooks](docs/05-runbooks.md).
- Grafana utiliza exemplars para ligar métricas de latência/erro a traces do Tempo.
- Logs estruturados via Loki permitem correlação rápida (labels de namespace, pod, request-id).

## Testes de carga e alta disponibilidade

- Scripts `k6/` cobrem smoke, stress e soak. Os cenários recomendados estão em [06-tests-k6.md](docs/06-tests-k6.md).
- Durante os testes, simule falhas (drain de nó, queda de pod/ingress) para comprovar tolerância a falhas. Capture evidências para o relatório/vídeo.
