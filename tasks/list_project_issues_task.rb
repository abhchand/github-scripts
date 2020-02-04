# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Lists all issues under a project, grouped by state

require_relative "../shared/base_task"

class ListProjectIssuesTask < BaseTask
  DISPLAY_AGE_CUTOFF = 4
  DONT_SHIP_LABEL = "Don't Ship".freeze

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

    logger.info("Target project ids: #{projects.keys.join(', ')}")

    fetch_projects.each do |project|
      project_id = project["number"]
      columns = fetch_columns_for(project)

      columns.each do |column|
        if skip_column?(column)
          logger.info("Skipping column #{column['name']}")
          next
        end

        cards = fetch_cards_in(column)

        cards.each do |card|
          issue = fetch_issue_for(card)
          next if issue.blank?

          state = state_for(issue)
          github_username = issue["user"]["login"]
          days = days_since(issue["created_at"])

          data[project_id] ||= {}
          data[project_id][:name] ||= project["name"]
          data[project_id][:states] ||= {}
          data[project_id][:states][state] ||= {}
          data[project_id][:states][state][:issues] ||= []
          data[project_id][:states][state][:issues] <<
            {
              url: issue["html_url"].gsub("https://", ""),
              title: truncate(issue["title"], 45),
              slack_username: find_slack_by_github(github_username),
              days: (days if days >= display_age_cutoff),
              dont_ship: label_names_for(issue).include?(DONT_SHIP_LABEL)
            }
        end
      end
    end
    sort_by_created_at!(data)
    add_state_data!(data)
    puts render_template("project-issues", data)
  end

  private

  def state_name_to_label_mapping
    @state_name_to_label_mapping ||= begin
      mapping = {}

      config["states"].each do |state_name, state_cfg|
        key = state_name
        val = state_cfg["labels"]
        mapping[key] = val
      end

      mapping
    end
  end

  def labels_for(issue)
    (issue["labels"] || []).map { |l| l["name"] }
  end

  def state_for(issue)
    labels = labels_for(issue)

    return no_applicable_label_state unless any_applicable_labels?(labels)

    state_name_to_label_mapping.select do |_state_name, whitelabels|
      (whitelabels & labels).any?
    end.keys.first
  end

  def any_applicable_labels?(labels)
    applicable_labels = state_name_to_label_mapping.values.flatten.uniq
    labels.any? && applicable_labels.any? && (labels & applicable_labels).any?
  end

  def no_applicable_label_state
    @no_applicable_label_state ||=
      @state_name_to_label_mapping
        .select { |k, v| v.include?("none") }
        .keys
        .first
  end

  def sort_by_created_at!(data)
    data.each do |_project_id, project_data|
      project_data[:states].each do |state, state_data|
        state_data[:issues].sort! do |issue_a, issue_b|
          # Github URLs get assigned by creation date, so just sort directly
          # on the URL
          issue_a[:url] <=> issue_b[:url]
        end
      end
    end
  end

  def add_state_data!(data)
    data.each do |project_id, project_data|
      project_data[:states].each do |state, state_data|
        owner = config.dig("projects", github_org, github_repo, project_id, "state_owners", state)
        display_name = config.dig("states", state, "display_name")

        state_data[:display_name] = display_name
        state_data[:owner] = to_slack_user(owner) if owner
      end
    end
  end

  def days_since(time)
    # Convert times to local user specified TZ
    # Assumes `time` is always in UTC
    created = Time.zone.parse(time).in_time_zone(tz)
    now     = Time.zone.now.in_time_zone(tz)

    # Calculate range:
    # Anything after 3 PM local (i.e. 9 hours remaining in day) gets rounded to
    # next day
    start_date = (created + 9.hours).beginning_of_day.to_date
    end_date   = (now + 9.hours).beginning_of_day.to_date

    # Count days, ignornig weekends
    (start_date..end_date).select { |d| (1..5).include?(d.wday) }.size
  end

  def display_age_cutoff
    @opts[:display_age_cutoff] || DISPLAY_AGE_CUTOFF
  end

  def skip_column?(column)
    @opts[:skip_columns].include?(column["name"].downcase)
  end
end
