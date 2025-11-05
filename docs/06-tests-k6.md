# Testes de performance com k6

Este guia explica como executar as suítes de smoke, stress e soak disponíveis no diretório `k6/`, analisar as métricas geradas pelo k6 e correlacioná-las com os sinais de observabilidade da stack.

## Pré-requisitos

- [k6](https://k6.io/docs/get-started/installation/) instalado localmente ou uso do `grafana/setup-k6-action` nas pipelines.
- Variáveis de ambiente que apontem para o endpoint da aplicação (por exemplo `BASE_URL`) referenciadas pelos scripts JavaScript em `k6/`.
- Acesso à stack de observabilidade descrita em [03-observability.md](./03-observability.md) para consultar métricas, logs e traces.

## Executando os testes

Os scripts seguem a convenção abaixo:

- `k6/smoke.js`: verificação rápida pós-deploy (baixa carga, duração curta).
- `k6/stress.js`: validação de escala horizontal/vertical simulando aumentos agressivos de carga.
- `k6/soak.js`: carga sustentada durante várias horas para detectar vazamentos de recursos ou degradações graduais.

### Usando o Makefile

O `Makefile` traz alvos para facilitar a repetição dos cenários:

```bash
# Planejar infraestrutura antes de aplicar mudanças
make infra-plan TF_ENV=dev TF_PLAN_FLAGS="-var-file=dev.auto.tfvars"

# Aplicar manifests com Helmfile no cluster configurado
make apps-apply HELMFILE_ENV=dev

# Rodar o cenário de stress (altere K6_SCRIPT para smoke/soak)
make k6-stress K6_SCRIPT=k6/stress.js K6_FLAGS="-e BASE_URL=https://api.dev.example.com"
```

### Execução direta com k6

Para executar manualmente, utilize:

```bash
# Smoke test (~1-5 minutos)
k6 run -e BASE_URL=https://api.dev.example.com k6/smoke.js

# Stress test com ramp-up progressivo
k6 run -e BASE_URL=https://api.dev.example.com k6/stress.js

# Soak test (defina duração na opção --duration)
k6 run -e BASE_URL=https://api.dev.example.com --duration 4h k6/soak.js
```

Ajuste `BASE_URL`, headers e variáveis extras conforme os cenários implementados nos scripts.

## Interpretando métricas do k6

O relatório do k6 apresenta estatísticas agregadas que ajudam a validar SLOs:

- `http_req_duration`: tempo total da requisição (ideal para comparar com latência P95/P99 exposta em Prometheus).
- `http_req_failed`: percentual de falhas; deve permanecer próximo de zero em smoke tests e dentro do erro tolerado em stress/soak.
- `vus` e `vus_max`: número de usuários virtuais ativos; confirme se o cluster escala adequadamente durante o stress test.
- Métricas customizadas via `Trend`, `Counter`, `Gauge` e `Rate` nos scripts podem acompanhar KPIs específicos (ex.: tempo de processamento de filas, taxa de erros de negócio).

Exportar os resultados como JSON (`k6 run --out json=./artifacts/result.json ...`) possibilita comparar execuções históricas ou alimentar dashboards.

## Correlação com observabilidade

Enquanto o teste roda, correlacione os pontos de medição:

1. **Métricas**: utilize Prometheus/Grafana para verificar consumo de CPU/Memória, saturação de HPA e latência dos serviços descritos em [03-observability.md](./03-observability.md).
2. **Logs**: valide se o Loki/ELK recebe eventos esperados e se há aumento de erros de aplicação durante os picos simulados.
3. **Traces**: investigue spans lentos no Jaeger/Tempo (ou a ferramenta configurada) para localizar gargalos gerados pela carga do k6.

Documente as correlações relevantes e mantenha limites de alertas alinhados aos valores observados durante os testes. Isso garante que novas execuções de smoke/stress/soak validem continuamente a resiliência do ambiente.
