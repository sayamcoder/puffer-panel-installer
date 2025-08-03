#!/bin/bash

# ==============================================================================
# PufferPanel Installer Script
#
# Author: AI Assistant (with reference to official PufferPanel documentation)
# Version: 1.1
#
# This script automates the installation of PufferPanel on Debian and
# Ubuntu-based systems. It handles dependencies, repository setup,
# user creation, and service configuration.
#
# Usage:
#   wget https://path/to/this/script/install_pufferpanel.sh
#   chmod +x install_pufferpanel.sh
#   sudo ./install_pufferpanel.sh
#
# ==============================================================================

# --- Configuration & Colors ---
set -e # Exit immediately if a command exits with a non-zero status.

# Colors for better output
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

# --- Helper Functions ---
log_info() {
    echo -e "${C_BLUE}INFO:${C_RESET} $1"
}

log_success() {
    echo -e "${C_GREEN}SUCCESS:${C_RESET} $1"
}

log_warn() {
    echo -e "${C_YELLOW}WARNING:${C_RESET} $1"
}

log_error() {
    echo -e "${C_RED}ERROR:${C_RESET} $1" >&2
    exit 1
}

# --- Pre-flight Checks ---
check_root() {
    log_info "Checking for root privileges..."
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root. Please use 'sudo'."
    fi
    log_success "Root privileges confirmed."
}

check_distro() {
    log_info "Checking operating system compatibility..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
            log_error "This script is intended for Debian or Ubuntu systems only. Detected OS: $ID"
        fi
        log_success "Operating system is compatible ($PRETTY_NAME)."
    else
        log_error "Cannot determine the operating system. /etc/os-release not found."
    fi
}

# --- Main Installation Functions ---
install_dependencies() {
    log_info "Updating package lists and installing required dependencies..."
    apt-get update
    apt-get install -y curl wget gnupg apt-transport-https ca-certificates
    log_success "Dependencies installed."
}

setup_pufferpanel_repo() {
    log_info "Setting up the PufferPanel repository..."
    
    # Add PufferPanel GPG key
    log_info "Adding PufferPanel GPG key..."
    mkdir -p /etc/apt/keyrings
    curl -sSLo /etc/apt/keyrings/pufferpanel.gpg https://repo.pufferpanel.com/pufferpanel.gpg
    
    # Add the repository source list
    log_info "Adding PufferPanel to repository sources..."
    echo "deb [signed-by=/etc/apt/keyrings/pufferpanel.gpg] https://repo.pufferpanel.com/v3/debian $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/pufferpanel.list > /dev/null
    
    log_info "Updating package lists with the new repository..."
    apt-get update
    
    log_success "PufferPanel repository has been configured."
}

install_pufferpanel() {
    if command -v pufferpanel &> /dev/null; then
        log_warn "PufferPanel is already installed. Skipping installation."
    else
        log_info "Installing PufferPanel..."
        apt-get install -y pufferpanel
        log_success "PufferPanel has been installed."
    fi
}

create_admin_user() {
    log_info "Creating the first administrative user for PufferPanel."
    
    local username email password password_confirm
    
    read -p "Enter a username for the admin account: " username
    read -p "Enter an email for the admin account: " email
    
    while true; do
        read -s -p "Enter a password for the admin account: " password
        echo
        read -s -p "Confirm the password: " password_confirm
        echo
        if [ "$password" = "$password_confirm" ]; then
            break
        else
            log_warn "Passwords do not match. Please try again."
        fi
    done
    
    log_info "Adding user '$username'..."
    pufferpanel user add --name "$username" --email "$email" --password "$password" --admin
    log_success "Admin user '$username' created successfully."
}

enable_and_start_service() {
    log_info "Enabling and starting the PufferPanel service..."
    systemctl enable --now pufferpanel
    
    # Small delay to let the service start up
    sleep 3
    
    if systemctl is-active --quiet pufferpanel; then
        log_success "PufferPanel service is active and running."
    else
        log_error "The PufferPanel service failed to start. Please check logs with 'journalctl -fu pufferpanel'."
    fi
}

display_post_install_info() {
    local ip_address
    ip_address=$(hostname -I | awk '{print $1}')
    
    echo -e "\n${C_CYAN}===================================================================${C_RESET}"
    echo -e "${C_GREEN}          PufferPanel Installation Complete!                       ${C_RESET}"
    echo -e "${C_CYAN}===================================================================${C_RESET}"
    echo
    log_info "You can now access your PufferPanel web interface at:"
    echo -e "  ${C_YELLOW}http://$ip_address:8080${C_RESET}"
    echo
    log_info "Log in with the admin credentials you just created."
    echo
    log_warn "IMPORTANT: If you cannot access the panel, you may need to open port 8080 in your firewall."
    echo -e "If you are using 'ufw' (Uncomplicated Firewall), you can do this by running:"
    echo -e "  ${C_CYAN}sudo ufw allow 8080/tcp${C_RESET}"
    echo -e "  ${C_CYAN}sudo ufw allow 22/tcp   # To ensure you don't lose SSH access!${C_RESET}"
    echo -e "  ${C_CYAN}sudo ufw enable         # If not already enabled${C_RESET}"
    echo
    log_info "To view PufferPanel logs, run: ${C_CYAN}journalctl -fu pufferpanel${C_RESET}"
    log_info "To manage the service, use: ${C_CYAN}systemctl [status|stop|start|restart] pufferpanel${C_RESET}"
    echo
    echo -e "${C_CYAN}===================================================================${C_RESET}"
}

# --- Main Execution ---
main() {
    echo -e "${C_CYAN}### PufferPanel Automated Installer ###${C_RESET}\n"
    
    check_root
    check_distro
    
    install_dependencies
    setup_pufferpanel_repo
    install_pufferpanel
    create_admin_user
    enable_and_start_service
    
    display_post_install_info
}

# Run the main function
main