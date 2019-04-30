# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Lists all issues in a project. Convenient format to copy-paste into Slack.

require_relative "../shared/headless_browser_task"
require_relative "../shared/github_projects_helpers"

class SetProjectTask < HeadlessBrowserTask
  include GithubProjectsHelpers

  def self.run!(opts = {})
    new(opts).run!
  end

  def initialize(opts = {})
    @opts = opts

    setup_logger

    read_config
    check_for_chromedriver
    validate_environment

    super()
  end

  def run!
    logger.info("Target project ids: #{projects.keys.join(', ')}")

    run_and_close_driver do
      log_in_to_github

      members = projects.values.map { |p| p["members"] }.flatten.uniq
      github_author_whitelist = to_github_users(members)

      each_pull_request do |url, github_author|
        github_author = github_author.downcase
        next unless github_author_whitelist.include?(github_author)

        logger.debug "Analyzing PR: ##{url.split('/').last} (#{github_author})"
        visit(url, log: false)

        projects_to_add =
          (expected_projects_for(github_author) - current_projects)
          .map { |id| projects[id].fetch("name") }
        logger.debug "  - Adding: #{projects_to_add}" if projects_to_add.any?

        projects_to_add.each { |project_name| toggle_project(project_name) }
      end
    end
  end
end
