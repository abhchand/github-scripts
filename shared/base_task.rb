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

require "dotenv/load"
require "active_support"
require "active_support/core_ext/object/blank.rb"
require "active_support/core_ext/time/zones"
require "active_support/core_ext/numeric/time"

require "yaml"

class BaseTask
  attr_accessor :logger, :config

  ROOT = File.expand_path("..", __dir__)
  ORG_NAME = ENV["GITHUB_ORG_NAME"] || "callrail"
  REPO_NAME = ENV["GITHUB_REPO_NAME"] || "callrail"

  DEFAULT_CONFIG_FILE = File.join(ROOT, "config.yml")

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

  def tz
    @tz ||= config["tz"].present? ? config["tz"] : "UTC"
  end

  def people
    return @people if @people

    @people = {}

    # Ensure all keys are stored `downcase` to make searches case-insensitive
    config["people"].each do |name, mapping|
      @people[name.downcase] = {
        "github" => mapping["github"].downcase,
        "slack" => mapping["slack"].downcase
      }
    end
  end

  def to_github_users(people_list)
    people_list.map { |name| people[name.downcase]["github"] }
  end

  def to_slack_user(person)
    people[person.downcase]["slack"]
  end

  def find_slack_by_github(github_name)
    people.each do |person, mapping|
      if mapping["github"].downcase == github_name.downcase
        return mapping["slack"]
      end
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
  end

  def read_config
    config_file = File.expand_path(@opts[:config_file], ROOT)

    unless File.exist?(config_file)
      raise "Could not find config file `#{config_file}`!"
    end

    @config = YAML.load(File.read(config_file))
    logger.info "Mapping is: #{@config}"

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
