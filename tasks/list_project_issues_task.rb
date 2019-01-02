require_relative "../shared/api_task"

require "active_support"
require "active_support/core_ext/object/blank.rb"

class ListProjectIssuesTask < ApiTask

  def self.run!(project_ids, opts = {})
    new(project_ids, opts).run!
  end

  def initialize(project_ids, opts = {})
    @project_ids = project_ids
    @opts = opts

    @opts[:skip_columns] ||= []
    @opts[:skip_columns].map!(&:downcase)

    setup_logger
    validate_environment

    super(opts)
  end

  def run!
    str = ""
    projects = fetch_projects

    projects.each do |project|
      str += "=== #{project['name']}\n"
      columns = fetch_columns_for(project)

      columns.each do |column|
        if skip_column?(column)
          logger.info("Skipping column #{column['name']}")
          next
        end

        str += "\nColumn: #{column['name']}\n"
        cards = fetch_cards_in(column)

        cards.each do |card|
          issue = fetch_issue_for(card)
          url = issue["html_url"]
          title = truncate(issue["title"], 45)
          str += "- #{url} (#{title})\n"
        end
      end

      str += "\n"
    end

    puts str
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

  def skip_column?(column)
    @opts[:skip_columns].include?(column["name"].downcase)
  end

  def truncate(str, len)
    return str if str.length < len
    str[0, len - 3] + "..."
  end
end
