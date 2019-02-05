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

require "active_support"
require "active_support/core_ext/object/blank.rb"

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

    super
  end

  def run!
    run_and_close_driver do
      log_in_to_github
      author_whitelist = config["project_to_users_mapping"].values.flatten.uniq

      each_pull_request do |url, author|
        next unless author_whitelist.include?(author)

        logger.debug "Analyzing PR: ##{url.split('/').last} (#{author})"
        visit(url, log: false)

        projects = expected_projects_for(author) - current_projects
        logger.debug "  - Adding: #{projects}" if projects.any?

        projects.each { |project| toggle_project(project) }
      end
    end
  end
end
