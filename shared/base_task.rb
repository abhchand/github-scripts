# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Provides a base class for all tasks that interact with github
#

require_relative "multi_channel_logger"
require_relative "../app/helpers/github_api_helpers"
require_relative "../app/helpers/person_name_helpers"

require "dotenv/load"
require "active_support"
require "active_support/core_ext/object/blank.rb"
require "active_support/core_ext/time/zones"
require "active_support/core_ext/numeric/time"

require "yaml"
require "httparty"

class BaseTask
  attr_accessor :logger, :config

  ROOT = File.expand_path("..", __dir__)

  DEFAULT_GITHUB_ORG = "callrail".freeze
  DEFAULT_GITHUB_REPO = "callrail".freeze

  DEFAULT_CONFIG_FILE = "config.yml".freeze

  BASE_URI = "https://api.github.com"
  HEADERS = {
    "User-Agent" => ["abhchand/github-scripts", `whoami`].join(":"),
    "Authorization" => "token #{ENV['GITHUB_ACCESS_TOKEN']}",
    "Accept" => "application/vnd.github.inertia-preview+json"
  }

  include HTTParty
  include GithubApiHelpers

  include PersonNameHelpers

  base_uri BASE_URI
  headers HEADERS

  def initialize
    Time.zone = "UTC"
  end

  private

  def get(path, opts = {})
    responses = []
    page = 0

    loop do
      page += 1
      paginated_path = append_page_param(path, page)
      opts_label = opts.empty? ? "" : "(#{opts})"

      logger.debug("\tGET #{paginated_path} #{opts_label}")
      response = self.class.get(paginated_path, opts)

      unless (200..299).member?(response.code)
        logger.fatal(
          "Got invalid response: (#{response.code}) #{response.body}"
        )
        exit
      end

      responses << JSON.parse(response.body)
      break unless next_page?(response)
    end

    responses.flatten
  end

  def post(path, payload = {})
    logger.debug("\tPOST #{path} (#{payload})")
    response = self.class.post(path, body: payload.to_json)

    unless (200..299).member?(response.code)
      logger.fatal("Request failed: (#{response.code}) #{response.body}")
      exit
    end

    JSON.parse(response.body)
  end

  def access_token
    @access_token ||= ENV["GITHUB_ACCESS_TOKEN"]
  end

  def github_org
    return DEFAULT_GITHUB_ORG.downcase unless defined?(@opts)
    (@opts[:github_org] || DEFAULT_GITHUB_ORG).downcase
  end

  def github_repo
    return DEFAULT_GITHUB_REPO.downcase unless defined?(@opts)
    (@opts[:github_repo] || DEFAULT_GITHUB_REPO).downcase
  end

  def tz
    @tz ||= config["tz"].present? ? config["tz"] : "UTC"
  end

  def projects
    @projects ||= begin
      projects = config.dig("projects", github_org, github_repo) || {}
      project_ids = @opts[:project_ids] || projects.keys

      projects.select { |id, project_data| project_ids.include?(id) }
    end
  end

  def setup_logger
    # TODO: Avoid using `caller` in the future
    # We use it to get the name of the invoking class/file so we can
    # use it in our logfile name
    previous_file = caller.first.split(":").first

    logfile = File.join(
      ROOT,
      "log",
      File.basename(previous_file, File.extname(previous_file)) + ".log"
    )

    @logger = MultiChannelLogger.new([logfile, STDOUT], "monthly")
    @logger.level = @opts[:verbose] ? :debug : :info
    @logger.info("Logging to logfile: #{logfile}")

    # This isn't really the place for logging this but I'm lazy
    @logger.info("Target repository: github.com/#{github_org}/#{github_repo}")
  end

  def read_config
    config_file = File.expand_path(@opts[:config_file], ROOT)

    unless File.exist?(config_file)
      raise "Could not find config file `#{config_file}`!"
    end

    @config = YAML.load(File.read(config_file))
    logger.debug "Mapping is: #{@config}"

    @config
  end

  def validate_environment
    logger.debug("Checking if ENV variables are set")

    if access_token.blank?
      logger.fatal("Env not set correctly")
      puts "Please set `GITHUB_ACCESS_TOKEN`"
      exit
    end

    unless ActiveSupport::TimeZone::MAPPING.has_key?(tz)
      logger.fatal("Invalid timezone `#{tz}`")
      puts "Invalid timezone `#{tz}`"
      exit
    end
  end

  def render_template(template_name, *args)
    template = File.join(ROOT, "templates", "#{template_name}.erb")

    ERB.new(File.read(template)).result(binding).tap do |output|
      output.gsub!("\n\n", "\n")
    end
  end

  def truncate(str, len)
    return str if str.length < len
    str[0, len - 3] + "..."
  end

  def append_page_param(path, page)
    # No need to append param since `page` defaults to 1
    return path if page == 1

    path =~ /\?/ ? "#{path}&page=#{page}" : "#{path}?page=#{page}"
  end

  def next_page?(response)
    # Github returns a "link" header that specifies the next paginated
    # value.
    #
    # Link: "<https://api.github.com/repositories/1461037/pulls?page=2>;
    #   rel=\"next\", <https://api.github.com/repositories/1461037/pulls?page=3>; rel=\"last\""
    #
    # Note: We don't use the URL provided by github, we just keep track of our
    # own page counter
    response.headers["link"] =~ /rel=\"next\"/
  end
end
