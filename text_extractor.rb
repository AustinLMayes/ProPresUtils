require 'common'
require 'ruby-rtf'

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
    groups[group.group.uuid.string] = {name: group.group.name, cues: group.cue_identifiers, content: []}
  end
  presentation.cues.each do |cue|
    found_group = nil
    groups.each do |uuid, group|
      if group[:cues].include? cue.uuid
        found_group = group
        break
      end
    end
    next if found_group.nil?
    content = nil
    cue.actions.each do |action|
      if action.type == :ACTION_TYPE_PRESENTATION_SLIDE && action.slide.presentation
        base_slide = action.slide.presentation.base_slide

        if base_slide.elements.length > 0
          base_slide.elements.each do |element|
            plain = RubyRTF::Parser.new(unknown_control_warning_enabled: false).parse(element.element.text.rtf_data).sections.map{ | s | s[:text].strip }.filter{ | t | !t.empty? }
            next if plain.empty?
            # is<U+0097>a膗mighty God -> He is a mighty
            plain.map! do |line|
              line.gsub!("\u0097", " ")
              line.gsub!("\u8517", " ")
              line.gsub!("膗", " ")
              # curly apostrophes to straight
              line.gsub!("\u2019", "'")
              line
            end
            content = plain
            break
          end
        end

        break unless content.nil?
      end
    end
    next if content.nil?
    cue_index = found_group[:cues].index(cue.uuid)
    found_group[:content][cue_index] = content
  end
  lines = []
  groups.each do |uuid, group|
    next if group[:content].empty?
    lines << "#{group[:name]}"
    group[:content].each do |content|
      lines << content.join("\n")
      lines << ""
    end
  end
  lines
end

Dir.chdir PRES_DIR do
    Dir.glob("**/*").each do |path|
      next unless path.end_with? ".pro"
      info "Getting text from #{path}"
      pres = Rv::Data::Presentation.decode File.read(path)
      lines = extract(pres)
      out_path = File.join(OUT_DIR, File.basename(path, ".pro") + ".txt")
      File.open(out_path, 'w') do |file|
        lines.each_with_index do |line, index|
          file.write line
          file.write "\n" unless index == lines.length - 1
        end
      end
    end
end
