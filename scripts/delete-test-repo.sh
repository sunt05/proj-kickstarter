#!/bin/bash

# Define your GitHub username or organization name
GITHUB_USER_OR_ORG="UrbanClimateRisk-UCL"

# List all repositories and filter those starting with 'test-'
gh repo list $GITHUB_USER_OR_ORG --limit 1000 | awk '/^'$GITHUB_USER_OR_ORG'\/test-/ {print $1}' > filtered-repos.txt


# Review the list of repositories to be deleted
echo "The following repositories will be deleted:"
cat filtered-repos.txt
echo
read -p "Are you sure you want to continue? (y/N) " -n 1 -r

# delete repos listed in the filtered-repos.txt file
if [[ $REPLY =~ ^[Yy]$ ]]; then
    while IFS= read -r repo; do
        echo ""
        echo "Deleting repository $repo"
        gh repo delete $repo --yes
        echo "Repository $repo deleted successfully"
    done <filtered-repos.txt
fi

# remove the filtered-repos.txt file
rm filtered-repos.txt
