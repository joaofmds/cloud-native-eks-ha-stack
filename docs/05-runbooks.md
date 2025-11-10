# 05 - Runbooks operacionais

Este repositório mantém runbooks sucintos para responder aos alertas críticos definidos nos SLOs da aplicação WhoAmI.

## Convenções

- Cada alerta inclui `annotations.runbook_url` apontando para uma âncora neste arquivo.
- Estrutura: **Sintoma → Diagnóstico → Mitigação → Prevenção**.
- Ferramentas de apoio: Grafana (dashboards e Explore), Loki, Tempo, kubectl e AWS Console.

<a id="whoami-slo-burn-rate"></a>

## WhoAmI - SLO burn rate

**Sintoma**
- Alerta `SLOErrorBudgetBurn` (severidade `critical`) indica que a taxa de erros HTTP está acima de 0.1% de forma sustentada.

**Diagnóstico**
1. Abra o dashboard _WhoAmI SLI_ e confirme o gráfico _Error Budget Burn_.
2. Utilize o _Explore → Loki_ com a consulta `{namespace="demo"} |= "ERROR"` para localizar mensagens de erro.
3. Acesse o Tempo e filtre por serviço `ingress-nginx` para identificar traces com status 5xx.
4. Cheque `kubectl get pods -n demo -owide` para confirmar se os pods estão distribuídos entre as zonas.

**Mitigação**
- Se houver `CrashLoopBackOff`, execute `kubectl describe pod` para identificar falhas de inicialização.
- Escale manualmente `kubectl scale deploy whoami -n demo --replicas=6` enquanto investiga a causa raiz.
- Caso o ingress apresente saturação, aumente o limite de CPU via `helmfile` (`apps/values/ingress-nginx.yaml`).

**Prevenção**
- Ajuste os `requests/limits` após o incidente.
- Considere habilitar _pod disruption budgets_ mais rígidos caso drenagens frequentes consumam o orçamento.
- Revise testes de carga em [06-tests-k6.md](./06-tests-k6.md) para cobrir novos cenários.

<a id="whoami-p99-latency"></a>

## WhoAmI - Latência P99 alta

**Sintoma**
- Alerta `HighLatencyP99` (severidade `warning`) com a anotação indicando latência > 500 ms por 5 minutos.

**Diagnóstico**
1. Verifique o painel de latência no Grafana para confirmar o aumento.
2. Clique no exemplar no gráfico para abrir o trace correspondente no Tempo.
3. Analise os spans: identifique se o tempo é gasto no ingress, upstream DNS ou no container.
4. Consulte o dashboard de nó (`Node Exporter`) para checar se há throttling de CPU (`container_cpu_cfs_throttled_seconds_total`).

**Mitigação**
- Aumente os `resources.limits` da aplicação se houver throttling.
- Se o gargalo estiver no backend, avalie replicar mais pods (`HPA` deve reagir; se não, revise métricas de target).
- Ajuste `nginx.ingress.kubernetes.io/proxy-read-timeout` se o backend legítimo precisar de mais tempo.

**Prevenção**
- Revise cenários de _stress test_ e _soak test_ para comparar com a linha base.
- Considere ativar cache no NGINX caso a resposta seja estática.
- Instrumente a aplicação com OpenTelemetry para obter spans detalhados e identificar camadas internas lentas.

Mantenha estes runbooks atualizados após cada incidente para garantir que alertas futuros tenham resolução cada vez mais rápida.
