#!/bin/bash
set -e

if [ $# -ne 1 ]; then
  echo "Usage: $0 search_term"
  exit 1
fi
