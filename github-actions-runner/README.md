# container-image-github-actions-runner

This container image is the base for our self-hosted GitHub Actions runners.
It contains various packages we need (like gcc).
The authentication is done via GitHub App and only working for GitHub organizations.
In order to get this working, head over to https://github.com/organizations/<your_org>/settings/apps/new .
Create a GitHub App with
- a dummy **Homepage URL**
- a disabled **Wekhook**
- the organization permission **Self-hosted runners** set to *Read & write*
- **Only on this account** as installation target

Once created, note down the **App ID**, create a **Private key** and safe it for later.
Make sure the app is installed on your org (left pane under *Install App*).

### Usage

This container image is used by our helm-chart to deploy in kubernetes but might be used standalone, too.
The following environment variables are required if used without helm:

| Variable              | Purpose                                                                              |
|-----------------------|--------------------------------------------------------------------------------------|
| SECRET_GITHUB_URL     | The URL to the GitHub website                                                        |
| SECRET_GITHUB_API_URL | The URL to the GitHub API                                                            |
| SECRET_GITHUB_APP_ID  | The earlier noted down APP ID                                                        |
| SECRET_GITHUB_ORG     | The name of your organization                                                        |
| SECRET_KEY_PATH       | The path to the RSA key file you downloaded (needs to be mounted into the container) |
| SECRET_NAME           | The name your GitHub Actions runner should have                                      |
