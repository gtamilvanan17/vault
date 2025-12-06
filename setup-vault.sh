#!/usr/bin/env bash
set -euo pipefail

### Simple HashiCorp Vault setup script for Ubuntu (Azure VM friendly)
# - Installs Vault from official repo
# - Configures Raft storage
# - Generates self-signed TLS cert
# - Sets up systemd service
# - Optionally configures Nginx reverse proxy on port 443

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root, e.g. sudo bash $0"
  exit 1
fi

echo "=== HashiCorp Vault installation & setup ==="

# --- 1. Basic input ---

read -rp "Enter DNS name or IP for Vault (used in cert & api_addr, e.g. vault.example.com or 20.x.x.x): " VAULT_HOSTNAME
if [[ -z "${VAULT_HOSTNAME}" ]]; then
  echo "Hostname/IP cannot be empty."
  exit 1
fi

read -rp "Use Nginx reverse proxy on port 443? (y/n) [y]: " USE_NGINX
USE_NGINX=${USE_NGINX:-y}
USE_NGINX=$(echo "$USE_NGINX" | tr '[:upper:]' '[:lower:]')

echo "Using hostname/IP: ${VAULT_HOSTNAME}"
echo "Nginx reverse proxy: ${USE_NGINX}"

# --- 2. Packages ---

echo "=== Updating packages and installing prerequisites ==="
apt update
apt install -y unzip curl jq gnupg lsb-release

if [[ "$USE_NGINX" == "y" ]]; then
  apt install -y nginx
fi

# --- 3. Install Vault ---

echo "=== Adding HashiCorp APT repo & installing Vault ==="
if [[ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]]; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
fi

if [[ ! -f /etc/apt/sources.list.d/hashicorp.list ]]; then
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list
fi

apt update
apt install -y vault

echo "Vault version: $(vault --version)"

# --- 4. Users & directories ---

echo "=== Creating Vault directories ==="

# Package usually creates 'vault' user, but ensure it exists
if ! id -u vault >/dev/null 2>&1; then
  useradd --system --home /etc/vault.d --shell /bin/false vault
fi

mkdir -p /etc/vault.d
mkdir -p /opt/vault/data
mkdir -p /etc/vault.d/tls

chown -R vault:vault /etc/vault.d /opt/vault
chmod 750 /etc/vault.d
chmod 750 /opt/vault

# --- 5. TLS certificate ---

echo "=== Generating self-signed TLS certificate ==="
cd /etc/vault.d/tls

# Overwrite existing if present
openssl req -x509 -nodes -newkey rsa:4096 \
  -keyout vault.key -out vault.crt -days 365 \
  -subj "/CN=${VAULT_HOSTNAME}"

chmod 600 vault.key
chown vault:vault vault.key vault.crt

# --- 6. Vault configuration ---

echo "=== Writing /etc/vault.d/vault.hcl ==="

LISTENER_ADDR=""
API_ADDR=""
CLUSTER_ADDR=""

if [[ "$USE_NGINX" == "y" ]]; then
  # Vault only listens on localhost; Nginx will expose to internet
  LISTENER_ADDR="127.0.0.1:8200"
  API_ADDR="https://${VAULT_HOSTNAME}"
  CLUSTER_ADDR="https://${VAULT_HOSTNAME}"
else
  # Vault directly exposed (lock down Azure NSG to your IP!)
  LISTENER_ADDR="0.0.0.0:8200"
  API_ADDR="https://${VAULT_HOSTNAME}:8200"
  CLUSTER_ADDR="https://${VAULT_HOSTNAME}:8200"
fi

cat >/etc/vault.d/vault.hcl <<EOF
ui = true

listener "tcp" {
  address       = "${LISTENER_ADDR}"
  tls_cert_file = "/etc/vault.d/tls/vault.crt"
  tls_key_file  = "/etc/vault.d/tls/vault.key"
}

storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault-node-1"
}

disable_mlock = true

api_addr     = "${API_ADDR}"
cluster_addr = "${CLUSTER_ADDR}"

log_level = "info"
EOF

chown vault:vault /etc/vault.d/vault.hcl
chmod 640 /etc/vault.d/vault.hcl

# --- 7. systemd service ---

echo "=== Creating systemd service for Vault ==="
cat >/etc/systemd/system/vault.service <<'EOF'
[Unit]
Description=HashiCorp Vault
After=network-online.target
Wants=network-online.target

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vault
systemctl restart vault

sleep 3
systemctl --no-pager --full status vault || true

# --- 8. Nginx reverse proxy (optional) ---

if [[ "$USE_NGINX" == "y" ]]; then
  echo "=== Configuring Nginx reverse proxy on port 443 ==="

  cat >/etc/nginx/sites-available/vault <<EOF
server {
    listen 443 ssl;
    server_name ${VAULT_HOSTNAME};

    ssl_certificate     /etc/vault.d/tls/vault.crt;
    ssl_certificate_key /etc/vault.d/tls/vault.key;

    location / {
        proxy_pass https://127.0.0.1:8200/;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}

server {
    listen 80;
    server_name ${VAULT_HOSTNAME};
    return 301 https://\$host\$request_uri;
}
EOF

  ln -sf /etc/nginx/sites-available/vault /etc/nginx/sites-enabled/vault
  if [[ -f /etc/nginx/sites-enabled/default ]]; then
    rm /etc/nginx/sites-enabled/default
  fi

  nginx -t
  systemctl restart nginx
fi

echo
echo "=== DONE ==="
echo "Vault service is installed and started."

if [[ "$USE_NGINX" == "y" ]]; then
  echo "-> External URL: https://${VAULT_HOSTNAME}"
  echo "   (Remember to open port 443 in your Azure NSG.)"
else
  echo "-> External URL: https://${VAULT_HOSTNAME}:8200"
  echo "   (Remember to open port 8200 in your Azure NSG, ideally restricted to your IP.)"
fi

cat <<'NEXT_STEPS'

Next steps (run these on the VM or from a machine that can reach Vault):

  export VAULT_ADDR="$(curl -s ifconfig.me)"
  export VAULT_SKIP_VERIFY=true   # only if using this self-signed cert

  # Initialize Vault (do this ONCE)
  vault operator init -key-shares=3 -key-threshold=2 2>&1 | tee output.txt

  # Store unseal keys + root token securely, then unseal:
  vault operator unseal <unseal-key-1>
  vault operator unseal <unseal-key-2>

  # Login:
  vault login <initial-root-token>

  # Test:
  vault secrets enable -path=secret kv-v2
  vault kv put secret/demo foo=bar
  vault kv get secret/demo

NEXT_STEPS

echo "All set 🎉"
