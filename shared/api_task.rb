# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Provides a base class for any task that uses the Github API to interact
# with Github. Provides helpers for making requests, parsing responses, etc...
#

require_relative "base_task"

require "httparty"

class ApiTask < BaseTask
  BASE_URI = "https://api.github.com"
  HEADERS = {
    "User-Agent" => ENV["GITHUB_USERNAME"],
    "Authorization" => "token #{ENV['GITHUB_ACCESS_TOKEN']}",
    "Accept" => "application/vnd.github.inertia-preview+json"
  }

  include HTTParty

  base_uri BASE_URI
  headers HEADERS

  private

  def validate_environment
    logger.debug("Checking if ENV variables are set")

    if access_token.blank?
      logger.fatal("Env not set correctly")
      puts "Please set `GITHUB_ACCESS_TOKEN` and `GITHUB_USERNAME`"
      exit
    end

    super
  end

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
