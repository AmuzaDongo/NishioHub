class PlatformMailer < ActionMailer::Base
  def verification
    user = params[:user]
    url = "#{params[:base_url]}/api/v1/users/verify-email?token=#{CGI.escape(EmailToken.encode(user.email))}"
    mail(to: user.email, from: ENV.fetch('MAIL_FROM', 'support@nishiohub.com'), subject: 'Verify your NishioHub email') do |format|
      format.text { render plain: "Hello #{user.full_name},\n\nVerify your email using this link (valid for 30 minutes):\n#{url}\n\nIf you did not create an account, ignore this email." }
    end
  end

  def test_email
    mail(to: params[:user].email, from: ENV.fetch('MAIL_FROM', 'support@nishiohub.com'), subject: "#{params[:platform_name]} email delivery test") do |format|
      format.text { render plain: 'This test confirms that platform email delivery is configured. No settings were changed.' }
    end
  end
end
