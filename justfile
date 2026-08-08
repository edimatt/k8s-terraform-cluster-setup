set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

terraform := env_var_or_default("TERRAFORM", "terraform")
plan_file := "k8s-lab.tfplan"
inventory_file := "hosts.ini"

default: help

# Show the minimal workflow and all available recipes.
help:
    @echo "Minimal workflow:"
    @echo "  just setup       # Create terraform.tfvars once"
    @echo "  just check       # Format-check, validate, and test"
    @echo "  just plan        # Create a saved Terraform plan"
    @echo "  just show-plan   # Review the saved plan"
    @echo "  just apply       # Apply exactly that plan"
    @echo "  just ssh-test    # Wait for and verify SSH on every node"
    @echo "  just inventory   # Export hosts.ini"
    @echo
    @just --list

# Create the local configuration without overwriting an existing one.
setup:
    @if [[ -f terraform.tfvars ]]; then \
        echo "terraform.tfvars already exists"; \
    else \
        cp terraform.tfvars.example terraform.tfvars; \
        echo "Created terraform.tfvars; review it before planning"; \
    fi

# Initialize the local Terraform working directory.
init:
    {{ terraform }} init

# Update providers within the constraints in versions.tf.
init-upgrade:
    {{ terraform }} init -upgrade

# Format Terraform sources.
fmt:
    {{ terraform }} fmt -recursive

# Run the same checks as CI.
check:
    {{ terraform }} fmt -check -recursive -diff
    {{ terraform }} init -backend=false -input=false
    {{ terraform }} validate -no-color
    {{ terraform }} test -no-color

# Run Terraform tests with the mocked libvirt provider.
test:
    {{ terraform }} test -no-color

# Create a saved plan for review.
plan: init
    {{ terraform }} plan -out="{{ plan_file }}"
    @echo "Review with: just show-plan"
    @echo "Apply with:  just apply"

# Display the currently saved plan.
show-plan:
    @test -f "{{ plan_file }}" || { echo "No saved plan; run 'just plan' first"; exit 1; }
    {{ terraform }} show "{{ plan_file }}"

# Apply only the previously reviewed saved plan.
apply:
    @test -f "{{ plan_file }}" || { echo "No saved plan; run 'just plan' first"; exit 1; }
    {{ terraform }} apply "{{ plan_file }}"

# Refresh lease-derived outputs without changing infrastructure.
refresh:
    {{ terraform }} apply -refresh-only

# Print all Terraform outputs.
outputs:
    {{ terraform }} output

# Print node addressing and lease verification.
nodes:
    {{ terraform }} output nodes

# Generate the inventory consumed by the Ansible repository.
inventory:
    {{ terraform }} output -raw ansible_inventory > "{{ inventory_file }}"
    @echo "Wrote {{ inventory_file }}"

# Print, but do not automatically execute, the SSH command.
ssh-command:
    {{ terraform }} output -raw ssh_command
    @echo

# Remove stale host keys and verify SSH access to every managed node.
ssh-test:
    ./scripts/test-ssh.sh

# Destroy infrastructure with Terraform's interactive confirmation.
destroy:
    {{ terraform }} destroy
