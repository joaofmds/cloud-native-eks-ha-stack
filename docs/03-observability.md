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

## Port-forward para Prometheus e Alertmanager

Prometheus:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Alertmanager:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

Após executar os comandos, acesse `http://localhost:9090` (Prometheus) e `http://localhost:9093` (Alertmanager).

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

* **Logs**: Utilize `Explore → Loki` para inspecionar os logs coletados via Promtail.
* **Traces**: Utilize `Explore → Tempo` e filtre por serviços que exportam via OTEL Collector.
* **Métricas**: Dashboards principais já incluídos pelo `kube-prometheus-stack` (Kubernetes / Nodes / API Server etc.).

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

Com esses passos é possível validar rapidamente a saúde da stack de observabilidade e dos componentes expostos.
