require 'common'

$LOAD_PATH.unshift "./lib"

require 'presentation_pb'

PRES_DIR = ARGV[0]
OUT_DIR = ARGV[1] if ARGV.length > 1

error "Please provide a presentation directory!" unless PRES_DIR.is_a? String
error "Presentation directory #{PRES_DIR} does not exist!" unless Dir.exists? PRES_DIR

error "Please provide an output directory!" unless OUT_DIR.is_a? String
Dir.mkdir(OUT_DIR) unless Dir.exists? OUT_DIR

def extract(presentation)
  cue_list = presentation.cue_groups
  groups = {}
  cue_list.each do |group|
    groups[group.group.uuid.string] = group.group.name
  end
  arrangements = {}
  presentation.arrangements.each do |arrangement|
    arrangements[arrangement.name] = arrangement.group_identifiers.map { |id| groups[id.string] }
  end
  lines = []
  arrangements.each do |name, group_names|
    lines << "Arrangement: \"#{name}\""
    group_names.each do |group_name|
      next if group_name == "Group"
      lines << group_name
    end
    lines << ""
  end
  lines
end

Dir.chdir PRES_DIR do
    Dir.glob("**/*").each do |path|
      next unless path.end_with? ".pro"
      info "Getting text from #{path}"
      pres = Rv::Data::Presentation.decode File.read(path)
      lines = extract(pres)
      next if lines.empty?
      out_path = File.join(OUT_DIR, File.basename(path, ".pro") + ".txt")
      File.open(out_path, 'w') do |file|
        lines.each_with_index do |line, index|
          file.write line
          file.write "\n" unless index == lines.length - 1
        end
      end
    end
end
