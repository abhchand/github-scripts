# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Lists all issues under a project that are unaccounted for in TargetProcess

require_relative "../shared/base_task"

class ListUnaccountedIssuesTask < BaseTask
  TARGET_PROCESS_BODY_REGEX = /callrail.tpondemand.com\/[^\/]*\/(\d+)/i.freeze
  TARGET_PROCESS_TITLE_REGEX = /TP[#\-\s]?(\d+)/i.freeze

  def self.run!(opts = {})
    new(opts).run!
  end

  def initialize(opts = {})
    @opts = opts

    @opts[:skip_columns] ||= []
    @opts[:skip_columns].map!(&:downcase)

    setup_logger
    read_config
    validate_environment

    super()
  end

  def run!
    data = {}

    each_issue do |issue, metadata|
      project_id  = metadata[:project]["number"]
      github_username = issue["user"]["login"]

      next if has_target_process_id?(issue)

      data[project_id] ||= []
      data[project_id] <<
        {
          url: issue["html_url"].gsub("https://", ""),
          slack_username: find_slack_by_github(github_username)
        }
    end

    puts render_template("unaccounted-issues", data)
  end

  private

  def has_target_process_id?(issue)
    parse_target_process_ids_from_body(issue) ||
      parse_target_process_ids_from_title(issue)
  end

  def parse_target_process_ids_from_body(issue)
    result = issue["body"].match(TARGET_PROCESS_BODY_REGEX)
    result.to_a.tap(&:shift) if result
  end

  def parse_target_process_ids_from_title(issue)
    result = issue["title"].match(TARGET_PROCESS_TITLE_REGEX)
    result.to_a.tap(&:shift) if result
  end
end

