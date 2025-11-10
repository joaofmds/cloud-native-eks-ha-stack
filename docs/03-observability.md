# Observabilidade e Acesso às Ferramentas

Este documento resume como interagir com a stack de observabilidade implantada via Helmfile.

## Pré-requisitos

* `kubectl` configurado para o cluster EKS alvo (`aws eks update-kubeconfig --name <cluster>`).
* Variáveis de ambiente utilizadas pelo `helmfile` exportadas (por exemplo, `PUBLIC_HOSTED_ZONE`, `AWS_REGION`, `GRAFANA_ADMIN_PASSWORD`).
* Acesso aos perfis IAM associados às ServiceAccounts (IRSA) já provisionados via Terraform/IAM.

## Aplicando o Helmfile

```bash
cd apps
helmfile sync
```

O `helmfile` aplica as releases na seguinte ordem para garantir dependências resolvidas: `ingress-nginx` → `cert-manager` → `external-dns` → `kube-prometheus-stack` → `loki`/`promtail` → `tempo`/`otel-collector` → `whoami`.

## Verificando o estado dos pods

```bash
kubectl get pods -n monitoring
kubectl get pods -n cert-manager
kubectl get pods -n demo
```

## Port-forward e endpoints

- **Prometheus** (caso não queira expor via port-forward):
  ```bash
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
  ```
- **Alertmanager**:
  ```bash
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
  ```
- **Tempo** (para consultas diretas OTLP/HTTP):
  ```bash
  kubectl port-forward -n monitoring svc/tempo-query-frontend 16686:16686
  ```

O Alertmanager já está configurado com rotas para Slack (`#alerts-critical`, `#alerts-warning`, `#alerts-slo`). Defina `SLACK_WEBHOOK_URL` antes do deploy para habilitar o envio real.

## Acesso ao Grafana

O Grafana é exposto via Ingress (`https://grafana.$PUBLIC_HOSTED_ZONE`). Se o DNS ainda não estiver propagado, é possível usar um `port-forward` temporário:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Credenciais padrão definidas no Helmfile:

* Usuário: `admin`
* Senha: valor da variável de ambiente `GRAFANA_ADMIN_PASSWORD`

Após o login, as fontes de dados Loki e Tempo já estarão configuradas automaticamente.

## Dashboards e Exploração

* **Métricas**: dashboards principais já incluídos pelo `kube-prometheus-stack` (Kubernetes / Nodes / API Server etc.). O painel _WhoAmI SLI_ possui links diretos para logs/traces através de exemplars.
* **Logs**: utilize `Explore → Loki` para inspecionar eventos. Use os botões *View logs* presentes nos gráficos do dashboard para abrir a consulta já filtrada.
* **Traces**: utilize `Explore → Tempo` e filtre por serviço `ingress-nginx`. O traço raiz é emitido pelo ingress via OpenTelemetry; downstreams podem anexar spans se estiverem instrumentados.
* **Alertas**: acesse `https://grafana.$PUBLIC_HOSTED_ZONE/alerting` ou o próprio Alertmanager para visualizar histórico. Cada alerta inclui link para o runbook e dashboard relacionado.

> Exemplars foram habilitados no Prometheus. Ao clicar em um ponto do gráfico de latência ou erro, o Grafana abre automaticamente o trace associado no Tempo.

## Troubleshooting rápido

* Certifique-se de que o `ClusterIssuer` `letsencrypt-prod` está `READY`:
  ```bash
  kubectl describe clusterissuer letsencrypt-prod
  ```
* Verifique se o HPA do `whoami` está coletando métricas:
  ```bash
  kubectl get hpa -n demo whoami
  ```
* Cheque as políticas de rede aplicadas no namespace `demo`:
  ```bash
  kubectl describe networkpolicy -n demo whoami-restricted
  ```
* Consultar status dos webhooks Slack:
  ```bash
  kubectl get secret -n monitoring alertmanager-kube-prometheus-stack-alertmanager -o yaml | grep SLACK
  ```

Se o alerta não chegar ao Slack, valide o webhook e o acesso de saída do namespace `monitoring` (NetworkPolicy).

Com esses passos é possível validar rapidamente a saúde da stack de observabilidade e dos componentes expostos.
