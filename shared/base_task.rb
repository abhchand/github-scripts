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

class BaseTask
  attr_accessor :logger

  ROOT = File.expand_path("..", __dir__)
  ORG_NAME = ENV["GITHUB_ORG_NAME"] || "callrail"
  REPO_NAME = ENV["GITHUB_REPO_NAME"] || "callrail"

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
end
