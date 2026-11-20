require 'cgi'
class AchievementCertificateDocument
  def initialize(award) = @award=award
  def svg
    a=@award;e=->(v){CGI.escapeHTML(v.to_s)};zone=SystemSetting.config['timezone']
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="850" viewBox="0 0 1200 850" role="img" aria-labelledby="title desc">
      <title id="title">#{e.call(a.title)}</title><desc id="desc">Awarded to #{e.call(a.user.full_name)}</desc>
      <rect width="1200" height="850" fill="#faf7ff"/><rect x="30" y="30" width="1140" height="790" rx="24" fill="white" stroke="#7826e6" stroke-width="8"/>
      <g text-anchor="middle" font-family="Arial,sans-serif" fill="#1c104e"><text x="600" y="145" font-size="40" font-weight="700">#{e.call(SystemSetting.config['platform_name'])}</text>
      <text x="600" y="260" font-size="38">Certificate of Achievement</text><text x="600" y="345" font-size="22">Presented to</text>
      <text x="600" y="410" font-size="34" font-weight="700">#{e.call(a.user.full_name)}</text><text x="600" y="495" font-size="27">#{e.call(a.title)}</text>
      <text x="600" y="565" font-size="20">#{e.call(a.platform_program&.title)}</text><text x="600" y="635" font-size="20">Issued #{a.awarded_at.in_time_zone(zone).strftime('%B %d, %Y')}</text>
      <text x="600" y="710" font-size="14">Record: #{e.call(a.identifier)}</text><text x="600" y="750" font-size="16">Awarded by #{e.call(a.issuer_name)}</text></g></svg>
    SVG
  end
end
