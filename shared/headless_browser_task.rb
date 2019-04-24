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

require_relative "base_task"

require "rotp"
require "selenium-webdriver"

class HeadlessBrowserTask < BaseTask
  attr_accessor :driver

  def initialize
    setup_driver
    setup_headless_window
  end

  private

  def setup_driver
    logger.debug("Creating driver")

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    @driver = Selenium::WebDriver.for(:chrome, options: options)
  end

  def check_for_chromedriver
    logger.debug("Checking if `chromedriver` is available")

    if `which chromedriver`.blank?
      logger.fatal("Can not find `chromedriver`")
      puts "Unable to find `chromedriver` in $PATH." +
        "Install it with `brew install chromedriver`"
      exit
    end
  end

  def validate_environment
    logger.debug("Checking if ENV variables are set")

    if username.blank? || password.blank? || otp_secret.blank?
      logger.fatal("Env not set correctly")
      puts "Please set `GITHUB_USERNAME`, `GITHUB_PASSWORD`, and "\
        "`GITHUB_OTP_SECRET`"
      exit
    end

    super
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

  def repo_url
    "https://github.com/#{github_org}/#{github_repo}"
  end

  def pulls_url(page: nil)
    url = repo_url + "/pulls"
    page ? "#{url}?page=#{page}" : url
  end

  def pull_url(id)
    [repo_url, "pull", id].join("/")
  end

  # Queries for the list of all pull requests and then yields them one at a
  # time to the provided block.
  # NOTE: This actually visits the /pulls page and generates the URL list
  # by visiting each paginated page and scraping the URL list from the DOM
  def each_pull_request(&block)
    visit(pulls_url)

    all_pulls = []

    (1..max_pulls_page).each do |page|
      logger.debug "Find pull requests on page #{page}"
      visit(pulls_url(page: page))

      # Parse the links at the bottom of each PR box to determine PR ID and
      # author
      # E.g. #12159 opened 6 hours ago by melindaweathers
      pulls =
        driver
        .find_element(:class, "repository-content")
        .find_elements(:class, "opened-by")
        .map do |span|
          text = span.text.split(" ")

          {
            url: pull_url(text.first.delete("#")),
            author: text.last
          }
        end

      logger.debug "Found #{pulls.count} pull requests"
      all_pulls << pulls
    end

    all_pulls.flatten!
    logger.info "Found total #{all_pulls.count} pull requests"

    all_pulls.each { |pull| yield(pull[:url], pull[:author]) }
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
