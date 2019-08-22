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
require_relative "../app/helpers/person_name_helpers"

require "dotenv/load"
require "active_support"
require "active_support/core_ext/object/blank.rb"
require "active_support/core_ext/time/zones"
require "active_support/core_ext/numeric/time"

require "yaml"

class BaseTask
  attr_accessor :logger, :config

  ROOT = File.expand_path("..", __dir__)

  DEFAULT_GITHUB_ORG = "callrail".freeze
  DEFAULT_GITHUB_REPO = "callrail".freeze

  DEFAULT_CONFIG_FILE = "config.yml".freeze

  include PersonNameHelpers

  def initialize
    Time.zone = "UTC"
  end

  private

  def access_token
    @access_token ||= ENV["GITHUB_ACCESS_TOKEN"]
  end

  def username
    @username ||= ENV["GITHUB_USERNAME"]
  end

  def password
    @password ||= ENV["GITHUB_PASSWORD"]
  end

  def otp_secret
    @otp_secret ||= ENV["GITHUB_OTP_SECRET"]
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
    unless ActiveSupport::TimeZone::MAPPING.has_key?(tz)
      logger.fatal("Invalid timezone `#{tz}`")
      puts "Invalid timezone `#{tz}`"
      exit
    end
  end
end
