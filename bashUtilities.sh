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

_randomPassword() {
  RND_PWD="$(openssl rand -base64 64 | tr -dc A-Z | cut -c1-4)+$(openssl rand -base64 64 | tr -dc 0-9 | cut -c1-4)-$(openssl rand -base64 64 | tr -dc a-z | cut -c1-4)=$(openssl rand -base64 8 | tr -dc A-Z-a-z-0-9)"
  echo $RND_PWD
}
