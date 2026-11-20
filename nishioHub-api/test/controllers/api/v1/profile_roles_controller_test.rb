require 'test_helper'
class Api::V1::ProfileRolesControllerTest < ActionDispatch::IntegrationTest
  ROLES=['mentee','mentor','Admin','Super Admin','moderator','organization','founder','user','Community Coordinator',nil].freeze
  def account(role,index)
    create_user(role:role&&create_role(role),email:"profile-role-#{index}@example.test",full_name:"Profile Person #{index}")
  end
  test 'all roles including roleless accounts persist their own common profile fields' do
    ROLES.each_with_index do |role,i|
      person=account(role,i);before_roles=person.effective_roles.map(&:id)
      values={full_name:"Updated Role Person #{i}",bio:"Saved bio #{i}",location:'Kampala, Uganda',website:"https://example.com/profile/#{i}",user_id:999999,role_id:create_role('Super Admin').id,is_active:false}
      values.merge!(school:'Test School',grade:'P.6') if person.has_role?('mentee')
      values.merge!(title:'Senior Educator',years_of_experience:7,hourly_rate:25.5,languages:['English','Luganda'],skills:['Teaching','Ruby']) if person.has_role?('mentor')
      patch '/api/v1/me/settings/profile',params:{profile:values},headers:auth_headers(person),as: :json
      assert_response :ok,role.to_s
      assert_equal "Saved bio #{i}",person.reload.bio;assert_equal 'Kampala, Uganda',person.location;assert person.is_active?
      assert_equal before_roles,person.effective_roles.map(&:id)
      get '/api/v1/me/settings',headers:auth_headers(person);assert_response :ok
      assert_equal "Saved bio #{i}",response.parsed_body.dig('profile','bio');assert_equal "https://example.com/profile/#{i}",response.parsed_body.dig('user','website')
      if person.has_role?('mentor')
        assert_equal 'Senior Educator',response.parsed_body.dig('professional','title');assert_equal ['Ruby','Teaching'],response.parsed_body.dig('professional','skills').sort
      else
        assert_nil response.parsed_body['professional']
      end
      get '/api/v1/users/me',headers:auth_headers(person);assert_equal "Saved bio #{i}",response.parsed_body['bio']
    end
  end
  test 'secondary and normalized role names grant their actual profile capabilities' do
    person=account('Admin',20)
    person.additional_roles<<create_role('Mentor');person.additional_roles<<create_role('Mentee')
    patch '/api/v1/me/settings/profile',params:{profile:{school:'Dual Role School',grade:'University',bio:'Multi role biography',title:'Research Mentor',years_of_experience:5,skills:['Research'],languages:['English']}},headers:auth_headers(person),as: :json
    assert_response :ok
    assert_equal 'Dual Role School',person.reload.mentee_profile.school
    assert_equal 'Research Mentor',person.mentor_profile.title
    assert_equal 'Multi role biography',person.mentee_profile.bio
    assert_equal 'Multi role biography',person.mentor_profile.bio
    assert_equal ['admin','mentee','mentor'],response.parsed_body.dig('user','roles').map{|r|r['name'].downcase}.sort
  end
  test 'non mentor fields cannot create a mentor profile and invalid changes roll back atomically' do
    person=account('user',30)
    patch '/api/v1/me/settings/profile',params:{profile:{full_name:'Must Not Save',title:'Unauthorized Mentor'}},headers:auth_headers(person),as: :json
    assert_response :forbidden;assert_equal 'Profile Person 30',person.reload.full_name;assert_nil person.mentor_profile
    person=account('mentor',31)
    patch '/api/v1/me/settings/profile',params:{profile:{full_name:'Must Roll Back',bio:'Must Roll Back',years_of_experience:-1}},headers:auth_headers(person),as: :json
    assert_response :unprocessable_entity;assert_equal 'Profile Person 31',person.reload.full_name;assert_nil person.bio;assert_nil person.mentor_profile
    [{website:'javascript:alert(1)'},{website:'https://user:password@example.com'},{skills:'Ruby'},{languages:['']},{bio:'x'*2001}].each do |values|
      patch '/api/v1/me/settings/profile',params:{profile:values},headers:auth_headers(person),as: :json
      assert_response :unprocessable_entity
    end
  end
  test 'email verification and required phone validation are independent of account role' do
    ROLES.each_with_index do |role,i|
      person=account(role,i+40)
      person.phone_number=nil;assert_not person.valid?,role.to_s;assert_includes person.errors[:phone_number],"can't be blank"
      person.reload
      get '/api/v1/users/verify-email',params:{token:EmailToken.encode(person.email)}
      assert_response :ok;assert person.reload.is_verified?
      assert_equal 'Email verified. You can now sign in to NishioHub.',response.parsed_body['detail']
    end
  end
  test 'all roles can upload and remove only their own avatar' do
    other=account('mentee',79)
    ROLES.each_with_index do |role,i|
      person=account(role,i+80)
      file=Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/profile-photo.png'),'image/png')
      post '/api/v1/me/settings/avatar',params:{avatar:file,user_id:other.id},headers:auth_headers(person)
      assert_response :ok;assert person.reload.avatar.attached?;assert_not other.reload.avatar.attached?
      delete '/api/v1/me/settings/avatar',params:{user_id:other.id},headers:auth_headers(person)
      assert_response :ok;assert_nil response.parsed_body.dig('user','avatar');assert_not person.reload.avatar.attached?
    end
  end
  test 'mentor canonical editor and common editor share saved biography' do
    mentor=create_mentor(email:'bio-sync@example.test')
    patch '/api/v1/me/settings/profile',params:{profile:{bio:'Common bio'}},headers:auth_headers(mentor),as: :json;assert_response :ok
    patch '/api/v1/me/mentor_profile',params:{bio:'Mentor editor bio'},headers:auth_headers(mentor),as: :json;assert_response :ok
    get '/api/v1/me/settings',headers:auth_headers(mentor);assert_equal 'Mentor editor bio',response.parsed_body.dig('profile','bio')
  end
end
