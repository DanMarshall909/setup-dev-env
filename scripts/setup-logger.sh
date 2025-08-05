#!/bin/bash

# Enhanced logging system for setup-dev-env
# Creates detailed, easily copyable logs for debugging

# Initialize logging system
init_setup_logging() {
    # Create log directory
    export SETUP_LOG_DIR="$HOME/.local/share/setup-dev-env/logs"
    mkdir -p "$SETUP_LOG_DIR"
    
    # Generate unique log file with timestamp
    export SETUP_LOG_FILE="$SETUP_LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
    export SETUP_SUMMARY_FILE="$SETUP_LOG_DIR/setup-summary-$(date +%Y%m%d-%H%M%S).log"
    
    # Create symlinks to latest logs
    ln -sf "$SETUP_LOG_FILE" "$SETUP_LOG_DIR/latest.log"
    ln -sf "$SETUP_SUMMARY_FILE" "$SETUP_LOG_DIR/latest-summary.log"
    
    # Initialize log files
    cat > "$SETUP_LOG_FILE" << EOF
================================================================================
Linux Development Environment Setup - Installation Log
================================================================================
Start Time: $(date)
Host: $(hostname)
User: $(whoami)
OS: $(lsb_release -d | cut -f2)
Architecture: $(uname -m)
Shell: $SHELL
Working Directory: $(pwd)
Command: $0 $*
================================================================================

EOF

    cat > "$SETUP_SUMMARY_FILE" << EOF
================================================================================
SETUP SUMMARY - Copy/Paste Friendly
================================================================================
Start Time: $(date)
Host: $(hostname)
User: $(whoami)  
OS: $(lsb_release -d | cut -f2)

EOF

    # Enable logging for all output
    export SETUP_LOGGING_ENABLED=true
    
    echo "📋 Logging initialized:"
    echo "   Full log: $SETUP_LOG_FILE"
    echo "   Summary:  $SETUP_SUMMARY_FILE"
    echo "   Latest:   $SETUP_LOG_DIR/latest.log"
    echo ""
}

# Enhanced logging functions
log_with_timestamp() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    if [ "$SETUP_LOGGING_ENABLED" = "true" ]; then
        echo "[$timestamp] [$level] $message" >> "$SETUP_LOG_FILE"
    fi
}

log_command() {
    local command="$1"
    local description="${2:-Command execution}"
    
    log_with_timestamp "CMD" "$description: $command"
    
    # Add to summary if it's a major command
    if [[ "$command" =~ (apt|snap|npm|curl|wget|git) ]]; then
        echo "🔧 $description: $command" >> "$SETUP_SUMMARY_FILE"
    fi
}

log_module_start() {
    local module_name="$1"
    log_with_timestamp "MODULE" "Starting installation: $module_name"
    echo "📦 INSTALLING: $module_name" >> "$SETUP_SUMMARY_FILE"
}

log_module_success() {
    local module_name="$1"
    log_with_timestamp "MODULE" "Successfully installed: $module_name"
    echo "✅ SUCCESS: $module_name" >> "$SETUP_SUMMARY_FILE"
}

log_module_failure() {
    local module_name="$1"
    local error="$2"
    log_with_timestamp "MODULE" "Failed to install: $module_name - $error"
    echo "❌ FAILED: $module_name - $error" >> "$SETUP_SUMMARY_FILE"
}

log_error_details() {
    local error_context="$1"
    local error_message="$2"
    
    log_with_timestamp "ERROR" "$error_context: $error_message"
    echo "" >> "$SETUP_SUMMARY_FILE"
    echo "🚨 ERROR in $error_context:" >> "$SETUP_SUMMARY_FILE"
    echo "   $error_message" >> "$SETUP_SUMMARY_FILE"
    echo "" >> "$SETUP_SUMMARY_FILE"
}

log_system_info() {
    local info_type="$1"
    local info_data="$2"
    
    log_with_timestamp "INFO" "$info_type: $info_data"
    echo "ℹ️  $info_type: $info_data" >> "$SETUP_SUMMARY_FILE"
}

# Finalize logging
finalize_setup_logging() {
    local exit_code="${1:-0}"
    local end_time="$(date)"
    
    cat >> "$SETUP_LOG_FILE" << EOF

================================================================================
Setup completed at: $end_time
Exit code: $exit_code
================================================================================
EOF

    cat >> "$SETUP_SUMMARY_FILE" << EOF

================================================================================
FINAL RESULT
================================================================================
End Time: $end_time
Exit Code: $exit_code
Result: $([ "$exit_code" -eq 0 ] && echo "SUCCESS ✅" || echo "FAILED ❌")

Log Files:
- Full Log: $SETUP_LOG_FILE
- Summary:  $SETUP_SUMMARY_FILE

Copy the content above to share with support or for debugging.
================================================================================
EOF

    echo ""
    echo "📋 Setup logging completed:"
    echo "   Exit code: $exit_code"
    echo "   Full log: $SETUP_LOG_FILE"
    echo "   Summary:  $SETUP_SUMMARY_FILE"
    echo ""
    echo "🔍 To view logs:"
    echo "   cat $SETUP_LOG_DIR/latest.log          # Full detailed log"
    echo "   cat $SETUP_LOG_DIR/latest-summary.log  # Copy/paste friendly summary"
    echo ""
    echo "📤 To share for debugging:"
    echo "   cat $SETUP_LOG_DIR/latest-summary.log | pbcopy  # macOS"
    echo "   cat $SETUP_LOG_DIR/latest-summary.log | xclip   # Linux"
    echo ""
}

# Override existing logging functions to use enhanced logging
if [ "$SETUP_LOGGING_ENABLED" = "true" ]; then
    # Backup original functions
    declare -f log_info > /dev/null && alias _orig_log_info=log_info
    declare -f log_error > /dev/null && alias _orig_log_error=log_error
    declare -f log_warning > /dev/null && alias _orig_log_warning=log_warning
    
    # Enhanced versions
    log_info() {
        log_with_timestamp "INFO" "$*"
        _orig_log_info "$*" 2>/dev/null || echo "[INFO] $*"
    }
    
    log_error() {
        log_with_timestamp "ERROR" "$*"
        _orig_log_error "$*" 2>/dev/null || echo "[ERROR] $*"
    }
    
    log_warning() {
        log_with_timestamp "WARN" "$*"
        _orig_log_warning "$*" 2>/dev/null || echo "[WARNING] $*"
    }
fi

# Export functions for use in other scripts
export -f log_with_timestamp
export -f log_command
export -f log_module_start
export -f log_module_success
export -f log_module_failure
export -f log_error_details
export -f log_system_info
export -f finalize_setup_logging