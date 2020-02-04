# Github Scripts

A series of helpful scripts to automate common github tasks.

Available Tasks:

| Task | Description |
| ------------- | ------------- |
| [Set Project](#task-set-project) | Ensure a "Project" is always set on certain PRs |
| [List Issues in Project](#task-list-project-issues) | List all Issues in a Project |
| [List Modified Filenames](task-list-modified-filenames) | List all Issues that are touching files you care about |
| [List Unaccounted Issues](task-list-unaccounted-issues) | List all Issues that do not reference a TP story |


## <a name="quick-start"></a> Quick Start

Create a [**github project**](https://help.github.com/en/github/managing-your-work-on-github/creating-a-project-board) for any grouping of issues you want to track (e.g. for each team). You may also want to set up project automation to automatically move issues between columns.

Then set up the project as follows:

```
# Install dependencies
bundle install

# Create and fill out an `.env` file based on the provided sample
cp .env.sample .env
vi .env

# Create and fill out a `config.yml` file base on the provided sample
cp config.yml.sample config.yml
vi config.yml
```

You're now set up to run one of the tasks below.

## <a name="tasks"></a> Tasks

Each task runs against one or more Github project boards which you specify via the `--project-ids=` (or `-p` flag).

All tasks use configurations and mappings specified in the `config.yml` file

For all tasks you can use `--help` to see all available options


### <a name="task-set-project"></a> Set Project

Automatically sets the "Project" on each Github PR!

This prevents each developer from having to remember to constantly add the `Project` field to get their PRs onto the board.
You'll probably want to always run this before any tasks below so the Project board is always up to date.

```
bin/set-project --project-ids=11,16
```

<p>
  <img src="meta/project-menu.png" height="175" />
</p>


### <a name="task-list-project-issues"></a> List Issues in Project

Lists all issues in a project. Convenient format to copy-paste into Slack.

```
bin/list-project-issues --project-ids=6,9

# Or, skip certain columns in your Projects
bin/list-project-issues --project-ids=6,9 --skip-columns="Shipped","Code Review"
```

<p>
  <img src="meta/project-board.png" height="175" />
</p>

### <a name="task-list-modified-filenames"></a> List Modified Filenames

Lists all issues in the repo that touch files that your project cares about.

For example, if your team owns `app/controllers/admin_controller.rb` you may want to be notified of all open PRs that touch that file.

```
bin/list-modified-filenames --project-ids=6,9
```

### <a name="task-unaccounted-issues"></a> List Unaccounted Issues

Lists all issues that do not reference a TP story in the body or title.

```
bin/list-unaccounted-issues --project-ids=11,15
``
