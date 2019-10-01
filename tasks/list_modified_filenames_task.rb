# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# List Pull Requests that modify certain files

require_relative "../shared/base_task"

class ListModifiedFilenames < BaseTask
  def self.run!(opts = {})
    new(opts).run!
  end

  def initialize(opts = {})
    @opts = opts

    @opts[:exclude_self] ||= @opts[:exclude_self] || false

    setup_logger
    read_config
    validate_environment

    super()
  end

  def run!
    data = {}
    pull_requests = fetch_pull_requests
    total_count = pull_requests.size
    count = 0

    pull_requests.each do |pull_request|
      files = files_for(pull_request)
      logger.debug("- Found #{files.count} files")

      file_patterns.each do |project_id, patterns|
        if files.any? { |file| matches?(file, patterns) }
          logger.debug("\t[#{project_id}] Matched #{pull_request['number']}")

          project_name = projects.dig(project_id, "name")
          github_user = pull_request.dig("user", "login")

          # if @opts[:exclude_self] && github_user_in_project?(github_user, project_id)
          # end

          data[project_name] ||= []
          data[project_name] << {
            url: pull_request["html_url"],
            title: truncate(pull_request["title"], 45),
            author: github_user
          }
        end
      end
    end

    puts render_template("modified-filenames", data)
  end

  private

  def file_patterns
    @file_patterns ||= begin
      {}.tap do |file_patterns|
        projects.
          select { |_,v| v.key?("owns_files") }.
          map { |k,v| { k => v["owns_files"] || [] } }.
          each { |m| file_patterns[m.keys.first] = m.values.first }
      end
    end
  end

  def files_for(pull_request)
    fetch_pull_request_files_for(pull_request).map { |file| file["raw_url"] }
  end

  def matches?(file, patterns)
    patterns.any? { |pattern| file =~ /#{pattern}/i }
  end
end
