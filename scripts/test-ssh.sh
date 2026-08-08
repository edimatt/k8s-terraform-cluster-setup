#!/usr/bin/env bash

set -Eeuo pipefail

terraform_bin="${TERRAFORM:-terraform}"
ssh_key="${SSH_KEY:-${HOME}/.ssh/eagle_ed25519}"
ssh_port="${SSH_PORT:-22}"
ssh_attempts="${SSH_ATTEMPTS:-24}"
ssh_retry_interval="${SSH_RETRY_INTERVAL:-5}"

for command in "${terraform_bin}" jq ssh ssh-keygen; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command not found: ${command}" >&2
    exit 1
  fi
done

if [[ ! -f "${ssh_key}" ]]; then
  echo "SSH private key not found: ${ssh_key}" >&2
  echo "Set SSH_KEY to the private key installed on the VMs." >&2
  exit 1
fi

if [[ ! "${ssh_attempts}" =~ ^[1-9][0-9]*$ ]]; then
  echo "SSH_ATTEMPTS must be a positive integer." >&2
  exit 1
fi

if [[ ! "${ssh_port}" =~ ^[0-9]+$ ]] || ((ssh_port < 1 || ssh_port > 65535)); then
  echo "SSH_PORT must be an integer between 1 and 65535." >&2
  exit 1
fi

if [[ ! "${ssh_retry_interval}" =~ ^[0-9]+$ ]]; then
  echo "SSH_RETRY_INTERVAL must be a non-negative integer." >&2
  exit 1
fi

nodes_json=$("${terraform_bin}" output -json nodes)
nodes_tsv=$(jq -er '
  if type == "object" and length > 0 then
    to_entries[] | [.value.name, .value.ip_address] | @tsv
  else
    error("Terraform output nodes is empty or invalid")
  end
' <<<"${nodes_json}")

ssh_user="${SSH_USER:-}"
if [[ -z "${ssh_user}" ]]; then
  inventory=$("${terraform_bin}" output -raw ansible_inventory)
  while IFS= read -r line; do
    if [[ "${line}" == ansible_user=* ]]; then
      ssh_user="${line#ansible_user=}"
      break
    fi
  done <<<"${inventory}"
fi

if [[ -z "${ssh_user}" ]]; then
  echo "Could not determine the SSH user from Terraform output." >&2
  echo "Set SSH_USER explicitly and try again." >&2
  exit 1
fi

failed=0
while IFS=$'\t' read -r node ip; do
  if [[ -z "${node}" || -z "${ip}" ]]; then
    echo "Terraform returned an invalid node entry." >&2
    exit 1
  fi

  echo "Testing ${node} at ${ip}"

  known_hosts_target="${ip}"
  if ((ssh_port != 22)); then
    known_hosts_target="[${ip}]:${ssh_port}"
  fi

  if ssh-keygen -F "${known_hosts_target}" >/dev/null 2>&1; then
    ssh-keygen -R "${known_hosts_target}" >/dev/null
    echo "Removed the existing host key for ${known_hosts_target}"
  fi

  connected=0
  for ((attempt = 1; attempt <= ssh_attempts; attempt++)); do
    if ssh -n \
      -i "${ssh_key}" \
      -p "${ssh_port}" \
      -o IdentitiesOnly=yes \
      -o BatchMode=yes \
      -o ConnectTimeout=5 \
      -o StrictHostKeyChecking=accept-new \
      "${ssh_user}@${ip}" \
      'printf "SSH connection successful on %s\n" "$(hostname)"'; then
      connected=1
      break
    fi

    if ((attempt < ssh_attempts)); then
      echo "SSH not ready on ${node} (attempt ${attempt}/${ssh_attempts}); retrying in ${ssh_retry_interval}s..."
      sleep "${ssh_retry_interval}"
    fi
  done

  if ((connected == 0)); then
    echo "SSH connection failed on ${node} after ${ssh_attempts} attempts." >&2
    failed=1
  fi
done <<<"${nodes_tsv}"

if ((failed != 0)); then
  exit 1
fi

echo "SSH connection succeeded for every Terraform-managed node."
