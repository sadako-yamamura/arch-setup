<!-- PROJECT LOGO -->
<br />
<div align="center">
  <img width="100" height="100" alt="image" src="https://github.com/user-attachments/assets/748b285b-cc4e-4e75-b4e4-e2b0a9fb6683" />
  <h2 align="center">Arch Script Installer</h2>
  <br>

[![Arch](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=fff&style=for-the-badge)](https://wiki.archlinux.org)
[![Artix](https://img.shields.io/badge/Artix%20Linux-555555?logo=artix-linux&style=for-the-badge)](https://wiki.artixlinux.org)

<ins>[Arch Linux Official Guide](https://wiki.archlinux.org/title/Installation_guide) | 
[Artix Linux Official Guide](https://wiki.artixlinux.org/Main/Installation)
</ins>
</div>


> [!NOTE]
> Full Artix installation with Desktop Env. requires 5 GB ≈.

---

#### 1. Download the live USB installer

[Arch Linux](https://archlinux.org/download/) | [Artix (for base dinit)](https://artixlinux.org/download.php)

---

#### 2. Optionally connect through SSH

Run the live USB installer in the target machine, and then:
<details>
<summary> Arch </summary>
  
```
# If using Wlan and no Ethernet
iwctl
station <wlan0> connect <SSID>
# Input WiFi password

# Set a password to use for SSH
passwd

# Get host IP
ip a
```
</details>

<details>
<summary> Artix </summary>

```
# If using Wlan and no Ethernet
rfkill unblock wifi
ip link set <wlan0> up
connmanctl
agent on
scan wifi
services | grep "<SSID>"
connect <wifi_id>
# Input WiFi password
exit

# Get host IP
ip a

# Manually start SSH service
# If using dinit
dinitctl start sshd
```
</details>

##### Then, on the host
```
# On the client
ssh root@<ip>
```

---

#### 3. Download the script
Inside the live USB installer, get the script and execute it

For Arch
```
curl -L https://raw.githubusercontent.com/sadako-yamamura/arch/refs/heads/main/arch_script.sh -o installer.sh
```
For Artix
```
curl -L https://raw.githubusercontent.com/sadako-yamamura/arch/refs/heads/main/artix_dinit.sh -o installer.sh
```
Then
```
# Make sure user is root
su root

chmod +x installer.sh
bash ./installer.sh
```

> [!IMPORTANT]  
> <ins>**System must be booted on UEFI mode**</ins>.  When installing it on VMware Workstation make sure it is enabled in settings.
<br>
<div align="center">
<img width="480" height="324" alt="image" src="https://github.com/user-attachments/assets/8f17e44b-8eee-4204-880d-0535e5ea5bb8"/>
</div>
<br>
<br>

Last tested on: <br>
```console
# Arch
$ cat /proc/version
Linux version 7.0.3-arch1-1 (linux@archlinux) (gcc (GCC) 15.2.1 20260209, GNU ld (GNU Binutils) 2.46) #1 SMP PREEMPT_DYNAMIC Thu, 30 Apr 2026 18:41:12 +0000
# Artix
$ cat /proc/version
Linux version 7.0.10-artix1-1 (linux@artixlinux) (gcc (GCC) 16.1.1 20260430, GNU ld (GNU Binutils) 2.46.0) #1 SMP PREEMPT_DYNAMIC Sat, 23 May 2026 18:01:41 +0000
```

</details>
<br>

---
# arch-setup
# arch-setup
# arch-setup
