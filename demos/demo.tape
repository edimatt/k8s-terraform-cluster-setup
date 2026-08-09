Output demos/demo.gif

Require just
Require ssh

Set Shell "bash"
Set Width 1200
Set Height 700
Set FontSize 22
Set Framerate 10
Set PlaybackSpeed 4.0
Set CursorBlink false
Set TypingSpeed 35 ms

# Let the terminal settle
Sleep 1 s
Ctrl+L
Sleep 1 s

# ──────────────────────────────────────────
# Terraform plan
# ──────────────────────────────────────────

Type "just plan"
Sleep 400 ms
Enter

# Wait until the shell prompt comes back.
# Give Terraform up to 3 minutes.
Wait+Line@180s />\s*$/
Sleep 2 s

# ──────────────────────────────────────────
# Terraform apply
# ──────────────────────────────────────────

Type "just apply"
Sleep 400 ms
Enter

# Apply can take considerably longer.
Wait+Line@600s />\s*$/
Sleep 2 s

# ──────────────────────────────────────────
# SSH connectivity test
# ──────────────────────────────────────────

Type "just ssh-test"
Sleep 400 ms
Enter

Wait+Line@180s />\s*$/
Sleep 2 s

# ──────────────────────────────────────────
# Connect to the Kubernetes control plane
# ──────────────────────────────────────────

Type "ssh k8s-control-01"
Sleep 500 ms
Enter

# Leave the SSH session visible as the final shot.
Sleep 6 s
