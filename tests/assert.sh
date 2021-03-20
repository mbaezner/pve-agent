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

# BLACK=$(echo -en "\\e[30m")
RED=$(echo -en "\\e[31m")
GREEN=$(echo -en "\\e[32m")
# ORANGE=$(echo -en "\\e[33m")
# BLUE=$(echo -en "\\e[34m")
# MAGENTA=$(echo -en "\\e[35m")
# CYAN=$(echo -en "\\e[36m")
# WHITE=$(echo -en "\\e[37m")
# YELLOW=$(echo -en "\\e[33m")
NORMAL=$(echo -en "\\e[00m")

# FUNCTIONS

## log functions

function log_success {
  printf "${GREEN}ok - %s${NORMAL}\\n" "$@"
}

function log_failure {
  printf "${RED}not ok - %s${NORMAL}\\n" "$@"
}

function log_footer {
  printf "== %s ==\\n" "$@"
}

## assert functions

function assert {
  local condition message code
  condition="$1"
  message="$2"
  code="-1"

  if eval "$condition"
  then
    if [[ $message ]]
    then
      log_success "$message"
    fi
    code="0"
  else
    if [[ $message ]]
    then
      log_failure "$message :: $condition"
    fi
    code="1"
  fi

  return $code
}

function assert_eq {
  local expected actual
  expected="$1"
  actual="$2"
  message="$3"

  if [[ -z "$message" ]]
  then
    assert "[[ \"$expected\" == \"$actual\" ]]"
  else
    assert "[[ \"$expected\" == \"$actual\" ]]" "$message"
  fi
}

function assert_contain {
  local expected actual
  expected="$1"
  actual="$2"
  message="$3"

  if [[ -z "$message" ]]
  then
    assert "[[ \"$actual\" =~ \"$expected\" ]]"
  else
    assert "[[ \"$actual\" =~ \"$expected\" ]]" "$message"
  fi
}