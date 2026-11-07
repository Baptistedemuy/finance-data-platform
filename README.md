# Finance Data Platform

End-to-end data platform on **Azure + Databricks** for public financial data (market prices, macro indicators, news), with an AI sentiment layer.
Built with production-grade practices — Infrastructure as Code, CI/CD, governance, least privilege — at minimal cost.

> 🚧 Work in progress. Key design decisions are documented as [Architecture Decision Records](docs/adr/).

## Tech stack

| Area | Technologies |
|---|---|
| Cloud & storage | Azure (Switzerland North), ADLS Gen2, Delta Lake — medallion architecture |
| Compute | Azure Databricks, PySpark, SQL, Lakeflow Declarative Pipelines |
| Ingestion | Batch jobs, Auto Loader (incremental), streaming use case |
| Governance | Unity Catalog, data contracts (YAML), data quality expectations, lineage |
| Security | Microsoft Entra ID, Azure RBAC, managed identities, Key Vault, Azure Policy |
| DataOps | Terraform, Databricks Asset Bundles, GitHub Actions (OIDC), pytest, uv |
| Consumption | Gold star schema, Databricks SQL dashboards |
| AI | News sentiment analysis |

## Roadmap

- [x] **Foundations** — subscription guardrails (budgets, spending limit), region & compute decisions ([ADR-0001](docs/adr/0001-compute-platform-azure-databricks.md), [ADR-0002](docs/adr/0002-azure-region-switzerland-north.md))
- [ ] **Platform & identity** — Terraform remote state, ADLS Gen2, Key Vault, Entra ID groups, Azure Policy, Databricks workspace, Unity Catalog
- [ ] **Bronze ingestion** — public financial APIs → landing zone → Auto Loader
- [ ] **Silver / gold** — Lakeflow pipelines, MERGE / SCD2, liquid clustering
- [ ] **Governance** — data contracts, expectations, lineage
- [ ] **Metadata-driven framework** — new source = one contract file
- [ ] **DataOps** — Asset Bundles, CI/CD, tests, monitoring
- [ ] **Streaming** use case
- [ ] **Consumption** — dimensional model, dashboards
- [ ] **AI** — news sentiment

## Architecture

_Diagram coming with the platform phase._

## Repository layout

```
.
├── infra/terraform/      # Infrastructure as Code (modules + envs)
├── resources/            # Databricks Asset Bundle resources (jobs, pipelines)
├── pipelines/            # Lakeflow pipeline definitions
├── contracts/            # Data contracts (YAML) — drive metadata-driven pipelines
├── src/finplatform/      # Python package
│   ├── common/           #   config, logging, Spark helpers
│   ├── ingestion/        #   batch, Auto Loader, streaming
│   ├── transformations/  #   bronze → silver → gold
│   └── quality/          #   expectations & data quality checks
├── notebooks/            # Exploration only (no production logic)
├── tests/                # pytest (unit + integration)
├── scripts/              # Local helper scripts
├── docs/
│   ├── adr/              # Architecture Decision Records
│   └── architecture/     # Diagrams
└── .github/workflows/    # CI/CD
```

## License

[MIT](LICENSE)
