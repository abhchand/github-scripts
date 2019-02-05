# Github Scripts

A series of helpful scripts to automate common github tasks.

These scripts are implemented using the [Github REST API](https://developer.github.com/v3/) where possible. For some actions that are not supported through the API, the scripts use a headless browser to log in to github and perform the action.

Available Tasks:

| Task | Description |
| ------------- | ------------- |
| [Set Project](#task-set-project) | Ensure a "Project" is always set on certain PRs |
| [List Issues in Project](#task-list-project-issues) | List all Issues (PRs) in a Project |

**NOTE:** Before running any of these tasks, you'll have to do a quick [one-time setup](#one-time-setup) below.

- [Tasks](#tasks)
    - [Set Project](#task-set-project)
    - [List Issues in Project](task-list-project-issues)
- [One-Time Setup](#one-time-setup)


## <a name="tasks"></a> Tasks

### <a name="task-set-project"></a> Set Project

Automatically sets the "Project" on each Github PR to the appropriate team(s) based on the mapping of users to projects you specify.

<p>
  <img src="meta/project-menu.png" height="175" />
</p>

Create a config file mapping users to projects:

```json
# config.json
{
  "project_to_users_mapping": {
    "Billing Team Project": ["abhchand", "mattRyan"],
    "Some Other Project": ["mattRyan"]
  }
}
```

Run

```
bundle install
bin/set-project-task --config-file config.json
```

### <a name="task-list-project-issues"></a> List Issues in Project

Lists all issues in a project. Convenient format to copy-paste into Slack.

<p>
  <img src="meta/project-board.png" height="175" />
</p>

Create a config file mapping github usernames to slack usernames (Optional)

```json
{
  "github_to_slack_username_mapping": {
    "abhchand": "Abhishek",
    "mattRyan": "Matty Ice",
  }
}

```

Run

```
bundle install
bin/list-project-issues-task --project-ids=6,9 --config-file config.json

# Skip certain columns in your Projects
bin/list-project-issues-task --project-ids=6,9 --config-file config.json --skip-columns="Shipped","Code Review"
```

## <a name="one-time-setup"></a> One-Time Setup

Because the script needs to access Github using either your API token or your Github credentials (with the headless browser), you'll need to set some environment variables to provide those values.

In the root directory of this project, create an `.env` file with the following:

```
GITHUB_ACCESS_TOKEN=xxxx

GITHUB_USERNAME=xxxx
GITHUB_PASSWORD=xxxx
GITHUB_OTP_SECRET=xxxx
```

You can create a new `GITHUB_ACCESS_TOKEN` [here](https://github.com/settings/tokens).

The `GITHUB_OTP_SECRET` (one-time password) auth token can be found in your `otpauth` URL that
github provides when you first set up 2FA. (This is the URL that's presented as a QR
code for you to scan with apps like Google Authenticator or 1Password.)

```
otpauth://totp/GitHub:abhchand?secret=abcdefg&issuer=GitHub
```

Here you would set `GITHUB_OTP_SECRET=abcdefg`.

If you use 1Password to store your 2FA logins you can easily retrieve this URL.
Otherwise you might have to disable and then re-enable your 2FA on Github
to get a new QR code and then decode that QR code yourself to get the URL ¯\\_(ツ)_/¯.
