#!/bin/bash

# This script configures a network interface for a PTP test,
# operating in either master or slave mode. It reloads kernel
# modules, assigns an IP address, runs a ping test, and
# finally starts the ptp4l service.

# Exit on any command failure in a pipeline
set -o pipefail

## --- Argument Validation ---
if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 <device_name> <mode>"
    echo "  <device_name>: The network interface (e.g., eth1)."
    echo "  <mode>: 'm' for master, 's' for slave."
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
   echo "This script must be run as root. Please use sudo."
   exit 1
fi

DEVICE="$1"
MODE="$2"

if [[ "$MODE" != "m" && "$MODE" != "s" ]]; then
    echo "Error: Mode must be 'm' (master) or 's' (slave)." >&2
    exit 1
fi

## --- Logging Setup ---
LOG_DATE=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="${LOG_DATE}_ptp_test_${DEVICE}_${MODE}.log"

# Function to log messages to both terminal and log file
log_message() {
    # The 'tee' command reads from standard input and writes to standard output and files.
    # The '-a' flag appends to the given file, not overwriting it.
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] - $1" | tee -a "$LOG_FILE"
}

## --- Script Execution ---
log_message "PTP Test Script Initialized."
log_message "Device: ${DEVICE}"
log_message "Mode: ${MODE}"
log_message "Log file: ${LOG_FILE}"
echo "---" | tee -a "$LOG_FILE"

# 1. Reload Kernel Modules
log_message "Resetting kernel modules for USB NIC..."
modprobe -r ax_usb_nic || log_message "Warning: Could not remove ax_usb_nic (might not be loaded)."
rmmod cdc_mbim || log_message "Warning: Could not remove cdc_mbim (might not be loaded)."
rmmod cdc_ncm || log_message "Warning: Could not remove cdc_ncm (might not be loaded)."
rmmod ax88179_178a || log_message "Warning: Could not remove ax88179_178a (might not be loaded)."
modprobe ax_usb_nic
log_message "Modules reloaded."
sleep 2 # Give modules time to settle

# 2. Assign IP Address based on Mode
MY_IP=""
TARGET_IP=""
MODE_FULL=""

if [ "$MODE" == "m" ]; then
    MY_IP="192.168.200.1"
    TARGET_IP="192.168.200.2"
    MODE_FULL="Master"
else
    MY_IP="192.168.200.2"
    TARGET_IP="192.168.200.1"
    MODE_FULL="Slave"
fi

log_message "Configuring device in ${MODE_FULL} mode."

# Disable NetworkManager control temporarily (if present)
if command -v nmcli >/dev/null 2>&1; then
    log_message "Disabling NetworkManager control for ${DEVICE}..."
    nmcli dev set "$DEVICE" managed no || log_message "Warning: Could not disable NM management."
fi

# Flush any existing IPs on the interface to avoid conflicts
ip addr flush dev "$DEVICE"

ATTEMPTS=0
MAX_ATTEMPTS=5
IP_ASSIGNED=false
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    log_message "Assigning IP ${MY_IP} to ${DEVICE} (Attempt $((ATTEMPTS+1)))..."
    ip addr add "${MY_IP}/24" dev "$DEVICE"
    # Wait a moment for the IP to be properly configured
    sleep 1
    if ip addr show "$DEVICE" | grep -q "$MY_IP"; then
        log_message "Successfully assigned IP ${MY_IP} to ${DEVICE}."
        ip link set dev "$DEVICE" up
        log_message "Interface ${DEVICE} brought up."
        log_message "Waiting 10 seconds for link stabilization..."
        sleep 10
        IP_ASSIGNED=true
        break
    fi
    log_message "Failed to verify IP address assignment. Retrying..."
    ATTEMPTS=$((ATTEMPTS+1))
    sleep 2
done

if [ "$IP_ASSIGNED" = false ]; then
    log_message "ERROR: Could not assign IP address after ${MAX_ATTEMPTS} attempts. Exiting."
    exit 1
fi

# 3. Run Ping Test
log_message "Starting ping test to ${TARGET_IP}..."
# The '-c 10' flag sends 10 packets. '-I' specifies the interface.
PING_OUTPUT=$(ping -c 10 -I "$DEVICE" "$TARGET_IP")

# Log the full ping result for diagnostics
echo "${PING_OUTPUT}" >> "$LOG_FILE"

# Check for 100% packet loss to determine failure
if echo "${PING_OUTPUT}" | grep -q "100% packet loss"; then
    log_message "PING TEST FAILED: Could not reach ${TARGET_IP} from ${DEVICE}."
    exit 1
else
    log_message "PING TEST PASSED: Successfully reached ${TARGET_IP}."
fi

# 4. Run ptp4l
log_message "Starting ptp4l..."

PTP_CMD=""
if [ "$MODE" == "m" ]; then
    PTP_CMD="ptp4l -i ${DEVICE} -m -H --masterOnly 1 --priority1 100"
else
    PTP_CMD="ptp4l -i ${DEVICE} -m -H --slaveOnly 1"
fi

# Run ptp4l in the background and redirect its output to the log file and terminal
$PTP_CMD &> >(tee -a "$LOG_FILE") &
PTP_PID=$!

log_message "ptp4l is running with PID ${PTP_PID}."
echo ">> Press 's' and then [ENTER] to stop ptp4l and exit."

while read -r input; do
  if [[ "$input" == "s" ]]; then
    break
  fi
done

log_message "Stop command received. Terminating ptp4l..."
kill "$PTP_PID"
# Wait for the process to terminate cleanly
wait "$PTP_PID" 2>/dev/null
log_message "Script finished."

exit 0

