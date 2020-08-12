#!/usr/bin/env bash

# exit immediately if a command fails
set -o errexit

# exit immediately if an unset variable is used
set -o nounset

readonly target_json="$HOME/.config/sa_config.json"

SCRIPT=$(readlink -f "$0")
# Absolute path this script
SCRIPTPATH=$(dirname "$SCRIPT")

# file will be put in the current working directory
local_file_dir="${SCRIPTPATH}/../"

function main(){

    validate_arguments "$@"

    local landscape=$1
    local sid=$2
    
    check_jq_installed

    check_file_exists ${target_json}

    local storage_account_name=$(read_json .saplibrary.storage_account_name)
    local container_name="sapsystem"
    local remote_file_name="${landscape}_${sid}.json"
    # The path of remote file can be updated based on actual needs
    local remote_file_path="${landscape}/${sid}/${remote_file_name}"
    local local_file_path="${local_file_dir}${remote_file_name}"

    json_download ${local_file_path} ${storage_account_name} ${container_name} ${remote_file_path}
}

function validate_arguments(){

    if [ "$#" -ne 2 ]; then
        printf "%s\n" "ERROR: Both LANDSCAPE and SID should be specified. Usage example: util/download_input.sh PROD HN1" >&2
        exit 1
    fi
}

function read_json(){

    local key="$1"
    local value=$(cat ${target_json} | jq -r "${key}")
	
    echo $value
}

function check_file_exists(){

    local file_path="$1"
    
    if [ ! -f "${file_path}" ]; then
        printf "%s\n" "ERROR: File ${file_path} does not exist. Please follow guidance to recover it" >&2
        # TODO: create a guidance about file/env recovery
        exit 1
    fi
}

function check_jq_installed(){

    local cmd="jq"
    local advice="Try: https://stedolan.github.io/jq/download/"

    # disable exit on error throughout this section as it's designed to fail
    # when cmd is not installed
    set +e
    local is_cmd_installed
    command -v "${cmd}" > /dev/null
    is_cmd_installed=$?
    set -e
    
    local error="This script depends on the '${cmd}' command being installed"
    # append advice if any was provided
    if [ ${is_cmd_installed} != 0 ]; then
        error="${error} (${advice})"
        printf "%s\n" "ERROR: ${error}" >&2
        exit 1
    fi
}

function json_download(){
    
    local local_file_path=$1
    local storage_account_name=$2
    local container_name=$3
    local remote_file_path=$4

    az login --identity > /dev/null
    
    printf "%s\n" "Check if ${remote_file_path} exists in storage accounts"

    remote_state_exists=$(az storage blob exists -c ${container_name} --name ${remote_file_path} --account-name ${storage_account_name} | jq -r .exists)
    if [ $remote_state_exists = true ]; then
        printf "%s\n" "INFO: remote file ${remote_file_path} exists"
    else
        printf "%s\n" "ERROR: remote file ${remote_file_path} does not exist. storage account name = ${storage_account_name}; container name = ${container_name}" >&2
        exit 1
    fi

    printf "%s\n" "Start downloading file ${remote_file_path}:"

    local cmd="az storage blob download --container-name ${container_name} --file ${local_file_path} --name ${remote_file_path} --account-name ${storage_account_name} --output none"
    eval "$cmd"
}

main "$@"
