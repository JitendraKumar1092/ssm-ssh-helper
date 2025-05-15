#!/bin/bash

# Ensure the script is run with bash
#if [ -z "$BASH_VERSION" ]; then
#    echo "This script must be run with bash."
#    exit 1
#fi


cat << 'EOF' > ~/ssm-ssh-proxy.sh
#!/bin/bash
# filepath: ~/ssm-ssh-proxy.sh

NAME="$1"
REGION="ap-south-1"

if [ -z "$NAME" ]; then
    echo "Error: Instance name is required." >&2
    exit 1
fi


INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text --region "$REGION" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Failed to query AWS. Check your AWS CLI configuration." >&2
    exit 1
fi

if [ -z "$INSTANCE_ID" ]; then
    echo "Error: No running instance found with Name tag: $NAME" >&2
    exit 1
fi

# Start SSM session
exec aws ssm start-session --target "$INSTANCE_ID" --region "$REGION"
EOF


chmod +x ~/ssm-ssh-proxy.sh

# Add the completion function and ssm function to ~/.zshrc
cat << 'EOF' >> ~/.zshrc

# AWS EC2 Instance Completion Function
_aws_ec2_instance_completion() {
    local cur_word instance_names cache_file cache_ttl=300
    cur_word="${COMP_WORDS[COMP_CWORD]}"
    cache_file="/tmp/aws_instance_names_cache"

    # Check if cache exists and is fresh
    if [[ -f "$cache_file" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file") ))
        else
            cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))
        fi
    else
        cache_age=$cache_ttl
    fi

    # Refresh cache if it doesn't exist or is too old
    if [[ ! -f "$cache_file" || $cache_age -ge $cache_ttl ]]; then
        instance_names=$(aws ec2 describe-instances \
            --filters Name=instance-state-name,Values=running \
            --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' \
            --output text 2>/dev/null)
        echo "$instance_names" > "$cache_file"
    else
        instance_names=$(cat "$cache_file")
    fi

    COMPREPLY=( $(compgen -W "${instance_names}" -- "${cur_word}") )
}


complete -F _aws_ec2_instance_completion ssm


function ssm() {
    ~/ssm-ssh-proxy.sh "$1"
}
EOF

# Reload the shell configuration
source ~/.zshrc

echo "Setup complete! You can now use the 'ssm' command with autocompletion."
