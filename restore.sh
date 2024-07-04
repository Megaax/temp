#!/bin/bash

# Load the restore functions from the library
source ./backup_restore_lib.sh

# Main function
main() {
    local backup_dir="$1"
    local restore_dir="$2"
    local encryption_key="$3"

    # Validate parameters
    if ! validate_restore_parameters "$backup_dir" "$restore_dir" "$encryption_key"; then
        exit 1
    fi

    # Copy files to restore directory
    copy_files_to_restore_dir "$backup_dir" "$restore_dir"

    # Perform restore
    if ! perform_restore "$restore_dir" "$encryption_key"; then
        exit 1
    fi
}

# Execute main function with provided arguments
main "$@"
