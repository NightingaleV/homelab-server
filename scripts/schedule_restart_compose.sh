#!/bin/bash

# ==============================================================================
# Docker Compose Restart Scheduler
# ==============================================================================
# This script allows you to schedule a restart of a docker-compose stack at a 
# specific time. It is designed to be run by a single cron job (e.g. every minute).
#
# Setup:
# 1. Add the following line to your crontab (run `crontab -e`):
#    * * * * * /mnt/nas/DockerServices/_homelab/scripts/schedule_restart_compose.sh run >> /var/log/docker_scheduler.log 2>&1
#
# Usage:
#   ./schedule_restart_compose.sh schedule <path_to_stack> "<time_string>"
#
# Example:
#   ./schedule_restart_compose.sh schedule ../admin/network_proxy "tomorrow 07:00"
# ==============================================================================

SCHEDULE_FILE="${HOME}/.docker_restart_queue"

# Determine script directory to find repo root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$REPO_ROOT/logs/time_script.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Ensure schedule file exists
if [ ! -f "$SCHEDULE_FILE" ]; then
    touch "$SCHEDULE_FILE"
fi


log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

usage() {
    echo "Usage:"
    echo "  Schedule a restart: $0 schedule <path_to_compose_dir> \"<date_time_string>\""
    echo "  Process queue (cron): $0 run"
    echo ""
    echo "Examples:"
    echo "  $0 schedule ../admin/network_proxy \"tomorrow 07:00\""
    echo "  $0 schedule /path/to/service \"2024-01-01 12:00\""
}

resolve_path() {
    local target="$1"
    if [ -d "$target" ]; then
        cd "$target" && pwd
    else
        echo ""
    fi
}

schedule_restart() {
    local target_dir="$1"
    local time_str="$2"

    # Resolve absolute path
    local abs_path
    abs_path=$(resolve_path "$target_dir")

    if [ -z "$abs_path" ]; then
        echo "Error: Directory not found: $target_dir"
        exit 1
    fi

    if [ ! -f "$abs_path/docker-compose.yml" ] && [ ! -f "$abs_path/docker-compose.yaml" ]; then
        echo "Error: No docker-compose.yml found in $abs_path"
        exit 1
    fi

    # Convert time to epoch
    local target_epoch
    target_epoch=$(date -d "$time_str" +%s 2>/dev/null)

    if [ -z "$target_epoch" ]; then
        echo "Error: Invalid date format '$time_str'"
        echo "Try formats like 'tomorrow 07:00', 'next friday', '2024-12-31 23:59'"
        exit 1
    fi

    # Check if date is in the past
    local current_epoch
    current_epoch=$(date +%s)
    if [ "$target_epoch" -le "$current_epoch" ]; then
        echo "Warning: The specified time is in the past. It will run immediately on next cron execution."
    fi

    echo "$target_epoch|$abs_path" >> "$SCHEDULE_FILE"
    echo "Scheduled restart for stack at:"
    echo "  Path: $abs_path"
    echo "  Time: $(date -d @$target_epoch)"
    echo "  Timestamp: $target_epoch"
}

process_queue() {
    local current_epoch
    current_epoch=$(date +%s)
    
    # We use a temporary file to rewrite the schedule
    # This separates tasks to run NOW from tasks to keep for LATER
    local temp_schedule
    temp_schedule=$(mktemp)
    
    local tasks_to_run_file
    tasks_to_run_file=$(mktemp)

    # Read the schedule file
    while IFS='|' read -r scheduled_epoch path; do
        # Skip empty lines
        if [ -z "$scheduled_epoch" ] || [ -z "$path" ]; then continue; fi

        if [ "$current_epoch" -ge "$scheduled_epoch" ]; then
            # Add to run list
            echo "$path" >> "$tasks_to_run_file"
        else
            # Keep in schedule
            echo "$scheduled_epoch|$path" >> "$temp_schedule"
        fi
    done < "$SCHEDULE_FILE"

    # Atomically update the schedule file to remove tasks we are about to run
    mv "$temp_schedule" "$SCHEDULE_FILE"

    # Now execute the tasks
    if [ -s "$tasks_to_run_file" ]; then
        while read -r path; do
            log "Starting scheduled restart for $path" | tee -a "$LOG_FILE"
            
            if [ -d "$path" ]; then
                # Run in subshell to not affect script working directory
                (
                    cd "$path" || exit
                    log "Executing: docker compose restart"
                    if docker compose restart; then
                        log "SUCCESS: Restarted $path" | tee -a "$LOG_FILE"
                    else
                        log "ERROR: Failed to restart $path" | tee -a "$LOG_FILE"
                    fi
                )
            else
                log "ERROR: Directory not found during execution: $path" | tee -a "$LOG_FILE"
            fi
        done < "$tasks_to_run_file"
    fi

    rm "$tasks_to_run_file"
}

# Main logic
case "$1" in
    schedule)
        if [ $# -lt 3 ]; then
            usage
            exit 1
        fi
        schedule_restart "$2" "$3"
        ;;
    run)
        process_queue
        ;;
    *)
        usage
        exit 1
        ;;
esac
