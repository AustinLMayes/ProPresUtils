require 'common'
require 'ruby-rtf'

$LOAD_PATH.unshift "./lib"

require 'propresenter_pb'
require 'presentation_pb'

PRO_PRES_DIR = ARGV[0]

error "Please provide ProPresenter directory!" unless PRO_PRES_DIR.is_a? String
error "ProPresenter directory #{PRO_PRES_DIR} does not exist!" unless Dir.exists? PRO_PRES_DIR

PLAYLIST_DIR = File.join(PRO_PRES_DIR, "Playlists")
LIBRARIES_DIR = File.join(PRO_PRES_DIR, "Libraries")

LIBRARY_PLAYLIST = File.join(PLAYLIST_DIR, "Library")

def extract(presentation, arrangement)
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
            plain.map! do |line|
              # curly apostrophes to straight
              line.gsub!("\u2019", "'")
              # remove non ASCII characters (keep accented letters)
              line.encode!("UTF-8", invalid: :replace, undef: :replace, replace: '')
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
  arrangement.group_identifiers.each do |group_id|
    group = groups[group_id.string]
    next if group.nil?
    lines << "#{group[:name]}"
    next if group[:content].empty?
    group[:content].each do |content|
      next if content.nil? || content.empty?
      lines << content.join("\n")
      lines << ""
    end
  end
  lines
end

library = Rv::Data::PlaylistDocument.decode File.read(LIBRARY_PLAYLIST)
first_playlist = library.root_node.playlists.playlists[0]
lines = []

first_playlist.items.items.each do |item|
  path = item.presentation.document_path.local.path
  path = File.join(PRO_PRES_DIR, path)
  next unless File.exist? path
  pres = Rv::Data::Presentation.decode File.read(path)
  pl_arrangement = item.presentation.arrangement
  next if pl_arrangement.nil?

  arrangement = pres.arrangements.find { |a| a.uuid == pl_arrangement }
  next unless arrangement

  lines << "#{pres.name}:"
  lines += extract(pres, arrangement)
  lines << ""
end

File.open("playlist.txt", "w") do |file|
  lines.each_with_index do |line, index|
    file.write line
    file.write "\n" unless index >= lines.length - 2
  end
end
