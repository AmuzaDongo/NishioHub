require "test_helper"

class Api::V1::MenteeGoalsControllerTest < ActionDispatch::IntegrationTest
  def learner(email = "goals@example.com", role = "mentee")
    User.create!(full_name: "Goal Learner", email: email, password: "secret123",
      phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}", role: create_role(role))
  end

  test "goals workspace requires an authenticated mentee" do
    get "/api/v1/me/mentee_goals"
    assert_response :unauthorized
    get "/api/v1/me/mentee_goals", headers: auth_headers(learner("mentor-goals@example.com", "mentor"))
    assert_response :forbidden
  end

  test "goal edits preserve legacy completion and record only changed progress" do
    student = learner
    post "/api/v1/me/mentee_goals", headers: auth_headers(student), params: {
      goal: { title: "Learn programming", description: "Build a project", target_date: "2027-03-31", progress: 40, icon: "code" }
    }, as: :json
    assert_response :created
    goal = student.mentee_goals.last
    assert_equal 40, goal.progress
    refute goal.completed
    assert_equal Date.new(2027, 3, 31), goal.target_date
    assert_equal 1, goal.goal_progress_events.count
    patch "/api/v1/me/mentee_goals/#{goal.id}", headers: auth_headers(student), params: { goal: { progress: 75 } }, as: :json
    assert_response :ok
    patch "/api/v1/me/mentee_goals/#{goal.id}", headers: auth_headers(student), params: { goal: { progress: 75, title: "Programming practice" } }, as: :json
    assert_response :ok
    assert_equal 2, goal.goal_progress_events.count
    patch "/api/v1/me/mentee_goals/#{goal.id}", headers: auth_headers(student), params: { goal: { completed: true } }, as: :json
    assert_response :ok
    assert_equal 100, goal.reload.progress
    assert goal.completed
    patch "/api/v1/me/mentee_goals/#{goal.id}", headers: auth_headers(student), params: { goal: { progress: 20 } }, as: :json
    assert_response :ok
    refute goal.reload.completed
    get "/api/v1/me/mentee_goals", headers: auth_headers(student)
    assert_equal 20, response.parsed_body["goals"].first["progress"]
    assert_equal 4, response.parsed_body["history"].size
    assert_equal 20, response.parsed_body["history"].first["progress"]
  end

  test "invalid goal values are rejected" do
    student = learner
    [{ title: " " }, { title: "Test", progress: -1 }, { title: "Test", progress: 101 }, { title: "Test", progress: 2.5 }, { title: "Test", icon: "untrusted" }].each do |goal|
      post "/api/v1/me/mentee_goals", headers: auth_headers(student), params: { goal: goal }, as: :json
      assert_response :unprocessable_entity
    end
    assert_empty student.mentee_goals
  end

  test "milestones and goal histories are private to the owner" do
    owner = learner
    other = learner("other-goals@example.com")
    goal = owner.mentee_goals.create!(title: "Private goal")
    other_goal = other.mentee_goals.create!(title: "Other private goal")
    milestone = goal.goal_milestones.create!(title: "First project")
    other_milestone = other_goal.goal_milestones.create!(title: "Other milestone")
    patch "/api/v1/me/mentee_goals/#{goal.id}", headers: auth_headers(other), params: { goal: { progress: 100 } }, as: :json
    assert_response :not_found
    delete "/api/v1/me/mentee_goals/#{goal.id}", headers: auth_headers(other)
    assert_response :not_found
    post "/api/v1/me/mentee_goals/#{goal.id}/milestones", headers: auth_headers(other), params: { milestone: { title: "No access" } }, as: :json
    assert_response :not_found
    patch "/api/v1/me/mentee_goals/#{other_goal.id}/milestones/#{milestone.id}", headers: auth_headers(other), params: { milestone: { completed: true } }, as: :json
    assert_response :not_found
    delete "/api/v1/me/mentee_goals/#{goal.id}/milestones/#{other_milestone.id}", headers: auth_headers(owner)
    assert_response :not_found
    get "/api/v1/me/mentee_goals", headers: auth_headers(other)
    refute_includes response.body, "Private goal"
    assert_equal [other_goal.id], response.parsed_body["goals"].map { |item| item["id"] }
    assert response.parsed_body["history"].all? { |event| event["goal_id"] == other_goal.id }
  end

  test "milestones can be added completed and removed without rewriting manual progress" do
    student = learner
    goal = student.mentee_goals.create!(title: "Learn coding", progress: 40)
    post "/api/v1/me/mentee_goals/#{goal.id}/milestones", headers: auth_headers(student), params: { milestone: { title: "Build a page", target_date: "2027-01-31" } }, as: :json
    assert_response :created
    id = response.parsed_body["id"]
    patch "/api/v1/me/mentee_goals/#{goal.id}/milestones/#{id}", headers: auth_headers(student), params: { milestone: { completed: true } }, as: :json
    assert_response :ok
    assert GoalMilestone.find(id).completed
    assert_equal 40, goal.reload.progress
    delete "/api/v1/me/mentee_goals/#{goal.id}/milestones/#{id}", headers: auth_headers(student)
    assert_response :no_content
    refute GoalMilestone.exists?(id)
  end

  test "vision persists only for the signed in learner" do
    student = learner
    other = learner("other-vision@example.com")
    patch "/api/v1/me/goal_vision", headers: auth_headers(student), params: { profile: { vision: "Use technology to help my community", user_id: other.id } }, as: :json
    assert_response :ok
    assert_nil other.reload.mentee_profile
    get "/api/v1/me/mentee_goals", headers: auth_headers(student)
    assert_equal "Use technology to help my community", response.parsed_body["vision"]
    patch "/api/v1/me/goal_vision", headers: auth_headers(student), params: { profile: { vision: "a" * 1001 } }, as: :json
    assert_response :unprocessable_entity
  end

  test "deleting a goal removes its milestones and history" do
    student = learner
    goal = student.mentee_goals.create!(title: "Temporary goal")
    goal.goal_milestones.create!(title: "Temporary step")
    delete "/api/v1/me/mentee_goals/#{goal.id}", headers: auth_headers(student)
    assert_response :no_content
    refute MenteeGoal.exists?(goal.id)
    refute GoalMilestone.exists?(mentee_goal_id: goal.id)
    refute GoalProgressEvent.exists?(mentee_goal_id: goal.id)
  end
end
