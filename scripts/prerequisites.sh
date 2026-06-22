#!/bin/bash

# Prerequisite checks that must pass before installation starts.

PREREQ_ERRORS=()
PREREQ_WARNINGS=()

add_prereq_error() {
    PREREQ_ERRORS+=("$1")
}

add_prereq_warning() {
    PREREQ_WARNINGS+=("$1")
}

check_required_command() {
    local command_name="$1"
    local package_name="${2:-$command_name}"

    if ! command -v "$command_name" &>/dev/null; then
        add_prereq_error "Missing command '$command_name'. Install it with: sudo apt-get install -y $package_name"
    fi
}

check_prerequisite_commands() {
    check_required_command "bash" "bash"
    check_required_command "sudo" "sudo"
    check_required_command "apt-get" "apt"
    check_required_command "dpkg" "dpkg"
    check_required_command "jq" "jq"
    check_required_command "curl" "curl"
    check_required_command "wget" "wget"
    check_required_command "gpg" "gnupg"
    check_required_command "lsb_release" "lsb-release"
}

check_sudo_access() {
    if ! command -v sudo &>/dev/null; then
        return
    fi

    print_status "Checking sudo access..."
    if ! sudo -v; then
        add_prereq_error "Sudo access is required for package installation. Make sure your user can run sudo, then retry."
    fi
}

check_apt_state() {
    if ! command -v apt-get &>/dev/null; then
        return
    fi

    print_status "Checking apt/dpkg state..."

    if pgrep -x 'apt|apt-get|dpkg' &>/dev/null; then
        add_prereq_error "Another apt/dpkg process is running. Let it finish, then retry setup."
        return
    fi

    if ! sudo dpkg --audit >/tmp/setup-dev-env-dpkg-audit.txt 2>&1; then
        add_prereq_error "dpkg reports package database problems. Review: /tmp/setup-dev-env-dpkg-audit.txt"
    elif [ -s /tmp/setup-dev-env-dpkg-audit.txt ]; then
        add_prereq_error "dpkg has partially installed packages. Run: sudo dpkg --configure -a"
    fi

    if ! sudo apt-get check >/tmp/setup-dev-env-apt-check.txt 2>&1; then
        add_prereq_error "apt dependency check failed. Review /tmp/setup-dev-env-apt-check.txt, then try: sudo apt-get -f install"
    fi
}

check_network_access() {
    print_status "Checking network access..."

    if command -v curl &>/dev/null; then
        if ! curl -fsSL --connect-timeout 10 --max-time 20 https://github.com/ >/dev/null; then
            add_prereq_error "Network check failed: could not reach https://github.com/"
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -q --timeout=20 --spider https://github.com/; then
            add_prereq_error "Network check failed: could not reach https://github.com/"
        fi
    fi
}

check_supported_package_manager() {
    local package_manager
    package_manager=$(get_setting '.system.package_manager')
    package_manager="${package_manager:-apt-get}"

    if ! command -v "$package_manager" &>/dev/null; then
        add_prereq_error "Configured package manager '$package_manager' is not available."
    fi
}

print_prerequisite_report() {
    local item

    if [ ${#PREREQ_WARNINGS[@]} -gt 0 ]; then
        print_warning "Prerequisite warnings:"
        for item in "${PREREQ_WARNINGS[@]}"; do
            echo "  - $item"
        done
    fi

    if [ ${#PREREQ_ERRORS[@]} -gt 0 ]; then
        local old_pause_on_error="${PAUSE_ON_ERROR:-}"
        export PAUSE_ON_ERROR=false
        print_error "Setup prerequisites are not satisfied. No installation steps were run."
        if [ -n "$old_pause_on_error" ]; then
            export PAUSE_ON_ERROR="$old_pause_on_error"
        else
            unset PAUSE_ON_ERROR
        fi
        for item in "${PREREQ_ERRORS[@]}"; do
            echo "  - $item"
        done
        return 1
    fi

    print_success "Prerequisite checks passed"
    return 0
}

run_prerequisite_check() {
    local dry_run="${1:-false}"

    PREREQ_ERRORS=()
    PREREQ_WARNINGS=()

    print_status "Running prerequisite checks..."
    check_prerequisite_commands
    check_supported_package_manager

    if [ "$dry_run" = "true" ]; then
        add_prereq_warning "Dry-run mode: skipped sudo, apt state, and network checks"
    else
        check_sudo_access
        check_apt_state
        check_network_access
    fi

    print_prerequisite_report
}
