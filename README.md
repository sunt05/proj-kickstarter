# GitHub Project Repo Opener

This is a repo with snippets I've used for quickly setting up research project repos on GitHub for my students.

## Features

- Create a new repository using [this template](https://github.com/UrbanClimateRisk-UCL/Student-Research-Project).

- Populate onboarding tasks as GitHub issues in the new repo.

## How to Use

Several `gh cli` based scripts are provided in the `scripts` directory.
These scripts are designed to be executed from the command line, each with its respective embedded help message.

- `create-gh-repo.sh` - Create a new repository using the template.
- `raise-gh-issue.sh` - Populate onboarding tasks as GitHub issues in the new repo.
- `delete-test-repo.sh` - Delete repositories used for testing (keywords for filtering such repos can be adjusted).


## Contributing Guidelines

This repo is designed for my own use, but feel free to fork it and adapt it to your needs.
Two areas where contributions are welcome are:
- Improving [the scripts](./scripts/): feel free to add/improve scripts that automate the process of setting up a new project repo for student research projects.
- Improving [the template issues/tasks](./template-issues/): feel free to suggest new tasks or improvements with a focus on onboarding students to a new research project. Example tasks may include:
    - technical setup tasks (e.g. setting up a development environment in Python)
    - research skills (e.g. delving into a new area with effective identification of key papers)
