require 'rubygems/package'
require 'zlib'
require 'stringio'
class SessionMaterialArchive
  def self.build(assets)
    size = assets.sum { |a| a.file.attached? ? a.file.byte_size : 0 }
    raise Administration::Rejected.new('Download materials individually when their combined size exceeds 50 MB', :unprocessable_entity) if size > 50.megabytes
    output = StringIO.new; gzip = Zlib::GzipWriter.new(output)
    Gem::Package::TarWriter.new(gzip) do |tar|
      links = []
      assets.each do |asset|
        if asset.file.attached?
          bytes = asset.file.download
          name = "#{asset.id}-#{asset.file.filename.to_s.gsub(/[^a-zA-Z0-9._-]/, '_').first(90)}"
          tar.add_file_simple(name, 0o644, bytes.bytesize) { |entry| entry.write(bytes) }
        else
          links << "#{asset.title}\n#{asset.url}"
        end
      end
      if links.any?
        text = links.join("\n\n") + "\n"
        tar.add_file_simple('material-links.txt', 0o644, text.bytesize) { |entry| entry.write(text) }
      end
    end
    gzip.finish; output.string
  end
end
