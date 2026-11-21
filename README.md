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
- [ ] **Platform & identity** — in progress
  - [x] Terraform remote state, Entra ID only ([ADR-0003](docs/adr/0003-terraform-remote-state.md))
  - [x] Entra ID groups as code ([ADR-0004](docs/adr/0004-identity-entra-id-groups.md))
  - [x] Dev ADLS Gen2 lake + Key Vault, rights per group ([ADR-0005](docs/adr/0005-dev-data-lake-and-key-vault.md))
  - [x] Ephemeral Databricks workspace, Premium, no NAT Gateway fixed cost ([ADR-0006](docs/adr/0006-dev-databricks-workspace.md))
  - [x] Cost guardrail: single-node cluster policy; compute in Sweden Central, data in Switzerland North ([ADR-0007](docs/adr/0007-dev-compute-region-sweden-central.md))
  - [x] Unity Catalog storage access: managed-identity access connector, storage credential, external locations ([ADR-0008](docs/adr/0008-unity-catalog-storage-access-and-lifecycles.md))
  - [ ] Unity Catalog catalog / schemas / grants, VS Code end-to-end access, Azure Policy
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
├── infra/terraform/      # Infrastructure as Code, one root module per lifecycle
│   ├── bootstrap/        #   remote state backend (applied once)
│   ├── identity/         #   Entra ID groups
│   ├── envs/dev/         #   dev data lake + Key Vault + UC access connector (persistent)
│   ├── envs/dev-catalog/ #   Unity Catalog objects on the dev lake (persistent)
│   ├── envs/dev-workspace/ # dev Databricks workspace (ephemeral)
│   └── modules/          #   reusable modules
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
