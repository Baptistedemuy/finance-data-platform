# CLAUDE.md

Project conventions for AI-assisted development on this repository.

## Conventions
- Code, resource names, comments, commit messages and docs: English.
- Every structural decision is recorded as an ADR in `docs/adr/` (template: `0000-template.md`) before implementation.
- All Azure resources are created through Terraform (`infra/terraform/`); no manual changes outside documented exceptions.
- Databricks jobs and pipelines are deployed with Databricks Asset Bundles (`resources/`).
- Python 3.12 managed with `uv` (`.python-version`, `pyproject.toml`, `uv.lock`); run tools with `uv run`.
- Business logic lives in `src/finplatform/` and is unit-tested with pytest; notebooks are for exploration only.
- Cost first: every paid component is identified and estimated before deployment; least privilege for every identity.
- Never commit secrets, tenant/subscription IDs, personal data or `*.tfvars`.

## Local context
@private/CLAUDE.md
