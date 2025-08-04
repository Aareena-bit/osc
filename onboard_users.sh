#!/bin/bash

CSV_FILE="users.csv"

# Check if CSV file exists
if [ ! -f "users.csv" ]; then
    echo "ERROR: CSV file $CSV_FILE not found"
    exit 1
fi

# Function to check if user exists
user_exists() {
    local username="$1"
    id "$username" &>/dev/null
}

# Function to check if group exists
group_exists() {
    local groupname="$1"
    getent group "$groupname" &>/dev/null
}

# Function to manage group

manage_group() {
    local groupname="$1"
    
    # First validate the group name format
    if [[ ! "$groupname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "ERROR: Invalid group name '$groupname' - only letters, numbers, hyphens and underscores allowed"
        return 1
    fi

    # Check if group exists
    if getent group "$groupname" &>/dev/null; then
        echo "Group '$groupname' already exists"
        return 0
    fi

    # Try to create the group (with full command path)
    echo "Creating group '$groupname'..."
    if /usr/sbin/groupadd "$groupname"; then
        echo "Successfully created group '$groupname'"
        return 0
    else
        echo "ERROR: Failed to create group '$groupname' (are you running as root?)"
        return 1
    fi
}
# Function to manage user account
manage_user() {
    local username="$1"
    local shell="$2"
    local groupname="$3"
    
    if user_exists "$username"; then
        echo "User $username already exists. Updating shell to $shell..."
        if usermod -s "$shell" "$username"; then
            echo "Successfully updated shell for $username"
        else
            echo "ERROR: Failed to update shell for $username"
            return 1
        fi
    else
        echo "Creating new user $username with shell $shell..."
        if useradd -m -s "$shell" -G "$groupname" "$username"; then
            echo "Successfully created user $username"
        else
            echo "ERROR: Failed to create user $username"
            return 1
        fi
    fi
    return 0
}

# Function to ensure user is in group
ensure_group_membership() {
    local username="$1"
    local groupname="$2"
    
    if ! id -nG "$username" | grep -qw "$groupname"; then
        echo "Adding $username to group $groupname..."
        if usermod -aG "$groupname" "$username"; then
            echo "Successfully added $username to $groupname"
        else
            echo "ERROR: Failed to add $username to $groupname"
            return 1
        fi
    else
        echo "$username is already in group $groupname"
    fi
    return 0
}

echo "Starting user and group management..."
echo "==================================="

# Directory management
setup_home_directory() {
    local username="$1"
    local home_dir="/home/$username"
    
    if [ ! -d "$home_dir" ]; then
        log_message "ERROR: Home directory '$home_dir' doesn't exist"
        return 1
    fi

    log_message "Setting permissions for '$home_dir' to 700"
    if chmod 700 "$home_dir"; then
        log_message "Updated permissions for '$home_dir'"
    else
        log_message "ERROR: Failed to set permissions for '$home_dir'"
        return 1
    fi

    log_message "Verifying ownership of '$home_dir'"
    if chown "$username:$username" "$home_dir"; then
        log_message "Ownership set for '$home_dir'"
        return 0
    else
        log_message "ERROR: Failed to set ownership for '$home_dir'"
        return 1
    fi
}

create_project_directory() {
    local username="$1"
    local groupname="$2"
    local project_dir="$PROJECTS_BASE/$username"
    
    log_message "Creating project directory '$project_dir'"
    if mkdir -p "$project_dir"; then
        log_message "Directory '$project_dir' created"
        
        if chown "$username:$groupname" "$project_dir"; then
            log_message "Ownership set for '$project_dir'"
        else
            log_message "ERROR: Failed to set ownership for '$project_dir'"
            return 1
        fi
        
        if chmod 750 "$project_dir"; then
            log_message "Permissions set for '$project_dir'"
            return 0
        else
            log_message "ERROR: Failed to set permissions for '$project_dir'"
            return 1
        fi
    else
        log_message "ERROR: Failed to create directory '$project_dir'"
        return 1
    fi
}

# Process each line in the CSV file
while IFS=, read -r username groupname shell; do
   
    if [[ -z "$username" || "$username" == \#* ]]; then
        continue
    fi
    
    # Validate username
    if [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "ERROR: Invalid username '$username'"
        continue
    fi
    
    echo "Processing user: $username, group: $groupname"
    
    # Manage group 
    if ! manage_group "$groupname"; then
        continue
    fi
    
    # Manage user account
    if ! manage_user "$username" "$shell" "$groupname"; then
        continue
    fi
    
    # Ensure group membership (in case user existed already)
    if ! ensure_group_membership "$username" "$groupname"; then
        continue
    fi
    
    echo "----------------------"
done < "users.csv"

