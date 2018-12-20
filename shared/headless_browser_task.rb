# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Provides a base class for any task that uses a headless browser to interact
# with Github. Provides helpers for logging in, access pull requests, etc...
#

require_relative "multi_channel_logger"

require "rotp"
require "selenium-webdriver"

class HeadlessBrowserTask
  attr_accessor :logger, :driver, :config

  ROOT = File.expand_path("..", __dir__)
  ORG_NAME = ENV["GITHUB_ORG_NAME"] || "callrail"
  REPO_NAME = ENV["GITHUB_REPO_NAME"] || "callrail"

  def initialize
    setup_driver
    setup_headless_window

    logger.info("Looking at Github repository: #{repo_url}")
  end

  private

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
    @logger.info("Logging to logfile: #{logfile}")
  end

  def setup_driver
    logger.debug("Creating driver")

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    @driver = Selenium::WebDriver.for(:chrome, options: options)
  end

  def read_config
    config_file = self.class::CONFIG_FILE

    unless File.exist?(config_file)
      raise "Expecting `#{config_file}`!"
    end

    @config = JSON.parse(File.read(config_file))
    logger.info "Mapping is: #{@config}"

    @config
  end

  def setup_headless_window
    width = 1600
    height = 1280
    logger.debug("Resizing window to #{width}x#{height}")
    driver.manage.window.resize_to(width, height)
  end

  # Executes a block and ensures the headless browser connection is closed
  # before exiting.
  def run_and_close_driver(&block)
    logger.info("Starting execution")
    yield
    logger.info "Complete"
  rescue => e
    logger.error e
    logger.error e.backtrace
    capture_screenshot!
  ensure
    if driver
      logger.info("Closing driver...")
      driver.quit
    end
  end

  def visit(url, log: true)
    logger.debug("Visiting #{url}") if log
    driver.navigate.to(url)
  end

  def capture_screenshot!
    filename = "screenshot-#{Time.now.utc.to_i}.png"
    filepath = File.join(ROOT, "tmp", filename)

    logger.debug "Capturing screenshot... #{filename}"
    driver.save_screenshot(filepath) if driver
  end

  # Logs into Github by filling in the username, password, and 2FA prompt
  def log_in_to_github
    visit("https://github.com/login")

    logger.debug("Fill out username and password")

    username_field = driver.find_element(id: "login_field")
    password_field = driver.find_element(id: "password")
    username_field.send_keys(username)
    password_field.send_keys(password)
    username_field.submit

    logger.debug("Fill out two-factor auth")
    if driver.current_url =~ /two-factor/
      totp = ROTP::TOTP.new(otp_secret)

      otp_field = driver.find_element(id: "otp")
      otp_field.send_keys(totp.at(Time.now))

      otp_field.submit
    end
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

  # Grabs the author of the PR currently being viewed by scraping the DOM
  # element
  def pr_author
    driver.find_element(:class, "pull-header-username").text
  end

  def repo_url
    "https://github.com/#{ORG_NAME}/#{REPO_NAME}"
  end

  def pulls_url(page: nil)
    url = repo_url + "/pulls"
    page ? "#{url}?page=#{page}" : url
  end

  # Queries for the list of all pull requests and then yields them one at a
  # time to the provided block.
  # NOTE: This actually visits the /pulls page and generates the URL list
  # by visiting each paginated page and scraping the URL list from the DOM
  def each_pull_request(&block)
    visit(pulls_url)

    urls = []

    (1..max_pulls_page).each do |page|
      logger.debug "Find pull requests on page #{page}"
      visit(pulls_url(page: page))

      # Github doesn't provide a convenient class or tag structure to identify
      # PR links. So we just find *all* links and filter by those that have
      # an `id` with a pattern `issue-id-XXXX`
      parsed_urls =
        driver.find_element(:class, "repository-content")
        .find_elements(:tag_name, "a")
        .select { |a| a["id"] =~ /issue-id-[\d+]/ }
        .map { |a| a["href"] }

      logger.debug "Found #{parsed_urls.count} pull requests"
      urls << parsed_urls
    end

    urls.flatten!
    logger.info "Found total #{urls.count} pull requests"

    urls.each { |url| yield(url) }
  end

  # Gets the page number of the last pull request page since the above method
  # may need to cycle through multiple pages.
  def max_pulls_page
    # If pull requests span multiple pages, there's a pagination box at the
    # bottom. It follows the format: <1> <2> ... <99> <Next> so we want to
    # get the max page (second to last element)
    @max_pulls_page ||=
      driver
      .find_element(:class, "pagination")
      .find_elements(:tag_name, "a")
      .map(&:text)
      .last(2)
      .first
      .to_i
  rescue
    @max_pulls_page ||= 1
  end
end
