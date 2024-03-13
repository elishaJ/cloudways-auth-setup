#!/bin/bash

# Retrieve input variables
email="$EMAIL"
api_key="$API_KEY"
app_id="$APP_ID"
server_id="$SERVER_ID"

echo "Setting up SSH authentication for Cloudways server..."

dir=$(pwd)
key_path="$HOME/.ssh/bulk_project_ops"
BASE_URL="https://api.cloudways.com/api/v1"
qwik_api="https://us-central1-cw-automations.cloudfunctions.net"

# Fetch access token
get_token() {
    echo "Retrieving access token"
    response=$(curl -s -X POST --location "$BASE_URL/oauth/access_token" \
        -w "%{http_code}" \
        --header 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode 'email='$email'' \
        --data-urlencode 'api_key='$api_key'')

    http_code="${response: -3}"
    body="${response::-3}"

    if [ "$http_code" != "200" ]; then
        echo "Error: Failed to retrieve access token. Invalid credentials."
        exit
    else
        # Parse the access token and set expiry time to 10 seconds
        access_token=$(echo "$body" | jq -r '.access_token')
        expires_in=$(echo "$body" | jq -r '.expires_in')
        expiry_time=$(( $(date +%s) + $expires_in ))
        echo "Access token generated."
    fi
}

# Generate an SSH key for passwordless connection to Cloudways server
generate_SSH_key() {
    echo "Creating SSH key"
    ssh-keygen -b 2048 -t rsa -f "$key_path" -q -N "" #> /dev/null
    pub_key=$(<"$key_path.pub")
}

setup_SSH_keys() {
    # check_token_validity
    echo "Uploading SSH keys on Cloudways servers."
    task_id=($(curl -s --location "$qwik_api/auth" \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --header 'Authorization: Bearer '$access_token'' \
    --data-urlencode 'pub_key='"$pub_key" \
    --data-urlencode 'email='$email'' \
    --data-urlencode 'server_id='$server_id'' \
    | jq -r '.task_id'))
    if [ -z task_id ]; then
        echo "SSH keys set up failed."
    else
        echo "SSH key setup completed successfully"
        echo "Task ID = $task_id"
        # echo "::set-output name=task-id::$task_id"
        echo "task-id=$task_id" >> $GITHUB_OUTPUT
    fi
    
}

get_app_details() {
    echo "Fetching app info"
    apps_response=$(curl -s --location ''$qwik_api'/apps?server_id='$server_id'' \
        --header 'Authorization: Bearer '$access_token'')

    server_ip=$(echo "$apps_response" | jq -r '.apps[] | select(.id == "'$app_id'") | .server_ip')
    sys_user=$(echo "$apps_response" | jq -r '.apps[] | select(.id == "'$app_id'")| .sys_user')
    master_user=$(echo "$apps_response" | jq -r '.apps[] | select(.id == "'$app_id'") | .master_user')

    echo "server-ip=$server_ip" >> $GITHUB_OUTPUT
    echo "sys-user=$sys_user" >> $GITHUB_OUTPUT
    echo "master-user=$master_user" >> $GITHUB_OUTPUT
}

get_token
get_app_details
generate_SSH_key
setup_SSH_keys