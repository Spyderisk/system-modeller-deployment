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
# The script assumes that the deployment has used the default "docker compose up" method to start.
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
VERSION=0.7.3

# check docker compose
if command -v docker-compose &>/dev/null; then
    echo "[INFO] docker-compose is available"
    DOCKER_COMPOSE_CMD="docker-compose"
    #docker-compose ps -q | xargs docker inspect --format '{{.Name}}' | sed 's/\///'
elif docker compose version &>/dev/null; then
    echo "[INFO] docker compose (plugin) is available"
    DOCKER_COMPOSE_CMD="docker compose"
    #docker compose ps --format '{{.Name}}'
else
    echo "[ERROR] cannot find docker compose"
    exit 1
fi

# function to get container name based on project and service
get_container_name() {
    docker_project=$1
    service_name=$2
    docker ps \
      --filter "label=com.docker.compose.project=${docker_project}" \
      --filter "label=com.docker.compose.service=${service_name}" \
      --format '{{.Names}}'
}

# Extract the relative path as the docker compose project name
PROJECT_NAME=$(basename "${PWD}")
echo "Project name: $PROJECT_NAME"

KEYCLOAK_CONTAINER=$(get_container_name $PROJECT_NAME "keycloak")
MONGO_CONTAINER=$(get_container_name $PROJECT_NAME "mongo")
SSM_CONTAINER=$(get_container_name $PROJECT_NAME "ssm")

echo "KEYCLOAK container: $KEYCLOAK_CONTAINER"
echo "MONGO DB container: $MONGO_CONTAINER"
echo "Spyderisk container: $SSM_CONTAINER"

# default backup folder name format
DEFAULT_BACKUP_FOLDER="./backup_$(date +%Y-%m-%d_%H-%M)"

#container_name=$(get_container_name myproject web)

# function to check if a docker container is running
is_container_running() {
    local container_name="$1"
    docker ps -q --filter "name=$container_name" | grep -q .
}

# fuction to check if container exists
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -wq "$1"
}

# function to create the backup folder
create_backup_folder() {
    if [ ! -d "${BACKUP_FOLDER}" ]; then
        mkdir -p "${BACKUP_FOLDER}"
        echo "[INFO] Backup folder created: ${BACKUP_FOLDER}"
    else
        echo "[INFO] Backup folder already exists: ${BACKUP_FOLDER}"
    fi
}

# function to export SSM model data
restore_ssm_models() {
    echo "[INFO] Restoring SSM models data..."

    if ! is_container_running "$SSM_CONTAINER"; then
        echo "[WARN] cannot find SSM container, skipping this part"
        return 1
    fi

    # check if the backup folder exists
    if [ ! -d "${BACKUP_FOLDER}" ]; then
        echo "[ERROR] Backup folder does not exist: ${BACKUP_FOLDER}"
        exit 1
    fi

    # stop SSM container
    echo "[INFO] Stopping SSM container..."
    $DOCKER_COMPOSE_CMD stop ssm

    # check if jena-tdb folder exists inside the backup folder
    if [ -d "${BACKUP_FOLDER}/jena-tdb" ]; then
        # Restore model data to jena-tdb
        docker cp "${BACKUP_FOLDER}/jena-tdb" "${SSM_CONTAINER}":/
        echo "[INFO] SSM models data restored to: jena-tdb"
    else
        echo "[WARN] jena-tdb folder does not exist inside the backup folder: ${BACKUP_FOLDER}"
        echo "[WARN] Skipping restore for SSM models"
    fi

    # check if knwolegebases folder exists inside the backup folder
    if [ -d "${BACKUP_FOLDER}/knowledgebases" ]; then
        # restore knowledgebases
        docker cp "${BACKUP_FOLDER}/knowledgebases" "${SSM_CONTAINER}":/opt/spyderisk/
        echo "[INFO] SSM knowledgebases data restored"
    else
        echo "[WARN] knowledgebases folder does not exist inside the backup folder: ${BACKUP_FOLDER}"
        echo "[INFO] Skipping restore for SSM knowledgebases"
    fi

    if [ -d "${BACKUP_FOLDER}/mnt/knowledgebases" ]; then
        cp -a "${BACKUP_FOLDER}/mnt/knowledgebases/." ./knowledgebases/
    fi

    echo "[INFO] Restarting SSM service ..."
    $DOCKER_COMPOSE_CMD start ssm
}

# function to backup SSM model data
backup_ssm_models() {
    echo "[INFO] Backing up SSM models data..."

    # stop SSM container
    echo "[INFO] Stopping SSM container..."
    $DOCKER_COMPOSE_CMD stop ssm

    # backup model data from jena-tdb
    docker cp "${SSM_CONTAINER}":/jena-tdb "${BACKUP_FOLDER}"
    echo "[INFO] SSM models data backed up to: ${BACKUP_FOLDER}"

    # backup knowledgebases data
    docker cp "${SSM_CONTAINER}":/opt/spyderisk/knowledgebases "${BACKUP_FOLDER}"
    mkdir -p "${BACKUP_FOLDER}/mnt"
    cp -a knowledgebases "${BACKUP_FOLDER}/mnt"
    echo "[INFO] SSM knowledgebases data backed up to: ${BACKUP_FOLDER}"

    echo "[INFO] Restarting SSM service ..."
    $DOCKER_COMPOSE_CMD start ssm
}

# function to export Keycloak realm data
restore_keycloak_realm() {
    if is_container_running $KEYCLOAK_CONTAINER; then
        echo "[INFO] Restoring Keycloak..."

        # copy realm data to container
        docker cp "${BACKUP_FOLDER}/ssm-realm.json" "${KEYCLOAK_CONTAINER}":"/tmp/ssm-realm.json"
        echo "[INFO] Keycloak realm data copied to container"

        # connect to the Keycloak container and execute import command
        docker exec -it "${KEYCLOAK_CONTAINER}" /bin/bash -c "/opt/keycloak/bin/kc.sh import --override true  --file  /tmp/ssm-realm.json"

        # delete realm backup file from the container
        docker exec -it "${KEYCLOAK_CONTAINER}" rm /tmp/ssm-realm.json
        echo "[INFO] Backup file from the container is now removed"
    else
        echo "[INFO] Keycloak container not found, skipping restore..."
    fi
}

# function to backup Keycloak realm data
backup_keycloak_realm() {
    if [ -z "$KEYCLOAK_CONTAINER" ]; then
        echo "[INFO] Keycloak container name is empty, skipping backup ..."
        return
    fi

    if is_container_running $KEYCLOAK_CONTAINER; then
        echo "[INFO] Backing up keycloak ssm-realm..."

        # backup exported realm data to the backup folder
        docker exec -it "${KEYCLOAK_CONTAINER}" /bin/bash -c "/opt/keycloak/bin/kc.sh export --users realm_file --realm ssm-realm --file /tmp/ssm-realm.json"
        docker cp "${KEYCLOAK_CONTAINER}":"/tmp/ssm-realm.json" "${BACKUP_FOLDER}"

        # delete realm backup file from the container
        docker exec -it "${KEYCLOAK_CONTAINER}" rm /tmp/ssm-realm.json
    else
        echo "[INFO] Keycloak container not running, skipping backup..."
    fi
}

# function to export MongoDB databases
restore_mongo_databases() {
    echo "[INFO] Restoring MongoDB databases..."

    # check if the backup folder exists
    if [ ! -d "${BACKUP_FOLDER}/mongo" ]; then
        echo "[ERROR] Backup folder does not exist: ${BACKUP_FOLDER}/mongo"
        return
    fi

    # list of databases to restore
    local databases=("system-modeller" "ssmadaptor")

    for db in "${databases[@]}"; do

        # check if mongo folder exists inside the backup folder
        if [ -d "${BACKUP_FOLDER}/mongo/${db}" ]; then
            echo "[INFO] Restoring MongoDB database: ${db}"

            # copy db dump data to the container
            docker cp "${BACKUP_FOLDER}/mongo/${db}" "${MONGO_CONTAINER}":/tmp/${db}
            echo "[INFO] MongoDB database $db imported to container"

            # connect to the MongoDB container and dump databases
            docker exec -it "${MONGO_CONTAINER}" sh -c "mongorestore --drop --db ${db} /tmp/${db}"

            if [[ $? -eq 0 ]]; then
                echo "[INFO] Successfully restored ${db}"
                docker exec "${MONGO_CONTAINER}" rm -rf "/tmp/${db}"
                echo "[INFO] Cleaned up temporary restore $db files in container"
            else
                echo "[ERROR] Failed to restore ${db}"
            fi
        else
            echo "[WARN] databse folder $db does not exist"
        fi
    done
}

# function to backup MongoDB databases
backup_mongo_databases() {
    echo "[INFO] Backing up MongoDB databases..."

    # list of databases to back up
    local databases=("system-modeller" "ssmadaptor")
    mkdir -p "${BACKUP_FOLDER}/mongo"

    for db in "${databases[@]}"; do
        echo "[INFO] Backing up MongoDB database: ${db}"

        # run mongodump inside the container
        docker exec "${MONGO_CONTAINER}" sh -c "mongodump --db ${db} --out /tmp"

        if docker exec "${MONGO_CONTAINER}" test -e "/tmp/${db}"; then
            # copy data from the container to the host
            docker cp "${MONGO_CONTAINER}":/tmp/"${db}" "${BACKUP_FOLDER}/mongo/"

            echo "[INFO] ${db} backed up"

            # clean up temp files inside the container
            docker exec "${MONGO_CONTAINER}" rm -rf "/tmp/${db}"
            echo "[INFO] Removed /tmp/${db} from container"

        else
            echo "[WARN] No dump found for ${db}, skipping copy"
        fi
    done
}


echo "============================"
echo " Spyderisk Backup tool v${VERSION}"
echo "============================"

# parse command-line arguments
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
            echo "Usage: $0 {backup [-b BACKUP_FOLDER]|restore -b BACKUP_FOLDER}"
            exit 1
            ;;
    esac
    shift
done

# set default backup folder if not provided
if [ -z "${BACKUP_FOLDER}" ]; then
    BACKUP_FOLDER="${DEFAULT_BACKUP_FOLDER}"
fi

# check the mode and execute the corresponding functions
case "${MODE}" in
    backup)
        create_backup_folder
        backup_ssm_models
        backup_keycloak_realm
        backup_mongo_databases
        ;;
    restore)
        #check_containers_status
        restore_ssm_models
        restore_keycloak_realm
        restore_mongo_databases
        ;;
    *)
        echo "Usage: $0 {backup [-b BACKUP_FOLDER]|restore -b BACKUP_FOLDER}"
        exit 1
        ;;
esac

