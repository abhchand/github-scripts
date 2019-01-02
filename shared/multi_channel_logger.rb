# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Provides an interface for a logger that logs to multiple channels (e.g. a
# file as well as STDOUT). Does so by wrapping the standard ruby logger and
# the common logger methods (`write`, `info`, etc...).
#
# Initialized the exact same way as the ruby logger except that the first
# argument is now an array that accepts a list of channels.
#
#    e.g. MultiChannelLogger.new([filename, STDOUT], "monthly")
#
require "logger"

class MultiChannelLogger
  def initialize(*args)
    unless args.first.is_a?(Array)
      raise "Expecting array as first argument"
    end

    channels = args.shift
    @loggers = []

    channels.each do |channel|
      loggers << Logger.new(*([channel] + args))
    end
  end

  def level=(level)
    loggers.each { |logger| logger.level = level }
  end

  def write(*args)
    loggers.each { |logger| logger.write(*args) }
  end

  def debug(*args)
    loggers.each { |logger| logger.debug(*args) }
  end

  def info(*args)
    loggers.each { |logger| logger.info(*args) }
  end

  def warn(*args)
    loggers.eac { |logger| logger.warn(*args) }
  end

  def error(*args)
    loggers.each { |logger| logger.error(*args) }
  end

  def fatal(*args)
    loggers.each { |logger| logger.fatal(*args) }
  end

  private

  attr_accessor :loggers
end
