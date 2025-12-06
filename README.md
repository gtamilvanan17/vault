<p align="center">
  <img src="https://dummyimage.com/1200x250/000/ffffff&text=Self-Hosted+Vault+on+Azure+VM" alt="Project Banner"/>
</p>

<h1 align="center">🔐 Self-Hosted HashiCorp Vault on Azure VM</h1>
<h3 align="center">Automated Bash Installer • TLS • Raft Storage • Nginx HTTPS • Auto-Unseal</h3>

<p align="center">
  <strong>🚀 Built a fully automated self-hosted HashiCorp Vault deployment on an Azure VM!</strong>
</p>

<p align="center">
This project provides a single-command automated installer for deploying HashiCorp Vault on an Azure Ubuntu VM.
It is designed to help DevOps engineers quickly provision a secure Vault instance with minimal steps and maximum automation.
</p>
<p align="center">
The script installs, configures, initializes, unseals, and exposes Vault over HTTPS — automatically.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Vault-Automation-yellow?style=for-the-badge&logo=vault" />
  <img src="https://img.shields.io/badge/Azure-VM-blue?style=for-the-badge&logo=microsoft-azure" />
  <img src="https://img.shields.io/badge/Bash-Scripting-green?style=for-the-badge&logo=gnubash" />
  <img src="https://img.shields.io/badge/Linux-Ubuntu-orange?style=for-the-badge&logo=ubuntu" />
</p>


## This project uses a single Bash script to:
• Install and configure Vault with Raft storage  
• Generate TLS certificates  
• Set up a secure Nginx HTTPS reverse proxy  
• Create and enable systemd services  
• Automatically initialize, unseal, and log in to Vault  
• Save root token & unseal keys securely  

## This project demonstrates skills in:
🔹 Cloud Infrastructure (Azure)  
🔹 Secrets Management (HashiCorp Vault)  
🔹 Linux Automation (Bash)  
🔹 TLS & Nginx reverse proxy setup  
🔹 Systemd services  
🔹 Secure configuration & cloud hardening  

Perfect for DevOps environments, PoCs, and learning secure secret-management patterns.

## 🌟 Features
• End-to-End Automated Vault Setup
• Installs Vault from the official HashiCorp repository
• Configures folders, permissions, users, systemd service
• Sets up Integrated Storage (Raft)
• Generates TLS certificates
• Auto-creates Vault configuration (vault.hcl)
• Enables the UI and API access

## HTTPS Reverse Proxy with Nginx (Optional)

• Expose Vault over: https://<domain/IP>:8200
• Uses the same generated TLS certificate

## 🏗 Architecture Overview

<img width="820" height="520" alt="image" src="https://github.com/user-attachments/assets/ed919ccd-c731-4123-83aa-ee0482fd307c" />

<p align="center">
  <img src="architecture.svg" alt="Architecture diagram: Azure VM with Nginx and Vault with Raft storage" />
</p>


## 🛠️ Requirements
- Azure VM (Ubuntu 20.04+/22.04/24.04)
- sudo or root privileges
- DNS name (optional but recommended)
- Open NSG port. (TCP/8200)

## 🚀 Usage
1️⃣ Clone the repository
```
git clone https://github.com/<your-username>/vault.git
cd vault
```

2️⃣ Make the script executable
```
chmod +x setup-vault.sh
```

3️⃣ Run the installer
```
sudo ./setup-vault.sh
```

- During setup, you will be asked:
- Enter hostname or IP
- Whether to enable Nginx HTTPS proxy
