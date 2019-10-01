module GithubApiHelpers
  def fetch_pull_requests
    # Documentation: https://developer.github.com/v3/pulls
    logger.info("Fetching Pull Requests")

    path = ["/repos", github_org, github_repo, "pulls"].join("/")
    query_params = { state: "open", sort: "created", direction: "desc" }

    get(path, query: query_params).tap do |pull_requests|
      logger.info("Found #{pull_requests.size} pull requests")
    end
  end

  def fetch_pull_request_files_for(pull_request)
    # Documentation: https://developer.github.com/v3/pulls
    logger.info("Fetching Pull Request files for ##{pull_request['number']}")

    path = [
      "/repos",
      github_org,
      github_repo,
      "pulls",
      pull_request["number"],
      "files"
    ].join("/")

    get(path)
  end

  def fetch_projects
    # Documentation: https://developer.github.com/v3/projects
    logger.info("Fetching projects")

    path = ["/repos", github_org, github_repo, "projects"].join("/")
    response = get(path)
    project_ids = projects.keys

    response.select { |project| project_ids.include?(project["number"]) }
  end

  def fetch_columns_for(project)
    # Documentation: https://developer.github.com/v3/projects/columns
    logger.info(
      "Fetching columns for project ##{project['number']} '#{project['name']}'"
    )

    url = project["columns_url"]
    get(url)
  end

  def fetch_cards_in(column)
    # Documentation: https://developer.github.com/v3/projects/cards
    logger.debug(
      "Fetching cards for column ##{column['number']} '#{column['name']}'"
    )

    url = column["cards_url"]
    get(url)
  end

  def fetch_issue_for(card)
    # Documentation: https://developer.github.com/v3/issues
    logger.debug("Fetching issue for card ##{card['id']}")

    url = card["content_url"]
    # If the card is not an issue (e.g. a note, etc..) it may not have a
    # content url.
    get(url)&.first if url
  end
end
