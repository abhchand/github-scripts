# Github Scripts

A series of helpful scripts to automate common github tasks.

These scripts are implemented using the [Github REST API](https://developer.github.com/v3/) where possible. For some actions that are not supported through the API, the scripts use a headless browser to log in to github and perform the action.

Current Tasks:

- [Set Project](#task-set-project)

## <a name="task-set-project"></a> Set Project Task

Automatically sets the "Project" on each Github PR to the appropriate team(s) based on the mapping of users to projects you specify.

<p>
  <img src="meta/project-menu.png" height="250" />
</p>

Specify the mapping in a json file as follows:

```json
# config.json
{
  "project_to_users_mapping": {
    "Billing Team Project": ["abhchand", "mattRyan"],
    "Some Other Project": ["mattRyan"]
  }
}
```

Build

```
bundle install
```

Run

```
GITHUB_USERNAME=**** \
  GITHUB_PASSWORD=**** \
  GITHUB_OTP_SECRET=*** \
  bin/set-project-task --config-file config.json
```

The username and password are you github credentials. See `setup_project_task.rb` for info on finding your OTP Secret.
