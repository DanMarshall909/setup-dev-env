#!/bin/bash

# Logging layer for setup scripts

# Get logging settings
get_logging_setting() {
    local key=$1
    local settings_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/configs/settings.json"
    if [ -f "$settings_file" ] && command -v jq &> /dev/null; then
        jq -r ".logging.$key" "$settings_file" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Initialize logging
init_logging() {
    # Get log directory and create if needed
    local log_dir=$(get_logging_setting "directory")
    if [ -z "$log_dir" ]; then
        log_dir="$HOME/.local/share/setup-dev-env/logs"
    fi
    
    # Expand ~ to $HOME
    log_dir="${log_dir/#\~/$HOME}"
    
    # Create log directory if it doesn't exist
    mkdir -p "$log_dir"
    
    # Set up log file with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local log_file="$log_dir/setup_${timestamp}.log"
    
    # Export for use in other scripts
    export SETUP_LOG_FILE="$log_file"
    export SETUP_LOG_DIR="$log_dir"
    
    # Get log level
    local log_level=$(get_logging_setting "level")
    export SETUP_LOG_LEVEL="${log_level:-INFO}"
    
    # Get whether to log to console
    local log_to_console=$(get_logging_setting "console")
    export SETUP_LOG_CONSOLE="${log_to_console:-true}"
    
    # Create symlink to latest log
    ln -sf "$log_file" "$log_dir/latest.log"
    
    # Log initialization
    log_info "Logging initialized"
    log_info "Log file: $log_file"
    log_info "Log level: $SETUP_LOG_LEVEL"
}

# Get log level priority
get_log_level_priority() {
    case $1 in
        "DEBUG") echo 0 ;;
        "INFO") echo 1 ;;
        "WARNING") echo 2 ;;
        "ERROR") echo 3 ;;
        *) echo 1 ;;
    esac
}

# Check if should log based on level
should_log() {
    local msg_level=$1
    local current_level=${SETUP_LOG_LEVEL:-INFO}
    
    local msg_priority=$(get_log_level_priority "$msg_level")
    local current_priority=$(get_log_level_priority "$current_level")
    
    [ $msg_priority -ge $current_priority ]
}

# Core logging function
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
    
    # Check if we should log this level
    if ! should_log "$level"; then
        return
    fi
    
    # Format log message
    local log_entry="[$timestamp] [$level] [$caller] $message"
    
    # Write to log file if available
    if [ -n "$SETUP_LOG_FILE" ]; then
        echo "$log_entry" >> "$SETUP_LOG_FILE"
    fi
    
    # Also log to syslog if available
    if command -v logger &> /dev/null; then
        logger -t "setup-dev-env" -p "user.$level" "$message"
    fi
}

# Log functions for different levels
log_debug() {
    log_message "DEBUG" "$1"
}

log_info() {
    log_message "INFO" "$1"
}

log_warning() {
    log_message "WARNING" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

# Log command execution
log_command() {
    local command=$1
    log_info "Executing command: $command"
    
    # Execute command and capture output
    local output
    local exit_code
    
    if output=$($command 2>&1); then
        exit_code=$?
        log_debug "Command output: $output"
        log_info "Command completed successfully (exit code: $exit_code)"
        echo "$output"
        return $exit_code
    else
        exit_code=$?
        log_error "Command failed (exit code: $exit_code)"
        log_error "Command output: $output"
        echo "$output" >&2
        return $exit_code
    fi
}

# Log function entry and exit
log_function_start() {
    local function_name=$1
    shift
    local args="$@"
    log_debug "Entering function: $function_name($args)"
}

log_function_end() {
    local function_name=$1
    local exit_code=$2
    if [ "$exit_code" -eq 0 ]; then
        log_debug "Exiting function: $function_name (success)"
    else
        log_debug "Exiting function: $function_name (failed with code: $exit_code)"
    fi
}

# Log file operations
log_file_operation() {
    local operation=$1
    local file=$2
    local result=${3:-"success"}
    
    case $operation in
        "create")
            log_info "Created file: $file"
            ;;
        "modify")
            log_info "Modified file: $file"
            ;;
        "delete")
            log_info "Deleted file: $file"
            ;;
        "read")
            log_debug "Read file: $file"
            ;;
        *)
            log_info "File operation '$operation' on: $file ($result)"
            ;;
    esac
}

# Log package operations
log_package_operation() {
    local operation=$1
    local package=$2
    local version=${3:-""}
    
    case $operation in
        "install")
            if [ -n "$version" ]; then
                log_info "Installed package: $package (version: $version)"
            else
                log_info "Installed package: $package"
            fi
            ;;
        "remove")
            log_info "Removed package: $package"
            ;;
        "update")
            log_info "Updated package: $package"
            ;;
        "check")
            log_debug "Checked package: $package"
            ;;
        *)
            log_info "Package operation '$operation' on: $package"
            ;;
    esac
}

# Log configuration changes
log_config_change() {
    local config_type=$1
    local key=$2
    local old_value=${3:-"<not set>"}
    local new_value=$4
    
    # Mask sensitive values
    if [[ "$key" =~ (password|secret|token|key) ]]; then
        old_value="<masked>"
        new_value="<masked>"
    fi
    
    log_info "Configuration change: $config_type.$key changed from '$old_value' to '$new_value'"
}

# Log script execution
log_script_start() {
    local script_name=$1
    log_info "========================================="
    log_info "Starting script: $script_name"
    log_info "User: $(whoami)"
    log_info "Host: $(hostname)"
    log_info "Working directory: $(pwd)"
    log_info "========================================="
}

log_script_end() {
    local script_name=$1
    local exit_code=$2
    local duration=${3:-""}
    
    log_info "========================================="
    if [ "$exit_code" -eq 0 ]; then
        log_info "Script completed successfully: $script_name"
    else
        log_error "Script failed: $script_name (exit code: $exit_code)"
    fi
    if [ -n "$duration" ]; then
        log_info "Duration: $duration seconds"
    fi
    log_info "========================================="
}

# Create summary report
create_log_summary() {
    local log_file=${1:-$SETUP_LOG_FILE}
    local summary_file="${log_file%.log}_summary.txt"
    
    if [ ! -f "$log_file" ]; then
        log_error "Log file not found: $log_file"
        return 1
    fi
    
    {
        echo "Setup Log Summary"
        echo "================="
        echo "Log file: $log_file"
        echo "Generated: $(date)"
        echo ""
        
        echo "Statistics:"
        echo "-----------"
        echo "Total entries: $(wc -l < "$log_file")"
        echo "Errors: $(grep -c '\[ERROR\]' "$log_file" || echo 0)"
        echo "Warnings: $(grep -c '\[WARNING\]' "$log_file" || echo 0)"
        echo "Info: $(grep -c '\[INFO\]' "$log_file" || echo 0)"
        echo "Debug: $(grep -c '\[DEBUG\]' "$log_file" || echo 0)"
        echo ""
        
        echo "Installed Packages:"
        echo "------------------"
        grep "Installed package:" "$log_file" | sed 's/.*Installed package: /  - /' || echo "  None"
        echo ""
        
        echo "Configuration Changes:"
        echo "---------------------"
        grep "Configuration change:" "$log_file" | sed 's/.*Configuration change: /  - /' || echo "  None"
        echo ""
        
        echo "Errors:"
        echo "-------"
        grep '\[ERROR\]' "$log_file" | tail -10 || echo "  No errors"
        echo ""
        
        echo "Warnings:"
        echo "---------"
        grep '\[WARNING\]' "$log_file" | tail -10 || echo "  No warnings"
    } > "$summary_file"
    
    log_info "Created log summary: $summary_file"
    echo "$summary_file"
}

# Rotate logs
rotate_logs() {
    local max_logs=$(get_logging_setting "max_files")
    max_logs=${max_logs:-10}
    
    local log_dir=${SETUP_LOG_DIR:-"$HOME/.local/share/setup-dev-env/logs"}
    
    # Count log files
    local log_count=$(find "$log_dir" -name "setup_*.log" -type f | wc -l)
    
    if [ "$log_count" -gt "$max_logs" ]; then
        # Delete oldest logs
        local logs_to_delete=$((log_count - max_logs))
        find "$log_dir" -name "setup_*.log" -type f -printf '%T@ %p\n' | \
            sort -n | head -n "$logs_to_delete" | cut -d' ' -f2- | \
            while read -r file; do
                log_info "Rotating log: Deleting old log file $file"
                rm -f "$file"
                rm -f "${file%.log}_summary.txt"
            done
    fi
}

# Archive logs
archive_logs() {
    local archive_dir=$(get_logging_setting "archive_directory")
    if [ -z "$archive_dir" ]; then
        archive_dir="$HOME/.local/share/setup-dev-env/archives"
    fi
    
    # Expand ~ to $HOME
    archive_dir="${archive_dir/#\~/$HOME}"
    mkdir -p "$archive_dir"
    
    local log_dir=${SETUP_LOG_DIR:-"$HOME/.local/share/setup-dev-env/logs"}
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local archive_file="$archive_dir/setup_logs_$timestamp.tar.gz"
    
    # Create archive
    tar -czf "$archive_file" -C "$log_dir" .
    log_info "Archived logs to: $archive_file"
    
    # Clean up old logs after archiving
    find "$log_dir" -name "setup_*.log" -type f -mtime +7 -delete
    find "$log_dir" -name "setup_*_summary.txt" -type f -mtime +7 -delete
}

# Initialize logging if sourced directly
if [ -z "$SETUP_LOG_FILE" ]; then
    init_logging
fi