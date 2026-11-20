require "cgi"

class LearningCertificateDocument
  def initialize(certificate)
    @certificate = certificate
  end

  def svg
    enrollment = @certificate.learning_enrollment
    name = escape(enrollment.user.full_name)
    title = escape(LearningCatalog.find(enrollment.course_key).fetch("title"))
    issued = @certificate.issued_at.in_time_zone("Africa/Kampala").strftime("%B %d, %Y")
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="850" viewBox="0 0 1200 850" role="img" aria-labelledby="title desc">
        <title id="title">NishioHub Course Completion Certificate</title>
        <desc id="desc">#{name} completed #{title}. Issued #{issued}.</desc>
        <rect width="1200" height="850" fill="#faf7ff"/>
        <rect x="28" y="28" width="1144" height="794" rx="24" fill="white" stroke="#7826e6" stroke-width="8"/>
        <rect x="50" y="50" width="1100" height="750" rx="18" fill="none" stroke="#e6d7ff" stroke-width="2"/>
        <g text-anchor="middle" font-family="Arial, sans-serif" fill="#1c104e">
          <text x="600" y="132" font-size="38" font-weight="700">NishioHub</text>
          <text x="600" y="174" font-size="17" fill="#765595">Discover. Learn. Grow.</text>
          <text x="600" y="275" font-size="45" font-weight="700">Certificate of Completion</text>
          <text x="600" y="344" font-size="21">This certificate recognizes</text>
          <text x="600" y="409" font-size="30" font-weight="700">#{name}</text>
          <text x="600" y="469" font-size="21">for completing all lessons and practice activities in</text>
          <text x="600" y="526" font-size="29" font-weight="700" fill="#7422d6">#{title}</text>
          <text x="600" y="594" font-size="20">Issued: #{issued}</text>
          <text x="600" y="680" font-size="14" fill="#806991">Record ID: #{@certificate.identifier}</text>
          <text x="600" y="723" font-size="16" fill="#806991">NishioHub learning course completion record</text>
        </g>
        <path d="m600 194 6 13 14 2-10 10 2 14-12-7-12 7 2-14-10-10 14-2z" fill="#ffb700"/>
      </svg>
    SVG
  end

  private

  def escape(value)
    CGI.escapeHTML(value.to_s)
  end
end
