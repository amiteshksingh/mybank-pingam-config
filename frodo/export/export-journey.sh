#!/bin/bash

PROFILE=$1
REALM=$2
JOURNEY=$3

frodo journey export \
  --profile "$PROFILE" \
  --realm "$REALM" \
  --journey "$JOURNEY"

