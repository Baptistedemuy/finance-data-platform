# Authenticates with the Azure CLI session (`az login`), in the tenant of the current account.
# Needs a directory role able to create groups (Groups Administrator or higher), see ADR-0004.
provider "azuread" {}
