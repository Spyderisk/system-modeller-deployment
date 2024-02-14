#!/bin/bash
#########################################################################
##
## © University of Southampton IT Innovation Centre, 2024
##
## Copyright in this software belongs to University of Southampton
## IT Innovation Centre, Highfield Campus, Southampton, SO17 1BJ, UK.
##
## This software may not be used, sold, licensed, transferred, copied
## or reproduced in whole or in part in any manner or form or in or
## on any media by any person other than in accordance with the terms
## of the Licence Agreement supplied with the software, or otherwise
## without the prior written consent of the copyright owners.
##
## This software is distributed WITHOUT ANY WARRANTY, without even the
## implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
## PURPOSE, except where stated in the Licence Agreement supplied with
## the software.
##
##      Created By:             Panos Melas
##      Created Date:           2024-01-15
##      Created for Project :   Cyberkit4SME
##
#########################################################################

# A Spyderisk tool to make backup and restore Spyderisk deployment contents
#
# The script assumes that the deployment has used the default "docker-compose up" method to start.
# The SSM container is stopped for both backup and restore operations.
# At the end of the process, the container is restarted.
#
# Example how to backup Spyderisk:
# ./backup_spyderisk.sh backup
#
# Example how to restore a backup:
# ./backup_spyderisk.sh restore -b backup_2024-01-09_13-14
#

#set -euo pipefail

# tool version
VERSION=0.3

# Fixed container names
SSM_DEPLOYMENT_BASENAME="${PWD##*/}"
KEYCLOAK_CONTAINER="${SSM_DEPLOYMENT_BASENAME}_keycloak_1"
MONGO_CONTAINER="${SSM_DEPLOYMENT_BASENAME}_mongo_1"
SSM_CONTAINER="${SSM_DEPLOYMENT_BASENAME}_ssm_1"

# Default backup folder name format
DEFAULT_BACKUP_FOLDER="./backup_$(date +%Y-%m-%d_%H-%M)"

# Function to check if a Docker container is running
is_container_running() {
    local container_name="$1"
    docker ps -q --filter "name=$container_name" | grep -q .
}

# Function to check if all required containers are running
check_containers_status() {
    if ! is_container_running "$KEYCLOAK_CONTAINER" || \
       ! is_container_running "$MONGO_CONTAINER" || \
       ! is_container_running "$SSM_CONTAINER"; then
        echo "Error: Not all required containers are running."
        exit 1
    fi
}

# Function to create the backup folder
create_backup_folder() {
    if [ ! -d "${BACKUP_FOLDER}" ]; then
        mkdir -p "${BACKUP_FOLDER}"
        echo "Backup folder created: ${BACKUP_FOLDER}"
    else
        echo "Backup folder already exists: ${BACKUP_FOLDER}"
    fi
}

# Function to export SSM model data
restore_ssm_models() {
    echo "Restoring SSM models data..."

    # Check if the backup folder exists
    if [ ! -d "${BACKUP_FOLDER}" ]; then
        echo "Error: Backup folder does not exist: ${BACKUP_FOLDER}"
        exit 1
    fi

    # Stop SSM container
    echo "Stopping SSM container..."
    docker-compose stop ssm

    # Check if jena-tdb folder exists inside the backup folder
    if [ -d "${BACKUP_FOLDER}/jena-tdb" ]; then
        # Restore model data to jena-tdb
        docker cp "${BACKUP_FOLDER}/jena-tdb" "${SSM_CONTAINER}":/
        echo "SSM models data restored to: jena-tdb"
    else
        echo "Warning: jena-tdb folder does not exist inside the backup folder: ${BACKUP_FOLDER}"
        echo "Skipping restore for SSM models"
    fi

    # Check if knwolegebases folder exists inside the backup folder
    if [ -d "${BACKUP_FOLDER}/knowledgebases" ]; then
        # Restore knowledgebases
        docker cp "${BACKUP_FOLDER}/knowledgebases" "${SSM_CONTAINER}":/
        echo "SSM knowledgebases data restored"
    else
        echo "Warning: knowledgebases folder does not exist inside the backup folder: ${BACKUP_FOLDER}"
        echo "Skipping restore for SSM knowledgebases"
    fi

    echo "Restarting SSM service ..."
    docker-compose start ssm
}

# Function to backup SSM model data
backup_ssm_models() {
    echo "Backing up SSM models data..."

    # Create the backup folder
    create_backup_folder

    # Stop SSM container
    echo "Stopping SSM container..."
    docker-compose stop ssm

    # Backup model data from jena-tdb
    docker cp "${SSM_CONTAINER}":/jena-tdb "${BACKUP_FOLDER}"
    echo "SSM models data backed up to: ${BACKUP_FOLDER}"

    # Backup knowledgebases data
    docker cp "${SSM_CONTAINER}":/knowledgebases "${BACKUP_FOLDER}"
    echo "SSM knowledgebases data backed up to: ${BACKUP_FOLDER}"

    echo "Restarting SSM service ..."
    docker-compose start ssm
}

# Function to export Keycloak realm data
restore_keycloak_realm() {
    echo "Restoring Keycloak realm data..."

    # Check if the backup folder exists
    if [ ! -d "${BACKUP_FOLDER}" ]; then
        echo "Error: Backup folder does not exist: ${BACKUP_FOLDER}"
        exit 1
    fi

    # Check if realm file exists inside the backup folder
    if [ ! -f "${BACKUP_FOLDER}/ssm-realm.json" ]; then
        echo "Warning: realm file does not exist inside the backup folder: ${BACKUP_FOLDER}"
        echo "Skipping restore for keycloak ssm-realm."
        return
    fi

    # Copy realm data to container
    docker cp "${BACKUP_FOLDER}/ssm-realm.json" "${KEYCLOAK_CONTAINER}":"/tmp/ssm-realm.json"
    echo "Keycloak realm data copied to container"

    # Connect to the Keycloak container and execute import command
    docker exec -it "${KEYCLOAK_CONTAINER}" /bin/bash -c "/opt/keycloak/bin/kc.sh import --override true  --file  /tmp/ssm-realm.json"

    # Delete realm backup file from the container
    docker exec -it "${KEYCLOAK_CONTAINER}" rm /tmp/ssm-realm.json
    echo "Backup file from the container is now removed"
}

# Function to backup Keycloak realm data
backup_keycloak_realm() {
    echo "Backing up Keycloak realm data..."

    # Create the backup folder
    create_backup_folder

    # Backup exported realm data to the backup folder
    docker exec -it "${KEYCLOAK_CONTAINER}" /bin/bash -c "/opt/keycloak/bin/kc.sh export --users realm_file --realm ssm-realm --file /tmp/ssm-realm.json"
    docker cp "${KEYCLOAK_CONTAINER}":"/tmp/ssm-realm.json" "${BACKUP_FOLDER}"
    echo "Keycloak realm data backed up to: ${BACKUP_FOLDER}"

    # Delete realm backup file from the container
    docker exec -it "${KEYCLOAK_CONTAINER}" rm /tmp/ssm-realm.json
    echo "Backup file from the container is now removed"
}

# Function to export MongoDB databases
restore_mongo_databases() {
    echo "Restoring MongoDB databases..."

    # Check if the backup folder exists
    if [ ! -d "${BACKUP_FOLDER}" ]; then
        echo "Error: Backup folder does not exist: ${BACKUP_FOLDER}"
        exit 1
    fi

    # Check if mongo folder exists inside the backup folder
    if [ ! -d "${BACKUP_FOLDER}/system-modeller" ]; then
        echo "Warning: system-modeller folder does not exist inside the backup folder: ${BACKUP_FOLDER}"
        echo "Skipping restore for MongoDB databases."
        return
    fi

    # Copy db dump data to the container
    docker cp "${BACKUP_FOLDER}/system-modeller" "${MONGO_CONTAINER}":/tmp/system-modeller
    echo "MongoDB databases imported to container"

    # Connect to the MongoDB container and dump databases
    docker exec -it "${MONGO_CONTAINER}" /bin/bash -c "mongorestore --db system-modeller /tmp/system-modeller"

    # Delete backup data from the container
    docker exec -it "${MONGO_CONTAINER}" rm -rf /tmp/system-modeller
    echo "Backup files are now removed from the container"
}

# Function to backup MongoDB databases
backup_mongo_databases() {
    echo "Backing up MongoDB databases..."

    # Create the backup folder
    create_backup_folder

    # Backup db dump data to the backup folder
    docker exec -it "${MONGO_CONTAINER}" /bin/bash -c "mongodump --db system-modeller --out /tmp"
    docker cp "${MONGO_CONTAINER}":/tmp/system-modeller "${BACKUP_FOLDER}"
    echo "MongoDB databases backed up to: ${BACKUP_FOLDER}"

    # Delete backup data from the container
    docker exec -it "${MONGO_CONTAINER}" rm -rf /tmp/system-modeller
    echo "Backup files are now removed from the container"
}

echo "============================"
echo " Spyderisk Backup tool v${VERSION}"
echo "============================"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--backup-folder)
            shift
            BACKUP_FOLDER="$1"
            ;;
        backup|restore)
            MODE="$1"
            ;;
        *)
            echo "Invalid argument: $1"
            exit 1
            ;;
    esac
    shift
done

# Set default backup folder if not provided
if [ -z "${BACKUP_FOLDER}" ]; then
    BACKUP_FOLDER="${DEFAULT_BACKUP_FOLDER}"
fi

# Check the mode and execute the corresponding functions
case "${MODE}" in
    backup)
        check_containers_status
        backup_ssm_models
        backup_keycloak_realm
        backup_mongo_databases
        ;;
    restore)
        check_containers_status
        restore_ssm_models
        restore_keycloak_realm
        restore_mongo_databases
        ;;
    *)
        echo "Usage: $0 {backup [-b BACKUP_FOLDER]|restore -b BACKUP_FOLDER}"
        exit 1
        ;;
esac

