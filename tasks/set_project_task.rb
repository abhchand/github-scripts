# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# This script automates the updating the "Projects" on PRs so that PR owners
# don't have to do it themselves. It's intended to run periodically on cron.
#
# It expects a JSON config file that specifies which users should map to which
# projects
#
# E.g.
#
#     {
#       "project_to_users_mapping": {
#         "Billing Team Project": ["abhchand", "mattRyan"],
#         "Some Other Project": ["mattRyan"]
#       }
#     }
#
# In the above case, any open PRs by `abhchand` will be assigned the Billing
# project and any open PRs by Matt Ryan will be assigned both projects.
#
# Ideally it would use the rich Github API but unfortunately Github has not
# exposed the ability to edit Projects on PRs. So we have to do this the hard
# way. This script utilizes a headless browser (Selenium Chrome) to go through
# and actually click the "Project" icon on each PR 😲
#
# For this reason it requires valid Github credentials to log in and perform
# the update. Because of this terrible security restriction, this script is
# intended to run on your local machine or somewhere informal where your
# credentials can't be accidentally exposed.
#
# It looks for the following environment variables
#
#    - GITHUB_USERNAME - Your github username
#    - GITHUB_PASSWORD - Your github password
#    - GITHUB_OTP_SECRET - The `secret` query param of your otpauth token. This
#                          is needed to generate and fill out the 2FA auth
#    - * GITHUB_ORG_NAME - The organization name. Defaults to "callrail"
#    - * GITHUB_REPO_NAME - The repository name. Defaults to "callrail"
#
#   * optional
#
# The OTP (one-time password) auth token can be found in your otpauth URL that
# github provides when you set up 2FA. This is the URL that's encoded as a QR
# code that's scanned by apps like Google Authenticator or 1Password.
#
# e.g. otpauth://totp/GitHub:abhchand?secret=abcdefg&issuer=GitHub
#
# Here you'll need to set `GITHUB_OTP_SECRET` as `abcdefg`.
# If you use 1Password to store 2FA logins you can easily retrieve this URL.
# Otherwise you might have to disable and then re-enable your 2FA on Github
# to get a new QR code and then decode that QR code yourself.

require_relative "../shared/headless_browser_task"
require_relative "../shared/github_projects_helpers"

require "active_support"
require "active_support/core_ext/object/blank.rb"

class SetProjectTask < HeadlessBrowserTask
  include GithubProjectsHelpers

  def self.run!(opts = {})
    new(opts).run!
  end

  def initialize(opts = {})
    @opts = opts

    setup_logger

    read_config
    check_for_chromedriver
    validate_environment

    super
  end

  def run!
    run_and_close_driver do
      log_in_to_github
      author_whitelist = config["project_to_users_mapping"].values.flatten.uniq

      each_pull_request do |url, author|
        next unless author_whitelist.include?(author)

        logger.debug "Analyzing PR: ##{url.split('/').last} (#{author})"
        visit(url, log: false)

        projects = expected_projects_for(author) - current_projects
        logger.debug "  - Adding: #{projects}" if projects.any?

        projects.each { |project| toggle_project(project) }
      end
    end
  end
end
