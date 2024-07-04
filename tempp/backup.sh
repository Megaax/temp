#!/bin/bash

# Source the backup_restore_lib.sh file
source ./backup_restore_lib.sh

# Global variables
SOURCE_DIR="$1"
DEST_DIR="$2"
ENCRYPTION_KEY="$3"
NUM_DAYS="$4"

# Main function
main() {
    if ! validate_backup_parameters "$SOURCE_DIR" "$DEST_DIR" "$ENCRYPTION_KEY" "$NUM_DAYS"; then
        return 1
    fi

    if ! backup "$SOURCE_DIR" "$DEST_DIR" "$ENCRYPTION_KEY" "$NUM_DAYS"; then
        return 1
    fi

    return 0
}

# Execute main function
main "$@"