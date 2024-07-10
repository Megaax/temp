#!/bin/bash

# Function to validate input parameters
validate_backup_parameters() {
    local source_dir="$1"
    local dest_dir="$2"
    local encryption_key="$3"
    local num_days="$4"

    if [[ $# -ne 4 ]]; then
        printf "Error: Invalid number of parameters\n" >&2
        printf "Usage: <source_dir> <dest_dir> <encryption_key> <num_days>\n" >&                                                                                                                                                                                                                                                                                                                                       2
        return 1
    fi

    if [[ ! -d "$source_dir" ]]; then
        printf "Error: Source directory '%s' does not exist\n" "$source_dir" >&2
        return 1
    fi

    if [[ ! -d "$dest_dir" ]]; then
        printf "Error: Destination directory '%s' does not exist\n" "$dest_dir"                                                                                                                                                                                                                                                                                                                                        >&2
        return 1
    fi

    if ! [[ "$num_days" =~ ^[0-9]+$ ]]; then
        printf "Error: Number of days '%s' is not a valid number\n" "$num_days"                                                                                                                                                                                                                                                                                                                                        >&2
        return 1
    fi

    return 0
}

# Function to perform backup
backup() {
    local source_dir="$1"
    local dest_dir="$2"
    local encryption_key="$3"
    local num_days="$4"
    local remote_server="ubuntu@54.227.100.44:/home/ubuntu/backups"
    local current_date formatted_date backup_subdir

    current_date=$(date '+%Y-%m-%d_%H-%M-%S')
    formatted_date=$(echo "$current_date" | sed 's/[[:space:]:]/_/g')
    backup_subdir="$dest_dir/$formatted_date"

    mkdir -p "$backup_subdir"


        # Check for modified files in the source directory itself
    modified_files=$(find "$source_dir" -maxdepth 1 -type f -mtime -"$num_days")
    if [[ -n "$modified_files" ]]; then
        tar_file="$backup_subdir/${source_dir##*/}_$formatted_date.tgz"

        # Create a tar.gz file with the modified files directly
        tar -czvf "$tar_file" -C "$source_dir" $(echo "$modified_files" | xargs -n1 basename) || {
            echo "Error: Failed to create tarball for modified files in $source_dir"
        }

        if [[ -f "$tar_file" ]]; then
            gpg --batch --yes --passphrase "$encryption_key" -c "$tar_file"
            rm "$tar_file"
        fi
    else
        echo "No modified files found in $source_dir"
    fi




    shopt -s nullglob
    for dir in "$source_dir"/*/; do
        dir="${dir%/}"
        dir_name=$(basename "$dir")
        tar_file="$backup_subdir/${dir_name}_$formatted_date.tgz"

        # Check if there are any modified files in the directory
        modified_files=$(find "$dir" -type f -mtime -"$num_days")

        if [[ -n "$modified_files" ]]; then
            # Create a temporary directory to hold the modified files
            temp_dir="$backup_subdir/$dir_name"
            mkdir -p "$temp_dir"

            # Copy each modified file to the temporary directory, preserving the                                                                                                                                                                                                                                                                                                                                        directory structure
            while IFS= read -r file; do
                target="$temp_dir/$(basename "$file")"
                cp "$file" "$target"
            done <<< "$modified_files"

            # Create a tar.gz file with the temporary directory containing only                                                                                                                                                                                                                                                                                                                                        modified files
            tar -czvf "$tar_file" -C "$backup_subdir" "$dir_name" || {
                echo "Error: Failed to create tarball for $dir"
                continue
            }

            # Encrypt and remove the original tar file
            if [[ -f "$tar_file" ]]; then
                gpg --batch --yes --passphrase "$encryption_key" -c "$tar_file"
                rm "$tar_file"
            fi
        else
            echo "No modified files found in $dir"
        fi
       # rm -r "$temp_dir"
    done
    shopt -u nullglob

    # Backup all encrypted files directly under the main backup directory
    all_files_tar="$backup_subdir/${source_dir##*/}_$formatted_date.tar"
    all_files_gz="$all_files_tar.gz"

    echo "Adding files to $all_files_tar:"
    find "$backup_subdir" -maxdepth 1 -type f -name '*.gpg' -print0 | \
        tar --null --transform='s|^.*/||' -cf "$all_files_tar" --files-from - ||                                                                                                                                                                                                                                                                                                                                        {
        echo "Error: Failed to create all_files_tar"
    }

    # Check if any files were added to the all_files tar file
    if [[ -f "$all_files_tar" ]]; then
        echo "Files added to $all_files_tar:"
        tar -tvf "$all_files_tar"

        # Compress the tar file using gzip and delete the tar file
        gzip "$all_files_tar" #&& rm "$all_files_tar"

        # Encrypt the compressed tar.gz file
        if [[ -f "$all_files_gz" ]]; then
            gpg --batch --yes --passphrase "$encryption_key" -c "$all_files_gz"
            rm "$all_files_gz"
        
        fi
        find "$backup_subdir" -maxdepth 1 -type f -name '*.gpg' -not -name "${source_dir##*/}_$formatted_date.tar.gz.gpg" -exec rm {} \;

        # Remove all temporary directories created for individual backups
        for temp_dir in "$backup_subdir"/*/; do
            rm -rf "$temp_dir"
        done
    fi

    printf "Backup completed successfully.\n"
    return 0
}

# Function to validate restore parameters
validate_restore_parameters() {
    if [[ $# -ne 3 ]]; then
        printf "Error: Invalid number of parameters\n" >&2
        printf "Usage: $0 <backup_dir> <restore_dir> <encryption_key>\n" >&2
        return 1
    fi

    if [[ ! -d "$1" ]]; then
        printf "Error: Backup directory '%s' does not exist\n" "$1" >&2
        return 1
    fi

    if [[ ! -d "$2" ]]; then
        printf "Error: Restore directory '%s' does not exist\n" "$2" >&2
        return 1
    fi

    return 0
}

# Function to copy files from backup to restore directory
copy_files_to_restore_dir() {
    local backup_dir="$1"
    local restore_dir="$2"

    # Copy all files from BACKUP_DIR to RESTORE_DIR
    cp -r "$backup_dir"/* "$restore_dir/"
}

# Function to decrypt and restore files
perform_restore() {
    local restore_dir="$1"
    local encryption_key="$2"
    local produced_files=()

    shopt -s nullglob
    for file in "$restore_dir"/*; do
        if [[ -f "$file" && "$file" =~ \.gpg$ ]]; then
            decrypted_file="${file%.gpg}"
            gpg --batch --yes --passphrase "$encryption_key" -o "$decrypted_file" -d "$file"
            if [[ $? -eq 0 && -f "$decrypted_file" ]]; then
                tar -xvf "$decrypted_file" -C "$restore_dir"
                rm "$decrypted_file"  # Remove decrypted file after extraction
                rm "$file"  # Remove original .gpg file
		produced_files+=("basename $decrypted_file")
            else
                echo "Error: Failed to decrypt $file"
            fi
        fi
    done
    shopt -u nullglob

    # Process newly produced files recursively
    if [[ ${#produced_files[@]} -gt 0 ]]; then
        perform_restore "$restore_dir" "$encryption_key"
    fi

    printf "Restore completed successfully.\n"
}

