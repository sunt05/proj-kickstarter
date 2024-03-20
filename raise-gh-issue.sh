#!/bin/zsh

# this script is used to raise a set of github issues for specified repositories using template files
# based on Github cli

# Usage: ./raise-gh-issue.sh <repo-list-file> <template-file>
# Example: ./raise-gh-issue.sh repos.txt template.md

# repo-list-file: file containing list of repositories to raise issues in
# repos.txt: file containing list of repositories to raise issues in' (one repository per line)
#  example:
#  ```
#  user/repo1
#  user/repo2
#  ```

# template-file: markdown file containing issue template
# template.md: markdown file containing issue template
#  example:
#  ```
#  ### Issue 1
#  This is the body of issue 1
#  ### Issue 2
#  This is the body of issue 2
#  ```

# check if required arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: ./raise-gh-issue.sh <repo-list-file> <template-file>"
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

# check if provided template-file exists
if [ ! -f $2 ]; then
    echo "File $2 does not exist"
    exit 1
fi

# read the template file
template_file=$2

# Get the H2 headers
IFS=$'\n' issues=($(grep -E '^## ' $template_file | sed 's/^## //'))

# # Print the issues
# counter=1
# for issue in "${issues[@]}"; do
#     echo "$counter. $issue"
#     ((counter++))
# done
# echo "======================"
# echo ""

# Get the line numbers of the H2 headers
issue_line_numbers=($(grep -n -E '^## ' $template_file | cut -d: -f1))

# Print the line numbers
echo "Issue line numbers: ${issue_line_numbers[@]}"

# Get the line numbers of the last line of the file
last_line_number=$(wc -l <$template_file)

# Initialize an empty array
issue_bodies=()
counter=1
# Iterate over the issues and get the issue body
for i in $(seq 1 $((${#issue_line_numbers[@]}))); do
    # Get the issue title
    issue_title=$(sed -n "${issue_line_numbers[$i]}p" $template_file)
    # Get the issue body
    if [ $i -eq $((${#issue_line_numbers[@]})) ]; then
        issue_body=$(sed -n "$((${issue_line_numbers[$i]} + 1)),$last_line_number p" $template_file)
    else
        issue_body=$(sed -n "$((${issue_line_numbers[$i]} + 1)),$((${issue_line_numbers[$i + 1]} - 1)) p" $template_file)
    fi
    # Print the issue title and body
    # echo "Issue $counter:"
    # echo "Title: $issue_title"
    # echo "Body: $issue_body"
    # echo "----------------------"
    # Append the issue body to the issue_bodies array
    issue_bodies+="$issue_body"
    ((counter++))
done

# # Print the issue bodies
# # counter=1
# for i in {1..${#issue_bodies[@]}}; do
#     echo "Issue $i:"
#     echo "Title: ${issues[$i]}"
#     echo "${issue_bodies[$i]}"
#     echo "----------------------"
# done

# read the repo list file
repo_list_file=$1

# read the repositories from the file
repos=($(cat $repo_list_file))

# iterate over the repositories and raise issues
for repo in "${repos[@]}"; do
    echo "Raising issues in $repo"
    echo "----------------------"
    # iterate over the issues and raise them
    for i in {1..${#issue_bodies[@]}}; do
        issue_title=${issues[$i]}
        issue_body=${issue_bodies[$i]}
        echo "Raising issue $i: $issue_title"
        gh issue create --title "$issue_title" --body "$issue_body" --repo $repo
        echo "Done"
        echo "----------------------"
    done
    echo "Done raising issues in $repo"
    echo "======================"
    echo ""
done
