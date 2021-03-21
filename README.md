# pve-agent

## Description

Shell script to automatically start, stop, restart virtual machines; and perform healthchecks.  The script is designed to be executed on a schedule using cron.  The script reads the description of every virtual machine on the host looking for the keywords in the description and performing any required actions.

## Usage

Add any or all of the function keywords with a parameter into the "Notes" section of a virtual machines.

## Install

### Manually 

**Require sudo permissions**

1. Login to the Proxmox host
2. `git clone https://github.com/mbaezner/pve-agent.git /tmp/pve-agent`
3. `sudo cp /tmp/pve-agent/pve-agent.sh /var/lib/vz/snippets/pve-agent.sh`
4. `sudo chmod +x /var/lib/vz/snippets/pve-agent.sh`

### Ansible

1. See ansible role

## Functions

### qm_reboot \<policy\>

| Policy   | Description                                                    |
| -------- | -------------------------------------------------------------- |
| `no`     | Do not automatically restart the virtual machine (the default) |
| `always` | Always restart the virtual machine when it is not running      |

#### Examples

``` shell
qm_restart always
```

#### Alias

- qm_restart \<policy\>

### qm_autostart \<time\>

Automatically start the virtual machine at the specified time

#### Examples

``` shell
qm_autostart 6:00
```

### qm_autostop \<time\>

Automatically stop the virtual machine at the specified time

#### Examples

``` shell
qm_autostop 18:00
```

### qm_healthcheck \<command\>

Command is run inside the virtual machine via the QEMU Guest Agent, so the **QEMU Guest agent must be installed and enabled** for the Virtual Machine

Appends "-healthy" to the virtual machine name when the commands returns 0, or "-unhealthy" when the command returns non-zero; if the original virtual machine name is "ubuntu", when the command returns zero the name will be changed to "ubuntu-healthy" and when the command returns non-zero the name will be changed to "ubuntu-unhealthy"

#### Examples

``` shell
qm_healthcheck curl --fail --silent --output /dev/null http://localhost:80
```

## Inspiration

- [ayufan/pve-helpers](https://github.com/ayufan/pve-helpers)
- [Start containers automatically](https://docs.docker.com/config/containers/start-containers-automatically/#use-a-restart-policy)
