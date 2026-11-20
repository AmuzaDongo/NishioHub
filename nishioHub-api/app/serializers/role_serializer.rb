class RoleSerializer
  def initialize(role)
    @role = role
  end

  def as_json(*)
    { id: @role.id, name: @role.name }
  end
end
