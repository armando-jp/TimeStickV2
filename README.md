# TimeStickV2
## Get Yours on [Tindie](https://www.tindie.com/products/timeappliances/time-stick-v2/)

![TimeStickV2Front](/Images/2025-12-18_timestickv2_front.jpeg)
![TimeStickV2Bottom](/Images/2025-12-18_bottom.jpeg)

## USB to Ethernet adapter with AX88279 and SMA
The Time Stick USB adapter brings precision timing and advanced network functionality to any platform with a USB port.

In a small form factor, the Time Stick integrates the high-performance AX88279 USB-to-Ethernet controller with precision timing output via an SMA connector.

It’s a powerful tool for building small form-factor PTP (Precision Time Protocol) clients or grandmasters, ideal for time-sensitive networking applications.

## Key Features
* SMA for PPS output  
    ![TimeStickV2SMA](/Images/2025-12-18_female_SMA.jpeg)
* 5-pin right-angle connector for GNSS  
    ![TimeStickV2RAConnector](/Images/2025-12-18_GNSS_connector.jpeg)
* DIP switch for IO control to SMA  
    ![TimeStickV2DIP](/Images/2025-12-18_DIP_switch.jpeg)
* USB 3.0 Type-A connector  
    ![TimeStickV2USB](/Images/2025-12-18_USBA.jpeg)
* RJ45 jack with up to 2.5 GbE support  
    ![TimeStickV2RJ45](/Images/2025-12-18_rj45.jpeg)

## Building the Driver
The following steps have been tested on fresh installs of Ubuntu 22.04.1 LTS (6.8.0-90-generic kernel) and 24.04.02 LTS (6.11.0-29-generic kernel):

1. Visit the [official ASIX GitLab repository](https://gitlab.com/asix_official/ax88179_series/ax88279_linux_tod_suite) and download the AX88279_Linux_TOD_Suite.
2. `unzip ax88279_linux_tod_suite-main.zip`
3. `cd ax88279_linux_tod_suite-main`
4. `unzip ASIX_USB_NIC_Linux_Driver_Source_v3.5.17_251008.zip`
5. `cd ASIX_USB_NIC_Linux_Driver_Source_v3.5.17_251008`
6. `make`
7. If step 6 is successful, `ax_usb_nic.ko` will be created in the current directory.

## Using the Driver
To install the built driver for use with modprobe:
* `sudo make install`  
    Note: This command will back up the built-in `ax88179_178a` driver if it exists.

To load or unload the installed driver:
* Load: `sudo modprobe ax_usb_nic`
* Unload: `sudo modprobe -r ax_usb_nic`

To check driver info:
* `modinfo ax_usb_nic`

## Manual Driver Installation
To load the driver manually from the build directory:
```
sudo modprobe mii
sudo insmod ax_usb_nic.ko
```
To unload the driver manually:
* `sudo rmmod ax_usb_nic`

To check driver info:
* `modinfo ax_usb_nic.ko`

## Test Scripts
The /Scripts/ directory contains a test script called `ptp_setup.sh`. This script can be used to quickly configure and run a PTP test with a master/slave configuration.

![PTPTestArchitecture](/Images/2025-12-18_ptp_time_sync_test_architecture.jpg)

### Script prerequisites
1. `sudo apt install net-tools`
2. `sudo apt install ethtool`
3. `sudo apt install linuxptp`

Once the necessary tools are installed on each Linux machine, execute the script on each machine.

Note: The script assumes you have installed the `ax_usb_nic` driver via `sudo make install` after building the driver.

### Executing ptp_setup.sh
1. Use `ifconfig` (or `ip addr`) to identify the Time Stick V2 network interface on each Linux machine.
2. On the master machine, run:
```
./ptp_setup.sh <device_name> -m
```
3. On the slave machine, run:
```
./ptp_setup.sh <device_name> -s
```
Note: Try running both scripts at the same time; otherwise one may time out while trying to ping the other Time Stick.

4. If you have an oscilloscope connected to both Time Sticks with a rising-edge trigger configured on the master, you should see the PPS signals converge as shown:

![PTPTestWaveform](/Images/2025-12-18_ptp_test_waveform.jpg)

5. You can stop the script by pressing `s` then Enter.

For reference, here is the `ptp_setup.sh` help menu output:
```
Usage: ./ptp_setup.sh <device_name> <mode>
    <device_name>: The network interface (e.g., eth1).
    <mode>: 'm' for master, 's' for slave.
```

## Schematics
[TimeStickV2 Schematics](/Schematics/Schematic%20Prints.PDF)