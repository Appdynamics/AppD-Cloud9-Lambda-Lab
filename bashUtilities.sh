#!/bin/bash
#
# Copyright (c) AppDynamics Inc
# All rights reserved
#
# Maintainer: David Ryder, david.ryder@appdynamics.com
#
# Requires: jq (brew install jq)
#
#

_awsCloud9ListEnvironments() {
  LIST1=$(aws cloud9 list-environments --query environmentIds[*] --output text)
  for ENV_ID in $LIST1; do
    aws cloud9 describe-environments --environment-ids $ENV_ID
  done
}
