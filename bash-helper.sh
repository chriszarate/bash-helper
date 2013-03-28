#!/bin/bash

# Bash Helper
# -----------
# Boilerplate, logging, error checking, niceties, functions, and flim-flam.
#
# USAGE:
#   source /path/to/this.sh
#
# OPTIONS:
#  * Override defaults:
#   - resources_dir
#       Directory of resources; used as file path prefix for $resources.
#   - log_dir
#       Log directory.
#   - temp_dir
#       Temporary directory.
#  * Operation:
#   - usage_text
#       Help text describing usage and (optionally) flags.
#   - flags
#       String of flag letters in `getopts` format. If you specify flags,
#       you must provide a function named "options" which implements
#       options parsing.
#  * Security
#   - require_root
#       Set to anything to require root priveleges.
#  * Logging / silent mode
#   - enable_log
#       Set to anything to enable logging and suppress output to console.
#  * Prerequisites
#   - require_dirs
#       *Names of variables* that must be declared *and* contain required
#       directories. Useful for enforcing required flags.
#   - require_files
#       *Names of variables* that must be declared *and* contain required
#       files. Useful for enforcing required flags.
#   - args_type
#       Must be "file" or "directory". If set, at least one argument is
#       required and each argument will be checked for existence.
#
# PROVIDES:
#  * Variables
#   - current_date
#       Format: YYYYMMDD
#   - current_time
#       Format: hhmmss
#  * Functions
#   - upsearch
#       Find path in ancestor tree.
#   - realpath
#       A `realpath` clone.
#
# Written by Chris Zarate and released to the public domain.


## Configuration

  # Omit trailing slash on directories.

  # Default resources directory
  resources_dir_default="${HOME}/scripts"

  # Default log directory
  log_dir_default="$resources_dir_default/logs"

  # Temporary files directory
  temp_dir_default="$resources_dir_default/tmp"

  # Enumerate default variables.
  defaults="resources_dir log_dir temp_dir"


## Usage

  # Provide usage text.
  usage () {
    if [ -n "$1" ]; then
      echo "$1"
      echo "---"
    fi
    if [ -n "$usage_text" ]; then
      echo -n "$(basename $0) $usage_text"
    else
      echo "No usage notes; please read the script."
    fi
    exit
  }


## Error handling

  error () {
    if [ -n "$1" ]; then
      echo "$1"
    else
      echo "An unknown error occurred."
    fi
    exit 1
  }


## Require

  require () {
    if [ "$1" == "file" ]; then  # test for file
      if [ ! -f "$2" ]; then     # is not a file
        if [ -d "$2" ]; then     # is a directory
          error "$3 file is a directory: $2"
        else
          error "$3 file does not exist: $2"
        fi
      fi
    else
      if [ "$1" == "directory" ]; then  # test for directory
        if [ ! -d "$2" ]; then          # is not a directory
          if [ -f "$2" ]; then          # is a file
            error "$3 directory is a file: $2"
          else
            if [ -d "$(dirname $2)" ]; then
              mkdir -p "$2"
            else
              error "$3 directory does not exist: $2"
            fi
          fi
        fi
      else
        error "Unknown resource type: $1"
      fi
    fi
  }


## Safety

  # If requested, make sure script is being run by root.
  if [ -n "$require_root" ] && [ $EUID -ne 0 ]; then
    error "UID: $EUID. This script must be run as root."
  fi

  # Exit if any command exits with a nonzero return.
  set -o errexit


## Defaults

  # If a variable is undefined, populate it with the default.
  for default in $defaults; do
    if [ ! -n "${!default}" ]; then
      eval $default="\$${default}_default"
      require "directory" "${!default}" "Core resource"
    fi
  done


## Command-line arguments

  if [ -n "$flags" ]; then
    while getopts "$flags" opt; do
      options
    done
    shift $((OPTIND - 1))
  fi


## Logging

  # Get the current date and time.
  current_date=`date +%Y%m%d`
  current_time=`date +%H%M%S`

  if [ -n "$enable_log" ]; then

    # Set log file.
    log_file="$(basename $0)_${current_date}_${current_time}.log"

    # Redirect standard output and standard error to log file.
    exec 2>&1> "$log_dir/$log_file"

  fi


## Prerequisites

  # Expand resource paths, check that they exist,
  # and populate variables $resource[n].
  if [ -n "$resources" ]; then
    i=0
    for resource in $resources; do
      require "file" "$resources_dir/$resource" "Resource"
      eval resource$(( ++i ))="$resources_dir/$resource"
    done
  fi

  # Required variables.
  if [ -n "$require_dirs$require_files" ]; then
    for var in $require_dirs $require_files; do
      if [ ! -n "${!var}" ]; then
        usage
      fi
    done
  fi

  # Required directories.
  if [ -n "$require_dirs" ]; then
    for dir in $require_dirs; do
      require "directory" "${!dir}" "Required"
    done
  fi

  # Required files.
  if [ -n "$require_files" ]; then
    for file in $require_files; do
      require "file" "${!file}" "Required"
    done
  fi

  # Required arguments.
  if [ -n "$args_type" ]; then
    if [ $# -gt 0 ]; then
      for file in "$@"; do
        require "$args_type" "$file" "Input"
      done
    else
      usage "No input $args_type specified."
    fi
  fi


## Functions

  # Find path $1 in ancestor tree.
  upsearch () {
    local slashes=${PWD//[^\/]/}
    local parent_dir="$PWD"
    for (( n=${#slashes}; n>0; --n )); do
      test -e "$parent_dir/$1" && echo "$parent_dir/$1" && return 
      parent_dir="$parent_dir/.."
    done
  }

  # Provide `realpath` clone.
  realpath () {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
  }
