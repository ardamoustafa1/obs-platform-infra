#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

terraform -chdir="${repo_root}" fmt -recursive -check

for environment in dev staging prod; do
  terraform -chdir="${repo_root}/environments/${environment}" init -backend=false -input=false >/dev/null
  terraform -chdir="${repo_root}/environments/${environment}" validate
done

for values_file in "${repo_root}"/environments/*/values/*.yaml; do
  ruby -e 'require "yaml"; YAML.safe_load(File.read(ARGV.fetch(0)), permitted_classes: [], permitted_symbols: [], aliases: true)' "${values_file}"
done
