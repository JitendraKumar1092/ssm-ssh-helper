#!/bin/bash

cat << 'EOF' > ~/ssm-ssh-proxy.sh
#!/bin/bash
# filepath: ~/ssm-ssh-proxy.sh

NAME="$1"
REGION="ap-south-1"

# Lookup instance ID by Name tag
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text --region "$REGION")

if [ -z "$INSTANCE_ID" ]; then
  echo "No running instance found with Name tag: $NAME" >&2
  exit 1
fi

# Start SSM session as ssm-user (not SSH)
exec aws ssm start-session --target "$INSTANCE_ID" --region "$REGION"
EOF


chmod +x ~/ssm-ssh-proxy.sh

# Add the completion function and ssm function to ~/.zshrc
cat << 'EOF' >> ~/.zshrc
_aws_ec2_instance_completion() {
    local cur_word instance_names cache_file cache_ttl=300
    cur_word="${COMP_WORDS[COMP_CWORD]}"
    cache_file="/tmp/aws_instance_names_cache"

    # Check if cache exists and is fresh
    if [[ -f "$cache_file" ]]; then
        # Use `stat` in a portable way to get the modification time
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS: Use `stat -f %m`
            cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file") ))
        else
            # Linux: Use `stat -c %Y`
            cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))
        fi
    else
        cache_age=$cache_ttl
    fi

    # Refresh cache if it doesn't exist or is too old
    if [[ ! -f "$cache_file" || $cache_age -ge $cache_ttl ]]; then
        # Show a loading spinner while fetching instances
        echo -n "Fetching instances... " >&2
        (
            instance_names=$(aws ec2 describe-instances \
                --filters Name=instance-state-name,Values=running \
                --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' \
                --output text --region ap-south-1 2>/dev/null)
            echo "$instance_names" > "$cache_file"
        ) &
        spinner_pid=$!

        # Spinner animation (it sucks ik ://)
        while kill -0 $spinner_pid 2>/dev/null; do
            for s in / - \\ \|; do
                echo -n "$s" >&2
                sleep 0.1
                echo -ne "\b" >&2
            done
        done
        wait $spinner_pid
        echo "Done!" >&2
    else
        instance_names=$(cat "$cache_file")
    fi

    COMPREPLY=( $(compgen -W "${instance_names}" -- "${cur_word}") )
}

# Register the completion function for the `ssm` command
complete -F _aws_ec2_instance_completion ssm

# Define the `ssm` function to call your script
function ssm() {
  ~/ssm-ssh-proxy.sh "$1"
}
EOF

# Reload the shell configuration
source ~/.zshrc

echo "Setup complete! You can now use the 'ssm' command with autocompletion."
