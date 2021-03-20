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

# TODO: Add logging
LOG="/var/log/pve-agent.log"

# FUNCTIONS

## Helpers

function error
{
  printf "%s\\n" "$*" >&2
}

## Wrappers

# https://pve.proxmox.com/pve-docs/qm.1.html
function qm_binary
{
  /usr/sbin/qm "$@"
}

# qm_list
function qm_list
{
  local LIST

  # list virtual machiens from qemu
  LIST=$(qm_binary list)

  # split list of virtual machines by newlines
  mapfile -t LINES <<< "${LIST}"

  # iternate over each virtual machine in the list
  for LINE in "${LINES[@]}"
  do
    # split the line from the virtual machine list by spaces
    read -ra FIELDS <<< "${LINE}"
 
    # skip the line when the first item is "VMID" (table header)
    if [[ "${FIELDS[0]}" == "VMID" ]]
    then
      continue
    fi

    # collect virtual machine identifiers
    RESULT="${RESULT}${FIELDS[0]}\\n"
  done

  # remove the uneeded tilda from the end of the string
  # RESULT="${RESULT:0:${#RESULT}-1}"

  # return a new line seperated list of virtual machine identifiers
  # printf "%s" "${RESULT}"
  echo -e "${RESULT}"
  return 0
}

# qm_config <id>
function qm_config
{
  local VMID="${1}"

  qm_binary config "${VMID}"
}

# qm_config_select <config> <key>
function qm_get
{
  local CONFIG ENTRY
  CONFIG="${1}"
  KEY="${2}"

  # split string by tilda
  mapfile -t LINES <<< "${CONFIG}"

  # find line that containers the key
  for LINE in "${LINES[@]}"
  do

    if [[ "${LINE}" =~ ${KEY}\: ]]
    then

      # remove key and return only value
      printf "%s" "${LINE/${KEY}: /}"
      return 0

    fi

  done

  return 1
}

# qm_read <description> <entry>
function qm_read
{
  local DESCRIPTION ENTRY
  DESCRIPTION="${1}"
  ENTRY="${2}"

  # replace encoded new line characters (%0A) with tilda for easier splitting
  DESCRIPTION="${DESCRIPTION//\%0A/\~}"

  # split string by tilda
  mapfile -td '~' LINES <<< "${DESCRIPTION}"

  # iterate over lines of virtual machine description until qm_healthcheck is found
  for LINE in "${LINES[@]}"
  do

    if [[ "${LINE}" =~ ${ENTRY} ]]
    then

      # remove entry key leaving only the value
      LINE="${LINE/${ENTRY} /}"

      # decode url encoding (url encoding is used by Proxmox 
      # for special and control characters in the virtual machine description)
      printf '%b' "${LINE//%/\\x}"
      return 0

    fi

  done

  return 1
}

# qm_set <id> <key> <value>
function qm_set
{
  local VM_ID VM_DESCRIPTION
  VMID="${1}"
  KEY="${2}"
  VALUE="${3}"

  qm_binary set "${VMID}" "--${KEY}" "${VALUE}" 2> /dev/null
}

# qm_status <id>
function qm_status
{
  local VMID
  VMID="${1}"

  qm_binary status "${VMID}"
}

# qm_start <id>
function qm_start
{
  local VMID
  VMID="${1}"

  qm_binary start "${VMID}"
}

# qm_stop <id>
function qm_stop
{
  local VMID
  VMID="${1}"

  qm_binary stop "${VMID}"
}

# qm_reboot <id>
function qm_reboot
{
  local VMID
  VMID="${1}"

  qm_binary reboot "${VMID}"
}

# qm_host_exec <command>
function qm_host_exec
{
  # valid that enough arguments have been passed into the function
  MINIMUM_ARGUMENTS="1"
  if ! [[ "${#}" -ge "${MINIMUM_ARGUMENTS}" ]]
  then
    error "ERROR: Minimum of ${MINIMUM_ARGUMENTS} arguments required (command), ${#} arguments passed"
    return 1
  fi

  local HOST_COMMAND="${*}"

  # decode url encoding (url encoding is used by Proxmox 
  # for special and control characters in the virtual machine description)
  printf -v HOST_COMMAND '%b' "${HOST_COMMAND//%/\\x}"

  local OUTDATA EXITCODE
  OUTDATA="$(${HOST_COMMAND})"
  EXITCODE=$?

  # return command output by printing to standard out,
  # and return with the return code
  printf "%s" "${OUTDATA}"
  return "${EXITCODE}"
}

# qm_guest_exec <id> <command>
function qm_guest_exec
{
  # valid that enough arguments have been passed into the function
  MINIMUM_ARGUMENTS="2"
  if ! [[ "${#}" -ge "${MINIMUM_ARGUMENTS}" ]]
  then
    error "ERROR: Minimum of ${MINIMUM_ARGUMENTS} arguments required (vm id, command), ${#} arguments passed"
    return 1
  fi

  local VMID="${1}"
  shift # Drop first argument (VMID) from argument array ($@)

  # read remaining arguments into an array, splitting by space
  read -ra ARGUMENTS <<< "${@}"

  # assign the first element of the array to a variable 
  # in order to seperate the command from the arguments.
  local COMMAND="${ARGUMENTS[0]}"

  # remove the first element from the array to avoid doubling it when
  # using arguments after the command in a string.
  unset "ARGUMENTS[0]"

  local GUEST_COMMAND="qm_binary guest exec ${VMID} ${COMMAND}"

  # append arugments to command as an array
  if [[ "${#ARGUMENTS[@]}" -gt 0 ]]
  then
    GUEST_COMMAND="${GUEST_COMMAND} -- ${ARGUMENTS[*]}"
  fi

  # decode url encoding (url encoding is used by Proxmox 
  # for special and control characters in the virtual machine description)
  printf -v GUEST_COMMAND '%b' "${GUEST_COMMAND//%/\\x}"

  # execute command
  local RESULT
  RESULT="$(${GUEST_COMMAND})"

  # read result into an array, splitting by new line
  mapfile -t OUTPUT <<< "${RESULT}"

  # extract the return code
  if [[ "${OUTPUT[1]}" =~ (\"exitcode\")( : )([0-9]+)(\,) ]]
  then
    local EXITCODE="${BASH_REMATCH[3]}"
  fi

  # extract the out-data
  if [[ "${OUTPUT[3]}" =~ (\"out-data\")( : )(\")(.*)(\") ]]
  then
    local OUTDATA="${BASH_REMATCH[4]}"
  fi

  # return command output by printing to standard out,
  # and return with the return code
  printf "%s" "${OUTDATA}"
  return "${EXITCODE}"
}

# qm_autopower <id> <status> <config> <time>
function qm_autopower
{
  local VMID VMSTATUS VMCONFIG NOW VMDESCRIPTION VMSTARTTIME
  VMID="${1}"
  VMSTATUS="${2}"
  VMCONFIG="${3}"
  NOW="${4}"
  VMDESCRIPTION="$(qm_get "${VMCONFIG}" "description")"

  # convert current time to epoch
  NOW="$(date --date=${NOW} +%s)"

  # check that virtual machine is configured with a autostart policy
  if [[ "${VMDESCRIPTION}" =~ qm_autostart || "${VMDESCRIPTION}" =~ qm_autostop ]]
  then

    # read value of qm_autostart and qm_autostop from description 
    # and then convert the value to an epoch
    VMSTARTTIME="$(qm_read "${VMDESCRIPTION}" "qm_autostart")"
    VMSTARTTIME="$(date --date=${VMSTARTTIME} +%s)"
    
    VMSTOPTIME="$(qm_read "${VMDESCRIPTION}" "qm_autostop")"
    VMSTOPTIME="$(date --date=${VMSTOPTIME} +%s)"

    if [[ "${NOW}" -ge "${VMSTOPTIME}" ]]
    then

      # check that virtual machine is not alreay stopped
      if ! [[ "${VMSTATUS}" =~ stopped ]]
      then

          printf "automatically stopping VMID %s...\\n" "${VMID}"
          qm_stop "${VMID}"

      fi
    
    elif [[ "${NOW}" -ge "${VMSTARTTIME}" ]]
    then

      # check that virtual machine is not alreay running
      if ! [[ "${VMSTATUS}" =~ running ]]
      then

          printf "automatically starting VMID %s...\\n" "${VMID}"
          qm_start "${VMID}"

      fi
    
    fi

  fi
}

# TODO: 
# - restart options: https://docs.docker.com/config/containers/start-containers-automatically/
# - need to determine if qemu vms have exit codes for clean or dirty stops to implemented "on-failure" and "unless-stopped"
# qm_restart <id> <status> <config>
function qm_restart
{
  local VMID VMSTATUS VMDESCRIPTION
  VMID="${1}"
  VMSTATUS="${2}"
  VMCONFIG="${3}"
  VMDESCRIPTION="$(qm_get "${VMCONFIG}" "description")"

  # check that virtual machine is configured with a restart policy
  if [[ "${VMDESCRIPTION}" =~ qm_restart || "${VMDESCRIPTION}" =~ qm_reboot ]]
  then

    # check that virtual machine is not alreay running
    if ! [[ "${VMSTATUS}" =~ running ]]
    then

      # check that virtual machine is configured to always be restarted
      if [[ "${VMDESCRIPTION}" =~ qm_restart[[:space:]]always || "${VMDESCRIPTION}" =~ qm_reboot[[:space:]]always ]]
      then

        printf "restarting VMID %s...\\n" "${VMID}"
        qm_start "${VMID}"

      fi

    fi

  fi
}

# qm_healthcheck <id> <status> <config>
function qm_healthcheck
{
  local VMID VMSTATUS VMCONFIG VMAGENT VMNAME VMDESCRIPTION VMCOMMAND STATE
  VMID="${1}"
  VMSTATUS="${2}"
  VMCONFIG="${3}"
  VMAGENT="$(qm_get "${VMCONFIG}" "agent")"
  VMNAME=$(qm_get "${VMCONFIG}" "name")
  VMDESCRIPTION="$(qm_get "${VMCONFIG}" "description")"
  STATE="unknown"

  # check that QEMU Guest Agent is enabled (therefore installed)
  if [[ "${VMAGENT}" == 1 ]]
  then

    # check that virtual machine is configured with a healthcheck command
    if [[ "${VMDESCRIPTION}" =~ qm_healthcheck ]]
    then

      VMCOMMAND="$(qm_read "${VMDESCRIPTION}" "qm_healthcheck")"

      # check that the virtual machine is not stopped
      if [[ "${VMSTATUS}" =~ stopped ]]
      then

        STATE="stopped"

      else

        local HEALTH_RESULT HEALTH_STATUS
        HEALTH_RESULT="$(qm_guest_exec "${VMID}" "${VMCOMMAND}")"
        HEALTH_STATUS="${?}"

        if [[ "${HEALTH_STATUS}" == 0 ]]
        then

          STATE="healthy"

        else

          STATE="unhealthy"

        fi

      fi

      if ! [[ "${VMNAME}" =~ "-${STATE}" ]]
      then

        VMNAME="${VMNAME/-stopped/}"
        VMNAME="${VMNAME/-unhealthy/}"
        VMNAME="${VMNAME/-healthy/}"

        VMNAME="${VMNAME}-${STATE}"

        qm_set "${VMID}" "name" "${VMNAME}"

      fi

    fi
  else

    error "ERROR: QEMU Guest Agent not enabled!"
    return 1

  fi
}

# SCRIPT

function pve_agent
{
  # store current time as epoch / linux time
  NOW="$(date +%R)"

  # list all virtual machines and return only id numbers
  VMLIST=$(qm_list)

  # split string by new line
  mapfile -t VMARRAY <<< "${VMLIST}"
  
  # loop through all virtual machines
  for VM in "${VMARRAY[@]}"
  do
    VMID="${VM}"
    VMSTATUS="$(qm_status "${VMID}")"
    VMCONFIG="$(qm_config "${VMID}")"

    qm_autopower "${VMID}" "${VMSTATUS}" "${VMCONFIG}" "${NOW}"
    qm_restart "${VMID}" "${VMSTATUS}" "${VMCONFIG}"
    qm_healthcheck "${VMID}" "${VMSTATUS}" "${VMCONFIG}"
  done
}

# Call the function only if the script is executed directly.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  pve_agent
fi