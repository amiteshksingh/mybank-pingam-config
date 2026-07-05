#!/bin/bash

PROFILE=$1
REALM=$2
FILE=$3

frodo journey import \
  --profile "$PROFILE" \
  --realm "$REALM" \
  --file "$FILE"
