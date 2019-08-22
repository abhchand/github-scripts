module PersonNameHelpers
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
    people_list.map { |person| to_github_user(person) }
  end

  def to_github_user(person)
    people[name.downcase]["github"]
  end

  def to_slack_users(people_list)
    people_list.map { |person| to_slack_user(person) }
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

  def find_github_by_slack(slack_name)
    people.each do |person, mapping|
      if mapping["slack"].downcase == slack_name.downcase
        return mapping["slack"]
      end
    end
  end
end
