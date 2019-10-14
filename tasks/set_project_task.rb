# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Lists all issues in a project. Convenient format to copy-paste into Slack.

require_relative "../shared/base_task"

class SetProjectTask < BaseTask
  def self.run!(opts = {})
    new(opts).run!
  end

  def initialize(opts = {})
    @opts = opts

    setup_logger
    read_config
    validate_environment

    super()
  end

  def run!
    logger.info("Target project ids: #{projects.keys.join(', ')}")
    fetch_project_data

    fetch_pull_requests.each do |pull_request|
      url = pull_request["html_url"]
      author = pull_request["user"]["login"].downcase

      next unless care_about_author?(author)
      logger.info "Analyzing PR: ##{pull_request['number']} (#{author})"

      missing_projects = missing_projects_for(pull_request)
      missing_projects.each do |project|
        add_project_to_pull_request(pull_request, project)
      end
    end
  end

  private

  def github_projects
    @github_projects ||= fetch_projects
  end

  def fetch_project_data
    @columns_by_project_id ||= {}
    @issues_by_project_id ||= {}

    github_projects.each do |project|
      project_id = project["number"]
      @issues_by_project_id[project_id] ||= []
      @columns_by_project_id[project_id] ||= []

      fetch_columns_for(project).each do |column|
        @columns_by_project_id[project_id] << column

        fetch_cards_in(column).each do |card|
          issue = fetch_issue_for(card)
          @issues_by_project_id[project_id] << issue if issue
        end
      end
    end
  end

  def care_about_author?(author)
    @members ||= projects.values.map { |p| p["members"] }.flatten.uniq
    @author_whitelist ||= to_github_users(@members)

    @author_whitelist.include?(author)
  end

  def missing_projects_for(pull_request)
    expected = expected_project_ids_for(pull_request)
    actual = current_project_ids_for(pull_request)

    (expected - actual).map do |project_id|
      github_projects.detect { |project| project["number"] == project_id }
    end
  end

  def expected_project_ids_for(pull_request)
    author = pull_request["user"]["login"]

    @expected_project_ids ||= {}
    (@expected_project_ids[author] ||= []).tap do |ep|
      return ep if ep.any?
    end

    projects.each do |id, project_data|
      members = project_data["members"]
      if to_github_users(members).include?(author)
        @expected_project_ids[author] << id
      end
    end

    @expected_project_ids[author]
  end

  def current_project_ids_for(pull_request)
    @issues_by_project_id.select do |project_id, issues|
      issues.any? { |issue| issue["number"] == pull_request["number"] }
    end.keys
  end

  def add_project_to_pull_request(pull_request, project)
    logger.info "  - Adding to project: '#{project['name']}'"

    # Right now just get the first column.
    # TODO: Add to column based on status
    column = @columns_by_project_id[project['number']].first

    path = ["/projects", "columns", column["id"], "cards"].join("/")
    payload = { content_id: pull_request["id"], content_type: "PullRequest" }

    post(path, payload)
  end
end
