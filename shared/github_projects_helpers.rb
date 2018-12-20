module GithubProjectsHelpers
  def projects_element
    # Github doesn't provide an easy selector for the projects section. Just
    # find the <form> element that corresponds to it
    driver
      .find_element(:id, "partial-discussion-sidebar")
      .find_elements(:tag_name, "form")
      .detect { |f| f.text =~ /Projects\n/ }
  end

  def expected_projects
    author = pr_author
    projects = []
    mapping = config["project_to_users_mapping"]

    mapping.each_key do |project|
      projects << project if mapping[project].include?(author)
    end

    projects.uniq
  end

  def current_projects
    tries ||= 3

    # Github presents the title as "<Column> in <Project>", so we also filter
    # for that here
    projects_element
      .find_elements(:class, "muted-link")
      .map { |ml| ml["title"].split(" in ").last }

    rescue
      retry unless (tries -= 1).zero?
  end

  def toggle_project(project_name)
    # The `sleep` statements account for async behavior in the browser

    # Open "Project" pop up
    click_projects_gear_icon
    sleep 0.25

    # Click "Repository" tab
    driver
      .find_elements(:class, "select-menu-tab-nav")
      .detect { |b| b.text == "Repository" }
      .click
    sleep 0.25

    # Search for the project
    driver
      .find_element(:id, "project-sidebar-filter-field")
      .send_keys(project_name)
    sleep 0.25

    # Select the second tab and then select the first results (index: 1)
    projects_element
      .find_elements(:class, "js-project-menu-container")[0]
      .find_elements(:class, "select-menu-list")
      .detect { |i| i.text =~ /#{project_name}/ }
      &.click

    # Escape toggle closes window.
    driver.find_element(:tag_name, "body").send_keys(:escape)
  end

  def click_projects_gear_icon
    projects_element.find_element(:tag_name, "summary").click
  end
end
