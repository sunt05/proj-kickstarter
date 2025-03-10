#!/bin/zsh

# this script is used to create a set of github repositories using a list of repository names based on Github cli

# Usage: ./create-gh-repo.sh <repo-list-file>
# Example: ./raise-gh-issue.sh repos.txt

# repo-list-file: file containing list of repositories to raise issues in
# repos.txt: file containing list of repositories to raise issues in' (one repository per line)
#  example:
#  ```
#  user/repo1, username1
#  user/repo2, username2
#  ```

# the template repo to use: https://github.com/UrbanClimateRisk-UCL/Student-Research-Project
repo_template="UrbanClimateRisk-UCL/Student-Research-Project"

# check if required arguments are provided
if [ $# -ne 1 ]; then
    echo "Usage: ./create-gh-repo.sh <repo-list-file>"
    exit 1
fi

# check if github cli is installed
if ! command -v gh &>/dev/null; then
    echo "Github cli is not installed. Please install it before running this script"
    exit 1
fi

# check if provided repo-list-file exists
if [ ! -f $1 ]; then
    echo "File $1 does not exist"
    exit 1
fi

# read the repo list file
repo_list_file=$1

# Print header
echo "\n📦 Starting repository creation process..."
echo "==========================================\n"

# create the repositories and add student as collaborator
while IFS= read -r repo || [ -n "$repo" ]; do
    # Skip empty lines
    if [[ -z "${repo// }" ]]; then
        continue
    fi

    # split the repo and username using zsh way
    repo_array=("${(@s/,/)repo}")
    repo_name=${repo_array[1]}

    # Validate input format
    if [[ ! "$repo_name" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
        echo "⚠️  Invalid repository format: $repo_name - skipping"
        continue
    fi

    # Split repo_name into owner and repo
    IFS="/" read -r owner repo <<< "$repo_name"
    username=$(echo "${repo_array[2]}" | tr -d ' ')

    # Validate username
    if [[ -z "$username" ]]; then
        echo "⚠️  Missing username for repository $repo_name - skipping"
        continue
    fi

    echo "🔍 Processing: $repo_name"
    echo "   └── User: $username"

    # Check if repository exists
    if gh repo view "$repo_name" &>/dev/null; then
        echo "   └── ⏩ Repository already exists, skipping creation"
    else
        echo "   └── 🔨 Creating new repository..."
        if gh repo create $repo_name --template $repo_template --private; then
            echo "   └── ✅ Repository created successfully"

            # permission can be one of the following: pull, push, maintain, triage, admin
            if echo '{}' | gh api \
                --method PUT \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                /repos/"$owner"/"$repo"/collaborators/"$username" \
                -f permission='maintain' \
                --silent; then
                echo "   └── 👥 User $username added as collaborator"
            else
                echo "   └── ❌ Failed to add collaborator"
            fi
        else
            echo "   └── ❌ Failed to create repository"
        fi
    fi

    echo "-------------------"
done <$repo_list_file

echo "\n✨ Repository creation process completed"
echo "======================================\n"
