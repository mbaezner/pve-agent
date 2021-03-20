#!/bin/bash

# Copyright 2021 Matthew Baezner
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# IMPORTS

source "./assert.sh"
source ".././pve-agent.sh"

## mock functions

function qm_binary {
  case "$1" in
    status*)
      case "$2" in
        102*)
          printf "status: stopped"
          ;;
        *)
          printf "status: running"
          ;;
      esac
      ;;
    start*)
      printf "DRY RUN: qm start %s" "${2}"
      ;;
    reboot*)
      printf "DRY RUN: qm reboot %s" "${2}"
      ;;
    stop*)
      printf "DRY RUN: qm stop %s" "${2}"
      ;;
    list*)
      # printf "VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID\n  102 kali-xfce            stopped    2048              32.00 0\n  105 qbittorrent1         running    512                6.00 2868\n  106 mint-xfce            stopped    1024              32.00 0\n  107 omv1                 running    8192              32.00 2609\n  109 manjaro-xfce         stopped    1024              32.00 0\n  900 debian               stopped    512                8.00 0"
      printf "VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID\n  101 kali-xfce            stopped    2048              32.00 0\n  102 qbittorrent1         running    512                6.00 2868"
      ;;
    config*)
      case "$2" in
        102)
          printf "%s" "agent: 1\\nballoon: 0\nbootdisk: scsi0\ncores: 2\ndescription: [pve agent]%0Arestart = always%0A%0Astate = healthy%0A%0Aqm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//localhost%3A8000/%0A# write health status to the name of the VM%0A%0A# https%3A//github.com/ayufan/pve-helpers%0A# Conflict (207 shares disks, 208 shares VGA)%0Aqm_conflict 207%0Aqm_conflict 208\nide2: none,media=cdrom\nmemory: 8192\nname: pi-hole1\nnet0: virtio=EA:50:77:35:25:AA,bridge=vmbr0,firewall=1\nnuma: 0\nonboot: 1\nostype: l26\nprotection: 1\nscsi0: local-zfs:vm-107-disk-0,iothread=1,size=32G\nscsihw: virtio-scsi-single\nsmbios1: uuid=01827008-5025-4317-9e42-34f48fe1ec17\nsockets: 1\nstartup: order=1\ntablet: 0\nvga: virtio\nvmgenid: 82e22973-c5f8-4349-ac5c-9e218c25f6a6"
          ;;
        *)
          printf "%s" "agent: 1\\nballoon: 0\nbootdisk: scsi0\ncores: 2\ndescription: [pve agent]%0Arestart = always%0A%0Astate = healthy%0A%0Aqm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//localhost%3A8000/%0A# write health status to the name of the VM%0A%0A# https%3A//github.com/ayufan/pve-helpers%0A# Conflict (207 shares disks, 208 shares VGA)%0Aqm_conflict 207%0Aqm_conflict 208\nide2: none,media=cdrom\nmemory: 8192\nname: omv1\nnet0: virtio=EA:50:77:35:25:AA,bridge=vmbr0,firewall=1\nnuma: 0\nonboot: 1\nostype: l26\nprotection: 1\nscsi0: local-zfs:vm-107-disk-0,iothread=1,size=32G\nscsihw: virtio-scsi-single\nsmbios1: uuid=01827008-5025-4317-9e42-34f48fe1ec17\nsockets: 1\nstartup: order=1\ntablet: 0\nvga: virtio\nvmgenid: 82e22973-c5f8-4349-ac5c-9e218c25f6a6"
          ;;
      esac
      ;;
    guest*)
      case "$2" in
        exec*)
          case "$3" in
            102*)
              printf "{\\n\"exitcode\" : 1,\\n\"exited\" : 1,\\n\"out-data\" : \"Hello World\\\\n\"\\n}"
              ;;
            *)
              printf "{\\n\"exitcode\" : 0,\\n\"exited\" : 1,\\n\"out-data\" : \"qm %s\"\\n}" "$*"
              ;;
          esac
          ;;
      esac
      ;;
    *)
      echo "qm $*"
      ;;
    esac
}

## test functions

function test_qm_host_exec_too_few_arguments {
  local expected actual
  expected="ERROR: Minimum of 1 arguments required (command), 0 arguments passed"
  actual="$(qm_host_exec 2>&1)"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_host_exec_single_command {
  local expected actual
  expected="$(pwd)"
  actual="$(qm_host_exec "pwd")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_host_exec_single_command_multiple_arguments {
  local expected actual
  expected="http://localhost:8000/"
  actual="$(qm_host_exec "echo -n http://localhost:8000/")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_host_exec_single_command_multiple_arguments_url_encoded {
  local expected actual
  expected="http://localhost:8000/"
  actual="$(qm_host_exec "echo -n http%3A//localhost%3A8000/")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_host_exec_return_zero {
  local expected actual
  expected="0"
  actual="$(qm_host_exec "true")"

  # NULL='$actual'; 
  assert "NULL='$actual'; [[ $expected == $? ]]" "${FUNCNAME[0]}"
}

function test_qm_host_exec_return_one {
  local expected actual
  expected="1"
  actual="$(qm_host_exec "false")"

  # NULL='$actual'; 
  assert "NULL='$actual'; [[ $expected == $? ]]" "${FUNCNAME[0]}"
}

function test_qm_host_exec_single_command_single_argument {
  local expected actual
  expected="Hello"
  actual="$(qm_host_exec "echo Hello")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_guest_exec_return_zero {
  local expected actual
  expected="0"
  actual="$(qm_guest_exec "101" "echo Hello World")"

  # NULL='$actual'; 
  assert "NULL='$actual'; [[ $expected == $? ]]" "${FUNCNAME[0]}"
}

function test_qm_guest_exec_return_one {
  local expected actual
  expected="1"
  actual="$(qm_guest_exec "102" "echo Hello World")"

  # NULL='$actual'; 
  assert "NULL='$actual'; [[ $expected == $? ]]" "${FUNCNAME[0]}"
}

function test_qm_guest_exec_single_comamnd_multiple_arguments {
  local expected actual
  expected="qm guest exec 101 curl -- --fail --silent --output /dev/null http://localhost:8000/"
  actual="$(qm_guest_exec "101" "curl --fail --silent --output /dev/null http://localhost:8000/")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_guest_exec_single_comamnd_multiple_arguments_url_encoded {
  local expected actual
  expected="qm guest exec 101 curl -- --fail --silent --output /dev/null http://localhost:8000/"
  actual="$(qm_guest_exec "101" "curl --fail --silent --output /dev/null http%3A//localhost%3A8000/")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_guest_exec_single_command_single_argument {
  local expected actual
  expected="qm guest exec 101 test -- true"
  actual="$(qm_guest_exec "101" "test true")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_guest_exec_single_command {
  local expected actual
  expected="qm guest exec 101 true"
  actual="$(qm_guest_exec "101" "true")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_guest_exec_too_few_arguments {
  local expected actual
  expected="ERROR: Minimum of 2 arguments required (vm id, command), 1 arguments passed"
  actual="$(qm_guest_exec "101" 2>&1)"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_config {
  local expected actual
  expected="description"
  actual="$(qm_config "101")"

  assert_contain "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_get_description {
  local expected actual config
  config="$(echo -e "agent: 1\ndescription: [pve agent]%qm_restart no%0A%0Astate = healthy%0A%0Aqm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//localhost%3A8000/%0A# write health status to the name of the VM%0A%0A# https%3A//github.com/ayufan/pve-helpers%0A# Conflict (207 shares disks, 208 shares VGA)%0Aqm_conflict 207%0Aqm_conflict 208\nmemory: 8192\nname: omv1\nnuma: 0\nscsi0: local-zfs:vm-107-disk-0,iothread=1,size=32G\nscsihw: virtio-scsi-single\nsmbios1: uuid=01827008-5025-4317-9e42-34f48fe1ec17\nsockets: 1\nstartup: order=1")"
  expected="[pve agent]%qm_restart no%0A%0Astate = healthy%0A%0Aqm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//localhost%3A8000/%0A# write health status to the name of the VM%0A%0A# https%3A//github.com/ayufan/pve-helpers%0A# Conflict (207 shares disks, 208 shares VGA)%0Aqm_conflict 207%0Aqm_conflict 208"
  actual="$(qm_get "${config}" "description")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_get_name {
  local expected actual config
  config="$(echo -e "agent: 1\ndescription: [pve agent]%qm_restart no%0A%0Astate = healthy%0A%0Aqm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//localhost%3A8000/%0A# write health status to the name of the VM%0A%0A# https%3A//github.com/ayufan/pve-helpers%0A# Conflict (207 shares disks, 208 shares VGA)%0Aqm_conflict 207%0Aqm_conflict 208\nmemory: 8192\nname: omv1\nnuma: 0\nscsi0: local-zfs:vm-107-disk-0,iothread=1,size=32G\nscsihw: virtio-scsi-single\nsmbios1: uuid=01827008-5025-4317-9e42-34f48fe1ec17\nsockets: 1\nstartup: order=1")"
  expected="omv1"
  actual="$(qm_get "${config}" "name")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_read_qm_healthcheck {
  local expected actual config
  config="description: [pve agent]%qm_restart no%0A%0Astate = healthy%0A%0Aqm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//localhost%3A8000/%0A# write health status to the name of the VM%0A%0A# https%3A//github.com/ayufan/pve-helpers%0A# Conflict (207 shares disks, 208 shares VGA)%0Aqm_conflict 207%0Aqm_conflict 208"
  expected="curl --fail --silent --output /dev/null http://localhost:8000/"
  actual="$(qm_read "${config}" "qm_healthcheck")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_status_stopped {
  local expected actual
  expected="status: stopped"
  actual="$(qm_status "102")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_status_running {
  local expected actual
  expected="status: running"
  actual="$(qm_status "101")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_start {
  local expected actual
  expected="DRY RUN: qm start 101"
  actual="$(qm_start 101)"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_reboot {
  local expected actual
  expected="DRY RUN: qm reboot 101"
  actual="$(qm_reboot 101)"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_stop {
  local expected actual
  expected="DRY RUN: qm stop 101"
  actual="$(qm_stop 101)"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_list {
  local expected actual
  expected="$( echo -e "101\\n102" )"
  actual="$(qm_list)"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_restart_restart_no {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_restart no%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1\nstartup: order=1" )"
  expected=""
  actual="$(qm_restart "102" "${status}" "${config}")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"  
}

function test_qm_restart_reboot_no {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_reboot no%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1\nstartup: order=1" )"
  expected=""
  actual="$(qm_restart "102" "${status}" "${config}")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"  
}

function test_qm_restart_restart_always {
  local expected actual config status
  status="status: stopped"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1\nstartup: order=1" )"
  expected="$(printf "restarting VMID 102...\\nDRY RUN: qm start 102")"
  actual="$(qm_restart "102" "${status}" "${config}")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"  
}

function test_qm_restart_reboot_always {
  local expected actual config status
  status="status: stopped"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1\nstartup: order=1" )"
  expected="$(printf "restarting VMID 102...\\nDRY RUN: qm start 102")"
  actual="$(qm_restart "102" "${status}" "${config}")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"  
}

function test_qm_restart_unconfigured {
  local expected actual config status
  status="status: stopped"
  config="$( echo -e "agent: 1\nmemory: 8192\nname: omv1\nstartup: order=1" )"
  expected=""
  actual="$(qm_restart "102" "${status}" "${config}")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"  
}

function test_qm_restart_running {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1\nstartup: order=1" )"
  expected=""
  actual="$(qm_restart "101" "${status}" "${config}")"

  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"  
}

function test_qm_healthcheck_no_agent {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 0\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1\nstartup: order=1" )"
  expected="ERROR: QEMU Guest Agent not enabled!"
  actual="$(qm_healthcheck "101" "${status}" "${config}" 2>&1)"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_stopped {
  local expected actual config status
  status="status: stopped"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1\nstartup: order=1" )"
  expected="qm set 101 --name omv1-stopped"
  actual="$(qm_healthcheck "101" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_stopped_stopped {
  local expected actual config status
  status="status: stopped"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1-stopped\nstartup: order=1" )"
  expected=""
  actual="$(qm_healthcheck "101" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_unhealthy_stopped {
  local expected actual config status
  status="status: stopped"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1-unhealthy\nstartup: order=1" )"
  expected="qm set 101 --name omv1-stopped"
  actual="$(qm_healthcheck "101" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_healthy_stopped {
  local expected actual config status
  status="status: stopped"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1-healthy\nstartup: order=1" )"
  expected="qm set 101 --name omv1-stopped"
  actual="$(qm_healthcheck "101" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_healthy {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1\nstartup: order=1" )"
  expected="qm set 101 --name omv1-healthy"
  actual="$(qm_healthcheck "101" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_stopped_healthy {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1-stopped\nstartup: order=1" )"
  expected="qm set 101 --name omv1-healthy"
  actual="$(qm_healthcheck "101" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_unhealthy_healthy {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1-unhealthy\nstartup: order=1" )"
  expected="qm set 101 --name omv1-healthy"
  actual="$(qm_healthcheck "101" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_healthy_healthy {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1-healthy\nstartup: order=1" )"
  expected=""
  actual="$(qm_healthcheck "101" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_unhealthy {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1\nstartup: order=1" )"
  expected="qm set 102 --name omv1-unhealthy"
  actual="$(qm_healthcheck "102" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_stopped_unhealthy {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1-stopped\nstartup: order=1" )"
  expected="qm set 102 --name omv1-unhealthy"
  actual="$(qm_healthcheck "102" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_healthy_unhealthy {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1-healthy\nstartup: order=1" )"
  expected="qm set 102 --name omv1-unhealthy"
  actual="$(qm_healthcheck "102" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_healthcheck_unhealthy_unhealthy {
  local expected actual config status
  status="status: running"
  config="$( echo -e "agent: 1\ndescription: qm_restart always%0Aqm_autostart 6%3A00%0Aqm_autostop 18%3A00%0Aqm_healthcheck curl --fail --silent --output /dev/null http%3A//google.com/\nmemory: 8192\nname: omv1-unhealthy\nstartup: order=1" )"
  expected=""
  actual="$(qm_healthcheck "102" "${status}" "${config}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_autopower_autostop_stopped
{
  local expected actual config status crono
  status="status: stopped"
  crono="15:00"
  config="$( echo -e "agent: 1\ndescription: qm_autostart 12%3A00%0Aqm_autostop 14%3A00\nmemory: 8192\nname: omv1-unhealthy\nstartup: order=1" )"
  expected=""
  actual="$(qm_autopower "102" "${status}" "${config}" "${crono}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_autopower_autostop_running
{
  local expected actual config status crono
  status="status: running"
  crono="15:00"
  config="$( echo -e "agent: 1\ndescription: qm_autostart 12%3A00%0Aqm_autostop 14%3A00\nmemory: 8192\nname: omv1-unhealthy\nstartup: order=1" )"
  expected="$(printf "automatically stopping VMID 102...\\nDRY RUN: qm stop 102")"
  actual="$(qm_autopower "102" "${status}" "${config}" "${crono}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_autopower_autostart_stopped
{
  local expected actual config status crono
  status="status: stopped"
  crono="13:00"
  config="$( echo -e "agent: 1\ndescription: qm_autostart 12%3A00%0Aqm_autostop 14%3A00\nmemory: 8192\nname: omv1-unhealthy\nstartup: order=1" )"
  expected="$(printf "automatically starting VMID 102...\\nDRY RUN: qm start 102")"
  actual="$(qm_autopower "102" "${status}" "${config}" "${crono}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}

function test_qm_autopower_autostart_running {
  local expected actual config status crono
  status="status: running"
  crono="13:00"
  config="$( echo -e "agent: 1\ndescription: qm_autostart 12%3A00%0Aqm_autostop 14%3A00\nmemory: 8192\nname: omv1-unhealthy\nstartup: order=1" )"
  expected=""
  actual="$(qm_autopower "102" "${status}" "${config}" "${crono}")"
  
  assert_eq "$expected" "$actual" "${FUNCNAME[0]}"
}


# function test_pve_agent {
#   pve_agent
# }

## run function

function run_test_suite {
  RETURN_CODE=0
  COUNT=0
  COUNT_PASSED=0
  COUNT_FAILED=0

  for testcase in $(declare -f | grep --only-matching "^test[a-zA-Z_]*")
  do
    if ${testcase}
    then
      COUNT_PASSED=$(( COUNT_PASSED + 1 ))
    else
      COUNT_FAILED=$(( COUNT_FAILED + 1 ))
    fi
    COUNT=$(( COUNT + 1 ))
  done

  log_footer "$COUNT_PASSED tests passed, $COUNT_FAILED failed"

  if [[ "$COUNT_FAILED" -ne 0 ]]
  then
    RETURN_CODE=1
  fi

  return $RETURN_CODE
}

# SCRIPT

run_test_suite