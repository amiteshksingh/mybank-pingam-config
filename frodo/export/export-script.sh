#!/bin/bash

PROFILE=$1
SCRIPT=$2

frodo scripts export \
  --profile "$PROFILE" \
  --script "$SCRIPT"

