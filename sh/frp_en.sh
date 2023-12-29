#!/bin/bash

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "curl not found, attempting to install based on system type..."
    
    # Detect system type and install accordingly
    if [ -f /etc/debian_version ]; then
        echo "Installing curl (for Debian/Ubuntu systems)..."
        sudo apt update
        sudo apt install -y curl
    elif [ -f /etc/redhat-release ]; then
        echo "Installing curl (for Red Hat/CentOS systems)..."
        sudo yum install -y curl
    else
        echo "Unable to determine system type or not supported. Please manually install curl."
        exit 1
    fi
fi

# Check if systemd is installed
if ! command -v systemctl &> /dev/null; then
    echo "System does not have systemd installed, attempting to install based on system type..."
    
    # Detect system type and install accordingly
    if [ -f /etc/debian_version ]; then
        echo "Installing systemd (for Debian/Ubuntu systems)..."
        sudo apt update
        sudo apt install -y systemd
    elif [ -f /etc/redhat-release ]; then
        echo "Installing systemd (for Red Hat/CentOS systems)..."
        sudo yum install -y systemd
    else
        echo "Unable to determine system type or not supported. Please manually install systemd."
        exit 1
    fi
fi

# Check if tar is installed
if ! command -v tar &> /dev/null; then
    echo "tar not found, attempting to install based on system type..."

    # Detect system type and install accordingly
    if [ -f /etc/debian_version ]; then
        echo "Installing tar (for Debian/Ubuntu systems)..."
        sudo apt update
        sudo apt install -y tar
    elif [ -f /etc/redhat-release ]; then
        echo "Installing tar (for Red Hat/CentOS systems)..."
        sudo yum install -y tar
    else
        echo "Unable to determine system type or not supported. Please manually install tar."
        exit 1
    fi
fi

echo "If already installed, please back up the configuration files in advance."

# Get user choice for installing frpc or frps
echo "Select the component to install:"
echo "1. frpc"
echo "2. frps"
read -p "Enter the number (1/2): " choice

case $choice in
    1)
        COMPONENT="frpc"
        ;;
    2)
        COMPONENT="frps"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

# Define paths for frp.tar.gz and extraction directory
FRP_PACKAGE_PATH="$HOME/frp.tar.gz"
INSTALL_DIR="/usr/local/bin/$COMPONENT"
CONFIG_DIR="/etc/$COMPONENT"

# Check if frp.tar.gz exists
if [ ! -f "$FRP_PACKAGE_PATH" ]; then
    echo "frp.tar.gz not found. Choose an action:"
    echo "1. Manually download and place frp.tar.gz"
    echo "2. Automatically download from the internet"
    echo "3. Download specific version v0.50.0 (recommended))"
    read -p "Enter the number (1/2/3): " download_choice

    case $download_choice in
        1)
            echo "Please manually download frp.tar.gz and place it at $FRP_PACKAGE_PATH."
            echo "Visit https://github.com/fatedier/frp/releases/ to download the Linux version file, rename it to frp.tar.gz, and store it in the $HOME directory."
            echo "Download the corresponding version, as mismatch may cause issues."
            exit 1
            ;;
        2)
            echo "Downloading from the internet..."
            echo "This script provides network installation (scheduled to pull the latest version automatically), but the installed version may lag behind the GitHub version."
            curl -o "$FRP_PACKAGE_PATH" "https://yunzeo.github.io/download/frp.tar.gz"
            ;;
        3)
            echo "Downloading specific version v0.50.0..."
            curl -o "$FRP_PACKAGE_PATH" "https://yunzeo.github.io/download/old/frp.tar.gz"
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
fi

# Create installation and configuration directories
sudo mkdir -p "$INSTALL_DIR"
sudo mkdir -p "$CONFIG_DIR"

# Extract frp.tar.gz and move files to installation directory
tar -xzvf "$FRP_PACKAGE_PATH" --strip-components=1 -C "$INSTALL_DIR"

# Create example configuration file
sudo touch "$CONFIG_DIR/${COMPONENT}.ini"
# Add default configuration content as needed

# Check if tar extraction was successful
if [ -f "$INSTALL_DIR/$COMPONENT" ] && [ -f "$CONFIG_DIR/${COMPONENT}.ini" ]; then
    echo "Files successfully extracted and moved to the installation directory."

    # Check if frps and frpc files were successfully extracted
    if [ -f "$INSTALL_DIR/frps" ] && [ -f "$INSTALL_DIR/frpc" ]; then
        echo "$COMPONENT successfully extracted."
    else
        echo "Issues occurred during extraction; $COMPONENT files were not successfully extracted. Please check and rerun the script."
        exit 1
    fi
else
    echo "Issues occurred during extraction; files were not successfully extracted. Please check and rerun the script."
    exit 1
fi

# Create systemd service unit file
sudo tee "/etc/systemd/system/${COMPONENT}.service" > /dev/null <<EOL
[Unit]
Description=frp $COMPONENT
After=network.target

[Service]
Type=simple
ExecStart="$INSTALL_DIR/$COMPONENT" -c "$CONFIG_DIR/${COMPONENT}.ini"
Restart=on-failure

[Install]
WantedBy=default.target
EOL

# Enable and start the frp service
sudo systemctl enable "${COMPONENT}.service"
sudo systemctl start "${COMPONENT}.service"

# Output installation completion information and commands to manage the service
echo "$COMPONENT installation complete! Installation directory: $INSTALL_DIR"
echo "Configuration file directory: $CONFIG_DIR"
echo "Autostart enabled"
echo "$COMPONENT service has started. Use the following commands to manage:"
echo "Start service: sudo systemctl start ${COMPONENT}.service"
echo "Stop service: sudo systemctl stop ${COMPONENT}.service"
echo "Restart service: sudo systemctl restart ${COMPONENT}.service"
echo "Enable autostart: sudo systemctl enable ${COMPONENT}.service"
echo "Disable autostart: sudo systemctl disable ${COMPONENT}.service"
echo "Check service status: sudo systemctl status ${COMPONENT}.service"
