# 04 - Metas de SLO e orçamentos de erro

Os objetivos de nível de serviço (SLOs) definem o padrão mínimo aceitável para a aplicação de demonstração (`whoami`) e para o plano de controle. Eles orientam alertas, runbooks e priorização de incidentes.

## Resumo executivo

| Serviço | Indicador | Meta | Janela | Orçamento de erro |
|---------|-----------|------|--------|--------------------|
| WhoAmI | Taxa de sucesso HTTP via ingress | 99.9% | 30 dias móveis | 0.1% de requisições podem falhar |
| WhoAmI | Latência P99 no ingress | < 500 ms | 30 dias móveis | Até 30 min de violação por mês |
| Plano de controle | Disponibilidade do API Server | 99.95% | 30 dias móveis | 0.05% |

## Indicadores detalhados

### Disponibilidade (WhoAmI)
- **Fonte**: métricas `nginx_ingress_controller_requests` (status code)
- **Consulta**: `sum(increase(...status!~"5.."...)) / sum(increase(...))`
- **Motivo**: mede a experiência real do usuário final via ingress.
- **Alertas**: `SLOErrorBudgetBurn` (multi janela) dispara quando o consumo do orçamento é maior que 7x em 30 min e 14x em 5 min.

### Latência P99 (WhoAmI)
- **Fonte**: histograma `nginx_ingress_controller_request_duration_seconds_bucket`
- **Consulta**: `histogram_quantile(0.99, rate(...[5m]))`
- **Motivo**: garante que caudas de latência se mantenham dentro do objetivo do produto.
- **Alertas**: `HighLatencyP99` dispara após 5 minutos consecutivos acima de 500 ms.

### Plano de controle (API Server)
- **Fonte**: `apiserver_request_total` (exposto pelo kube-prometheus-stack)
- **Consulta**: `sum(rate(apiserver_request_total{code!~"5.."}[5m])) / sum(rate(apiserver_request_total[5m]))`
- **Motivo**: uma queda na disponibilidade do API Server afeta todas as workloads. O alerta correspondente está nos _default rules_.

## Integração com alertas e dashboards

- Os SLOs da aplicação são definidos como gravações em `apps/observability/prometheus-rules/slo-whoami.yaml`.
- Alertas incluem `labels.slo` e `annotations.runbook_url` apontando para [05-runbooks.md](./05-runbooks.md).
- O dashboard `WhoAmI SLI` (configmap aplicado via hook do Helmfile) mostra os indicadores com o mesmo cálculo dos _recording rules_.
- Exemplars conectam métricas → traces: clicar no ponto do gráfico no Grafana abre o trace no Tempo associado à requisição.

## Revisão e evolução

1. **Mensal**: revisar o consumo de orçamento e ajustar limites se necessário.
2. **Mudanças de arquitetura**: qualquer alteração no caminho de tráfego (ex.: trocar ingress) deve atualizar as consultas.
3. **Novas features**: adicionar SLIs específicos (ex.: payload size, tempo de resposta do backend) conforme o produto evolui.

Documentar SLOs torna explícito o nível de qualidade esperado e fundamenta decisões durante incidentes e planejamento de capacidade.
