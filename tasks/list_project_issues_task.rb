# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Automatically sets the "Project" on each Github PR to the appropriate team(s)
# based on the mapping of users to projects you specify.

require_relative "../shared/api_task"

class ListProjectIssuesTask < ApiTask
  STATE_TO_LABEL_MAPPING = {
    "In Development"            => ["WIP :construction:"],
    "In Code Review"            => ["Code Review :mag:", ":eyes: Code Review"],
    "Ready for QA Review"       => ["QA Review", ":hammer: QA Review"],
    "Ready for Product Review"  => ["Product Review"],
    "Ready for Deploy"          => ["QA OK :+1:", ":white_check_mark: QA Ok", "Product OK :+1"]
  }

  def self.run!(project_ids, opts = {})
    new(project_ids, opts).run!
  end

  def initialize(project_ids, opts = {})
    @project_ids = project_ids
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
    projects = fetch_projects
    username_mapping = config["github_to_slack_username_mapping"] || {}

    projects.each do |project|
      data[project['name']] = {}
      columns = fetch_columns_for(project)

      columns.each do |column|
        if skip_column?(column)
          logger.info("Skipping column #{column['name']}")
          next
        end

        cards = fetch_cards_in(column)

        cards.each do |card|
          issue = fetch_issue_for(card)
          state = state_for(issue)
          github_username = issue["user"]["login"]
          days = days_since(issue["created_at"])

          data[project['name']][state] ||= []
          data[project['name']][state] <<
            {
              url: issue["html_url"].gsub("https://", ""),
              title: truncate(issue["title"], 45),
              slack_username: username_mapping[github_username],
              days: (days if days > 2)
            }
        end
      end
    end

    sort_by_created_at!(data)
    puts render_template_with(data)
  end

  private

  def validate_environment
    if @project_ids.blank?
      logger.fatal("project_ids not set")
      puts "Please set project ids"
      exit
    end

    super
  end

  def fetch_projects
    # Documentation: https://developer.github.com/v3/projects
    logger.info("Fetching projects")

    path = ["/repos", ORG_NAME, REPO_NAME, "projects"].join("/")
    response = get(path)

    response.select { |project| @project_ids.include?(project["number"]) }
  end

  def fetch_columns_for(project)
    # Documentation: https://developer.github.com/v3/projects/columns
    logger.info(
      "Fetching columns for project ##{project['id']} '#{project['name']}'"
    )

    url = project["columns_url"]
    get(url)
  end

  def fetch_cards_in(column)
    # Documentation: https://developer.github.com/v3/projects/cards
    logger.info(
      "Fetching cards for column ##{column['id']} '#{column['name']}'"
    )

    url = column["cards_url"]
    get(url)
  end

  def fetch_issue_for(card)
    # Documentation: https://developer.github.com/v3/issues
    logger.info("Fetching issue for card ##{card['id']}")

    url = card["content_url"]
    get(url)&.first
  end

  def labels_for(issue)
    (issue["labels"] || []).map { |l| l["name"] }
  end

  def state_for(issue)
    labels = labels_for(issue)

    STATE_TO_LABEL_MAPPING.select do |state, whitelabels|
      (whitelabels & labels).any?
    end.keys.first
  end

  def sort_by_created_at!(data)
    data.each do |project, states|
      states.each do |state, issues|
        issues.sort! do |issue_a, issue_b|
          # Github URLs get assigned by creation date, so just sort directly
          # on the URL
          issue_a[:url] <=> issue_b[:url]
        end
      end
    end
  end

  def render_template_with(data)
    template = File.join(ROOT, "templates", "project-issues.erb")
    ERB.new(File.read(template)).result(binding)
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

  def skip_column?(column)
    @opts[:skip_columns].include?(column["name"].downcase)
  end

  def truncate(str, len)
    return str if str.length < len
    str[0, len - 3] + "..."
  end
end
