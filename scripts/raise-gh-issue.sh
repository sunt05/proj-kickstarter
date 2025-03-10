#!/bin/zsh

# Set zsh to use 0-based array indexing like bash
setopt KSH_ARRAYS

# this script is used to raise a set of github issues for specified repositories using template files
# based on Github cli

# Usage: ./raise-gh-issue.sh [-d] <repo-list-file> <template-file>
# Options:
#   -d    Dry run mode (don't actually create issues)
# Example: ./raise-gh-issue.sh repos.txt template.md
#          ./raise-gh-issue.sh -d repos.txt template.md

# repo-list-file: file containing list of repositories to raise issues in
# repos.txt: file containing list of repositories to raise issues in' (one repository per line)
#  example:
#  ```
#  user/repo1, username1
#  user/repo2, username2
#  ```

# template-file: markdown file containing issue template
# template.md: markdown file containing issue template
#  example:
#  ```
#  # Overall Topic
#  ## Issue 1
#  This is the body of issue 1
#  ### Subsection
#  More content for issue 1
#  ## Issue 2
#  This is the body of issue 2
#  ```

# --- 1. Input Validation and Error Handling ---

# Validate repository format
validate_repo_format() {
    local repo="$1"
    if [[ -z "$repo" ]]; then
        return 1
    fi

    if [[ ! "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
        echo "⚠️ Invalid repository format: $repo - must be owner/repo"
        return 1
    fi
    return 0
}

# Check repository existence before attempting to create issues
check_repo_exists() {
    local repo="$1"
    if ! gh repo view "$repo" &>/dev/null; then
        echo "⚠️ Repository does not exist: $repo"
        return 1
    fi
    return 0
}

# --- 5. Dry Run Mode ---
# Process command line options
dry_run=false
while getopts ":d" opt; do
    case ${opt} in
        d )
            dry_run=true
            ;;
        \? )
            echo "Invalid option: $OPTARG" 1>&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# After shifting, $1 should be repo-list-file and $2 should be template-file
# check if required arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: ./raise-gh-issue.sh [-d] <repo-list-file> <template-file>"
    echo "Options:"
    echo "  -d    Dry run mode (don't actually create issues)"
    exit 1
fi

# Explicitly assign arguments to variables for clarity
repo_list_file="$1"
template_file="$2"

# Debug output
echo "DEBUG: Using repo list file: $repo_list_file"
echo "DEBUG: Using template file: $template_file"

# check if provided repo-list-file exists
if [ ! -f "$repo_list_file" ]; then
    echo "❌ File $repo_list_file does not exist"
    exit 1
fi

# check if provided template-file exists
if [ ! -f "$template_file" ]; then
    echo "❌ File $template_file does not exist"
    exit 1
fi

# check if github cli is installed
if ! command -v gh &>/dev/null; then
    echo "❌ Github CLI is not installed. Please install it before running this script"
    exit 1
fi

# Add a function to check if an issue with the same title already exists
check_issue_exists() {
    local repo="$1"
    local title="$2"

    # Use gh api to search for issues with the given title in the repository
    # We need to URL encode the title for the search query
    local encoded_title=$(echo "$title" | sed 's/ /%20/g' | sed 's/#/%23/g' | sed 's/"/%22/g')

    # Search for open issues with this title
    local search_result=$(gh api -X GET search/issues \
        -f q="repo:$repo is:issue is:open \"$title\"" \
        --jq '.total_count')

    # If total_count > 0, an issue with this title already exists
    if [[ "$search_result" -gt 0 ]]; then
        return 0  # Issue exists
    fi

    return 1  # Issue doesn't exist
}

# --- 3. Rate Limiting and Retry Logic ---
# Modify the retry function for API operations
retry_issue_creation() {
    local repo="$1"
    local title="$2"
    local body="$3"
    local assignee="$4"
    local max_attempts=3
    local wait_time=5
    local attempt=1

    # Skip empty titles
    if [[ -z "$title" ]]; then
        echo "      └── ⚠️ Empty title, skipping"
        return 3  # Special return code for empty title
    fi

    # First check if the issue already exists
    if check_issue_exists "$repo" "$title"; then
        echo "      └── ⚠️ Issue with title \"$title\" already exists, skipping"
        return 2  # Special return code for duplicate
    fi

    while [ $attempt -le $max_attempts ]; do
        if $dry_run; then
            echo "      └── 🔍 [DRY RUN] Would create issue: \"$title\""
            return 0
        elif gh issue create --title "$title" --body "$body" --repo "$repo" --assignee "$assignee"; then
            return 0
        else
            echo "      └── ⚠️ Attempt $attempt failed, retrying in ${wait_time}s..."
            sleep $wait_time
            wait_time=$((wait_time * 2))
            attempt=$((attempt + 1))
        fi
    done

    return 1
}

# --- 6. Improved User Feedback ---
# Print header
echo "\n📝 Starting GitHub issue creation process..."
if $dry_run; then
    echo "🔍 DRY RUN MODE - No issues will be created"
fi
echo "============================================\n"

# --- 2. ULTRA SIMPLE Issue Parsing Logic ---
# Direct extraction of H2 headers and their line numbers
echo "DEBUG: Extracting H2 headers from template file"

# Initialize arrays for titles, line numbers, and bodies
issue_titles=()
issue_line_numbers=()
issue_bodies=()

# First, check if the template file has any H2 headers
h2_headers=$(grep -n "^## " "$template_file")
if [[ -z "$h2_headers" ]]; then
    echo "❌ No H2 headers found in template file"
    exit 1
fi

# Create a temporary file for header processing
temp_file=$(mktemp)
echo "$h2_headers" > "$temp_file"

# Get all H2 headers and their line numbers using grep
while IFS=: read -r line_num content; do
    title=$(echo "$content" | sed 's/^## *//' | sed 's/ *$//')
    # Only add non-empty titles
    if [[ -n "$title" ]]; then
        issue_titles+=("$title")
        issue_line_numbers+=("$line_num")
        echo "DEBUG: Found issue title at line $line_num: \"$title\""
    fi
done < "$temp_file"

rm "$temp_file"

# Get the total number of lines in the file
last_line_number=$(wc -l < "$template_file")

# Debug final header count
echo "DEBUG: Found ${#issue_titles[@]} valid issue titles"
# Print the issue titles
echo "DEBUG: Issue titles: ${issue_titles[@]}"
echo "DEBUG: Issue line numbers: ${issue_line_numbers[@]}"

# Extract bodies for each title
for ((i=0; i<${#issue_titles[@]}; i++)); do
    # Start the body extraction from the line after the H2 header
    start_line=$((${issue_line_numbers[$i]} + 1))

    # If this is the last issue, the body extends to the end of the file
    if [[ $i -eq $((${#issue_titles[@]} - 1)) ]]; then
        end_line=$last_line_number
    else
        # Otherwise, it extends to the line before the next heading
        end_line=$((${issue_line_numbers[$i+1]} - 1))
    fi

    # Extract the body
    body=$(sed -n "${start_line},${end_line}p" "$template_file")
    issue_bodies+=("$body")

    echo "DEBUG: Extracted body for \"${issue_titles[$i]}\" (lines $start_line-$end_line)"
done

# Test to see if arrays are empty
echo "DEBUG: Final issue count: ${#issue_titles[@]}"
if [[ ${#issue_titles[@]} -eq 0 ]]; then
    # Try direct assignment as a fallback
    # This is a workaround for the issue with zsh arrays not being populated in subshells
    readarray -t issue_titles_tmp < <(grep "^## " "$template_file" | sed 's/^## *//')

    # Exit if we still have no titles
    if [[ ${#issue_titles_tmp[@]} -eq 0 ]]; then
        echo "❌ No valid issues found in template file. Make sure your template has sections starting with ## headers"
        echo "\nDEBUG: H2 headers found in template file:"
        grep -E '^## ' "$template_file" || echo "No H2 headers found"
        exit 1
    fi

    # Copy titles from temporary array
    for title in "${issue_titles_tmp[@]}"; do
        if [[ -n "$title" ]]; then
            issue_titles+=("$title")
        fi
    done

    # Try to extract bodies based on simple pattern matching
    for ((i=0; i<${#issue_titles[@]}; i++)); do
        title="${issue_titles[$i]}"
        pattern="^## $title\$"

        # Extract between this pattern and the next ## or end of file
        body=$(awk -v pattern="$pattern" '
            BEGIN { found=0; printing=0; }
            $0 ~ pattern { found=1; printing=0; next; }
            found && !printing { printing=1; next; }
            printing && /^## / { printing=0; exit; }
            printing { print; }
        ' "$template_file")

        issue_bodies+=("$body")
    done
fi

# Make sure we have at least one issue
if [[ ${#issue_titles[@]} -eq 0 ]]; then
    echo "❌ No valid issues found in template file. Make sure your template has sections starting with ## headers"
    echo "\nDEBUG: H2 headers found in template file:"
    grep -E '^## ' "$template_file" || echo "No H2 headers found"
    exit 1
fi

# Display parsed issues
echo "📋 Found ${#issue_titles[@]} issues in template:"
for ((i=0; i<${#issue_titles[@]}; i++)); do
    echo "   └── Issue $((i+1)): \"${issue_titles[$i]}\""
done
echo "======================"
echo ""

# Add counters for summary
total_repos=0
processed_repos=0
skipped_repos=0
total_issues=0
created_issues=0
failed_issues=0
duplicate_issues=0  # New counter
empty_titles=0      # New counter

# read the repositories from the file
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines
    if [[ -z "${line// }" ]]; then
        continue
    fi

    ((total_repos++))

    # Split the line by comma and trim whitespace
    # First extract everything before the first comma for repo
    repo_name=$(echo "$line" | cut -d',' -f1 | xargs)
    # Then extract everything after the first comma for username
    username=$(echo "$line" | cut -d',' -f2- | xargs)

    echo "🔍 Processing repository: $repo_name"

    # Validate repository format
    if ! validate_repo_format "$repo_name"; then
        echo "   └── ⚠️ Skipping - invalid repository format"
        ((skipped_repos++))
        echo "-------------------"
        continue
    fi

    # Validate username
    if [[ -z "$username" ]]; then
        echo "   └── ⚠️ Skipping - missing username"
        ((skipped_repos++))
        echo "-------------------"
        continue
    fi

    echo "   └── Assignee: $username"

    # Check if repository exists
    if ! check_repo_exists "$repo_name"; then
        echo "   └── ⚠️ Skipping - repository does not exist"
        ((skipped_repos++))
        echo "-------------------"
        continue
    fi

    ((processed_repos++))

    # Process issues
    echo "   └── Creating issues:"
    for ((i=0; i<${#issue_titles[@]}; i++)); do
        ((total_issues++))
        issue_title="${issue_titles[$i]}"
        issue_body="${issue_bodies[$i]}"

        echo "      └── 📌 Issue #$((i+1)): \"$issue_title\""
        retry_issue_creation "$repo_name" "$issue_title" "$issue_body" "$username"
        exit_code=$?

        if [ $exit_code -eq 0 ]; then
            echo "         └── ✅ Created successfully"
            ((created_issues++))
        elif [ $exit_code -eq 2 ]; then
            echo "         └── 🔄 Skipped (duplicate)"
            ((duplicate_issues++))
        elif [ $exit_code -eq 3 ]; then
            echo "         └── ⚠️ Skipped (empty title)"
            ((empty_titles++))
        else
            echo "         └── ❌ Failed to create"
            ((failed_issues++))
        fi
    done

    echo "   └── ✨ Completed processing for $repo_name"
    echo "-------------------"
done < "$repo_list_file"

# Print summary
echo "\n📊 Summary:"
echo "   └── Total repositories in file: $total_repos"
echo "   └── Repositories processed: $processed_repos"
echo "   └── Repositories skipped: $skipped_repos"
echo "   └── Total issues attempted: $total_issues"
echo "   └── Issues created successfully: $created_issues"
echo "   └── Issues skipped (duplicates): $duplicate_issues"
echo "   └── Issues skipped (empty titles): $empty_titles"
echo "   └── Failed issues: $failed_issues"

echo "\n✅ Issue creation process completed"
echo "=================================\n"
