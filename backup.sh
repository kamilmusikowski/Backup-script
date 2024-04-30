#!/bin/bash

config_file="./config.txt"

log_message() {
    local timestamp=$(date +'%Y/%m/%d %H:%M:%S')
    echo -e "$timestamp $1" >> "$log_file"
}

send_email(){
    local subject="$1"
    local body=$(tail -n 1 "$log_file")

    echo "$body" | mail -s "$subject" "$recipient"
}

# Validate configuration file.
validate_config() {
    for var in log_file local_dir remote_dir archive_dir retention_days recipient remote_host; do
        if [ -z "${!var}" ]; then
            log_message "Error: Missing configuration for $var"
            send_email "Backup script configuration failure"
            exit 1 
        fi
    done
}

# Load configuration file if it exists
initialize() {
    if [ -f "$config_file" ]; then
        source "$config_file"
        log_message "Configuration file loaded."
    else
        log_message "Error: Configuration file not found."
        send_email "Backup script configuration failure"
        exit 1
    fi

    validate_config

    # Create the log file if it does not exist
    if [ ! -f "$log_file" ]; then
        touch "$log_file"
        log_message "Warning: Log file not found. Creating log file $log_file."
    fi
}

# Run basic tests and then backup
perform_backup() {
    if ! nc -z -w5 "$remote_host" 22; then
        log_message "Error: Cannot connect to $remote_host on port 22"
        return 1
    fi

    if [ ! -d "$local_dir" ]; then
        log_message "Warning: Backup directory not found. Creating backup directory."
        mkdir -p "$local_dir"
    fi

    if ! ssh "$remote_user@$remote_host" "test -d $remote_dir"; then
        log_message "Error: Remote directory $remote_dir does not exist"
        return 1
    fi

    rsync -avz --delete --log-file="$log_file" \
        "$remote_user@$remote_host:$remote_dir" "$local_dir" || {
            log_message "Error: Backup failed"
            return 1
        }


    log_message "Backup completed"
    send_email "Backup script finished"
}

# Create .tar.gz archive
archive_backup() {
    if [ ! -d "$archive_dir" ]; then
        log_message "Warning: Archive directory not found. Creating archive directory $archive_dir."
        mkdir -p "$archive_dir"
    fi

    if ! tar -czf "$archive_dir/backup_$(date +"%Y-%m-%d-%H-%M-%S").tar.gz" -C "$local_dir" . >> $log_file 2>&1; then
        log_message "Archive creation failed"
        send_email "Archive script failed"
        return 1
    fi

    log_message "Archive creation finished"
}

# Delete archives older than retention days specified.
delete_old_archives() {
    log_message "Deleting archives older than $retention_days days."

    find "$archive_dir" -maxdepth 1 -type f -mtime +$retention_days -exec \
    sh -c '{ echo "Deleting file: $1"; rm -f "$1" 2>&1; } >> $log_file' sh {} \;
}


initialize
perform_backup
if [ $? -ne 0 ]; then
    send_email "Backup script failed"
fi
