#!/bin/bash

# ==============================================================================
# Script Name: 3xui-multi-protocol Installer & Manager (GitHub Version)
# Description: Clones from GitHub, builds, and installs the .NET application.
# Author: Gemini AI & User
# Version: 2.1 (English)
# ==============================================================================

# --- Variables ---
# !!! Important: Replace this with your own GitHub repository URL !!!
GIT_REPO_URL="https://github.com/110-ghost/3xui-multi-protocol.git"

APP_NAME="3xui-multi-protocol"
INSTALL_DIR="/opt/$APP_NAME"
SERVICE_NAME="$APP_NAME.service"
SERVICE_FILE_PATH="/etc/systemd/system/$SERVICE_NAME"

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Helper Functions ---

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run with root privileges. (sudo ./setup.sh)${NC}"
        exit 1
    fi
}

is_installed() {
    [[ -d "$INSTALL_DIR" && -f "$SERVICE_FILE_PATH" ]]
}

is_service_active() {
    systemctl is-active --quiet "$SERVICE_NAME"
}

install_dependencies() {
    # Install Git
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Prerequisite git not found. Installing...${NC}"
        apt-get update > /dev/null
        apt-get install -y git > /dev/null
        if ! command -v git &> /dev/null; then
            echo -e "${RED}Failed to install git.${NC}"
            exit 1
        fi
    fi

    # Install .NET 8 SDK
    if ! command -v dotnet &> /dev/null || ! dotnet --list-sdks | grep -q "8.0"; then
        echo -e "${YELLOW}Prerequisite .NET 8 SDK not found. Installing...${NC}"
        wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
        chmod +x dotnet-install.sh
        ./dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet
        ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
        rm dotnet-install.sh
        if ! command -v dotnet &> /dev/null; then
            echo -e "${RED}Failed to install .NET 8.${NC}"
            exit 1
        fi
        echo -e "${GREEN}.NET 8 SDK installed successfully.${NC}"
    fi
}


# --- Main Functions ---

install_app() {
    if is_installed; then
        echo -e "${YELLOW}Application is already installed. Do you want to update/reinstall it? (y/n)${NC}"
        read -r choice
        if [[ "$choice" != "y" ]]; then
            echo "Operation cancelled."
            return
        fi
        uninstall_app "silent"
    fi

    echo "--- Starting installation process from GitHub ---"

    # 1. Install prerequisites (git and dotnet)
    install_dependencies

    # 2. Clone the repository to a temporary directory
    TEMP_DIR=$(mktemp -d)
    echo -e "${YELLOW}Cloning project from GitHub...${NC}"
    git clone "$GIT_REPO_URL" "$TEMP_DIR"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error cloning the repository. Check the GIT_REPO_URL in the script.${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # 3. Publish the application from the cloned source
    echo -e "${YELLOW}Building and publishing the application...${NC}"
    dotnet publish "$TEMP_DIR" -c Release -r linux-x64 --self-contained false -o "$INSTALL_DIR"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error building the application. Please check the logs.${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # 4. Clean up the temporary source code
    rm -rf "$TEMP_DIR"

    # 5. Create systemd service file
    echo -e "${YELLOW}Creating systemd service...${NC}"
    cat << EOF > "$SERVICE_FILE_PATH"
[Unit]
Description=$APP_NAME Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/dotnet "$INSTALL_DIR/$APP_NAME.dll"
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # 6. Start and enable the service
    echo -e "${YELLOW}Enabling and starting the service...${NC}"
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"

    echo -e "${GREEN}===============================================${NC}"
    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo -e "${GREEN}===============================================${NC}"
    show_status
}

uninstall_app() {
    if ! is_installed; then
        echo -e "${RED}Application is not installed.${NC}"
        return
    fi
    
    echo -e "${YELLOW}Stopping and disabling the service...${NC}"
    systemctl stop "$SERVICE_NAME"
    systemctl disable "$SERVICE_NAME"
    
    echo -e "${YELLOW}Removing service and application files...${NC}"
    rm -f "$SERVICE_FILE_PATH"
    rm -rf "$INSTALL_DIR"
    
    systemctl daemon-reload
    
    if [[ "$1" != "silent" ]]; then
        echo -e "${GREEN}Application uninstalled successfully.${NC}"
    fi
}

start_service() {
    systemctl start "$SERVICE_NAME"
    echo "Service started."
}

stop_service() {
    systemctl stop "$SERVICE_NAME"
    echo "Service stopped."
}

restart_service() {
    systemctl restart "$SERVICE_NAME"
    echo "Service restarted."
}

show_status() {
    echo "--- Current Status ---"
    if is_installed; then
        echo -e "Installation Status: ${GREEN}Installed${NC}"
        if is_service_active; then
            echo -e "Service Status: ${GREEN}Active${NC}"
        else
            echo -e "Service Status: ${RED}Inactive${NC}"
        fi
    else
        echo -e "Installation Status: ${RED}Not Installed${NC}"
    fi
    echo "--------------------"
}

view_logs() {
    echo -e "${YELLOW}Showing live logs... (Press Ctrl+C to exit)${NC}"
    journalctl -u "$SERVICE_NAME" -f --no-pager
}

# --- Menu ---
show_menu() {
    clear
    echo "========================================"
    echo "   3xui-multi-protocol Application Manager"
    echo "          (Install from GitHub)"
    echo "========================================"
    show_status
    echo "Select an option:"
    echo " "
    echo -e "   ${GREEN}1)${NC} Install or Update Application"
    echo -e "   ${RED}2)${NC} Uninstall Application"
    echo " "
    echo -e "   ${YELLOW}--- Service Management ---${NC}"
    echo -e "   ${GREEN}3)${NC} Start Service"
    echo -e "   ${RED}4)${NC} Stop Service"
    echo -e "   ${YELLOW}5)${NC} Restart Service"
    echo " "
    echo -e "   ${YELLOW}--- Tools ---${NC}"
    echo -e "   ${GREEN}6)${NC} View Full Status"
    echo -e "   ${YELLOW}7)${NC} View Live Logs"
    echo " "
    echo -e "   ${RED}0)${NC} Exit"
    echo "========================================"
}

# --- Main Script Logic ---
check_root
while true; do
    show_menu
    read -p "Please enter a number: " choice
    
    case $choice in
        1) install_app; read -p "Press Enter to return to the menu..." ;;
        2) uninstall_app; read -p "Press Enter to return to the menu..." ;;
        3) start_service; read -p "Press Enter to return to the menu..." ;;
        4) stop_service; read -p "Press Enter to return to the menu..." ;;
        5) restart_service; read -p "Press Enter to return to the menu..." ;;
        6) systemctl status "$SERVICE_NAME" --no-pager; read -p "Press Enter to return to the menu..." ;;
        7) view_logs ;;
        0) echo "Exiting."; exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}"; sleep 2 ;;
    esac
done
