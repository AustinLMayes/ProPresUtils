require 'common'
require 'ruby-rtf'

$LOAD_PATH.unshift "./lib"

require 'presentation_pb'

PRES_DIR = ARGV[0]
CLEAR_VISUALS = true

error "Please provide a presentation directory!" unless PRES_DIR.is_a? String
error "Presentation directory #{PRES_DIR} does not exist!" unless Dir.exists? PRES_DIR

def fix_name(file, presentation)
  file_name = File.basename(file, ".pro")

  if presentation.name != file_name
    info " - Updating name from '#{presentation.name}' to '#{file_name}'"
    presentation.name = file_name
  end

  if presentation.name.include?("-")
    parts = presentation.name.split("-", 2).map(&:strip)
    title = parts[0]
    author = parts[1]

    if presentation.ccli.nil?
      presentation.ccli = Rv::Data::Presentation::CCLI.new
    end

    if presentation.ccli.song_title != title
      info " - Setting CCLI song title to '#{title}'"
      presentation.ccli.song_title = title
    end

    if author.downcase != "hymn" && presentation.ccli.author != author
      info " - Setting CCLI author to '#{author}'"
      presentation.ccli.author = author
    end
  end
end

def add_spacer(presentation)
  presentation.cue_groups.each_with_index do |group, index|
    if group.group.name.downcase == "spacer" && index == 1
      return
    end
  end

  presentation.cue_groups.each do |group|
    if group.group.name.downcase == "spacer"
      warning " - Spacer group found but not at correct position, moving"
      presentation.cue_groups.delete(group)
      presentation.cue_groups.insert(1, group)
      return
    end
  end

  cue_id = Rv::Data::UUID.new(string: SecureRandom.uuid)
  group_id = Rv::Data::UUID.new(string: SecureRandom.uuid)

  spacer_group = Rv::Data::Presentation::CueGroup.new
  spacer_group.group = Rv::Data::Group.new
  spacer_group.group.uuid = group_id
  spacer_group.group.name = "Spacer"
  spacer_group.group.color = Rv::Data::Color.new(alpha: 1)
  spacer_group.group.application_group_identifier = Rv::Data::UUID.new(string: "FE4C597C-0E8C-44C4-A038-AFA1D720CE6A")
  spacer_group.cue_identifiers << cue_id

  presentation.cue_groups.insert(1, spacer_group)

  spacer_cue = Rv::Data::Cue.new
  spacer_cue.uuid = cue_id
  spacer_cue.completion_action_type = :COMPLETION_ACTION_TYPE_LAST
  spacer_cue.isEnabled = true
  action = Rv::Data::Action.new
  action.uuid = Rv::Data::UUID.new(string: SecureRandom.uuid)
  action.isEnabled = true
  action.type = :ACTION_TYPE_PRESENTATION_SLIDE
  slide_type = Rv::Data::Action::SlideType.new
  pres_slide = Rv::Data::PresentationSlide.new
  base_slide = Rv::Data::Slide.new
  base_slide.background_color = Rv::Data::Color.new(red: 1, green: 1, blue: 1, alpha: 1)
  base_slide.size = Rv::Data::Graphics::Size.new(width: 1920, height: 1080)
  base_slide.uuid = Rv::Data::UUID.new(string: SecureRandom.uuid)
  pres_slide.base_slide = base_slide
  slide_type.presentation = pres_slide
  action.slide = slide_type
  spacer_cue.actions << action

  presentation.cues.unshift(spacer_cue)
end

def add_visual(presentation)
  group_id = Rv::Data::UUID.new(string: SecureRandom.uuid)
  found_existing = false
  needs_move = true

  presentation.cue_groups.each_with_index do |group, index|
    if group.group.name.downcase == "visual"
      found_existing = true
      group_id = group.group.uuid
      if index == 0
        needs_move = false
      end
    end
  end

  presentation.cue_groups.each do |group|
    if group.group.name.downcase == "visual"
      warning " - Visual group found but not at start, moving to start"
      presentation.cue_groups.delete(group)
      presentation.cue_groups.unshift(group)
      return if group.cue_identifiers.length == 1
    end
  end if needs_move

  if found_existing
    visual_group = presentation.cue_groups.find { |g| g.group.uuid == group_id }
  else
    visual_group = Rv::Data::Presentation::CueGroup.new
    visual_group.group = Rv::Data::Group.new
    visual_group.group.uuid = group_id
    visual_group.group.name = "Visual"
    visual_group.group.color = Rv::Data::Color.new(red: 0.999996, green: 1, blue: 1, alpha: 1)
    visual_group.group.application_group_identifier = Rv::Data::UUID.new(string: "0504D58C-15F3-47D9-8081-1438C0CF60C4")
    visual_group.cue_identifiers << cue_id

    presentation.cue_groups.unshift(visual_group)
  end

  if CLEAR_VISUALS && visual_group.cue_identifiers.length > 0
    presentation.cues.delete_if do |cue|
      if visual_group.cue_identifiers.include?(cue.uuid)
        if cue.actions.length > 1
          visual_group.cue_identifiers.delete(cue.uuid)
          true
        else
          false
        end
      else
        false
      end
    end
  end

  if visual_group.cue_identifiers.length == 0
    visual_cue = Rv::Data::Cue.new
    cue_id = Rv::Data::UUID.new(string: SecureRandom.uuid)
    visual_cue.uuid = cue_id
    visual_cue.completion_action_type = :COMPLETION_ACTION_TYPE_LAST
    visual_cue.isEnabled = true
    action = Rv::Data::Action.new
    action.uuid = Rv::Data::UUID.new(string: SecureRandom.uuid)
    action.isEnabled = true
    action.type = :ACTION_TYPE_PRESENTATION_SLIDE
    slide_type = Rv::Data::Action::SlideType.new
    pres_slide = Rv::Data::PresentationSlide.new
    base_slide = Rv::Data::Slide.new
    base_slide.background_color = Rv::Data::Color.new(red: 1, green: 1, blue: 1, alpha: 1)
    base_slide.size = Rv::Data::Graphics::Size.new(width: 1920, height: 1080)
    base_slide.uuid = Rv::Data::UUID.new(string: SecureRandom.uuid)
    pres_slide.base_slide = base_slide
    slide_type.presentation = pres_slide
    action.slide = slide_type
    visual_cue.actions << action

    presentation.cues.unshift(visual_cue)

    visual_group.cue_identifiers << cue_id
  elsif visual_group.cue_identifiers.length > 1
    warning " - Multiple visual cues found, keeping only the first"
    first_cue_id = visual_group.cue_identifiers.first
    visual_group.cue_identifiers = [first_cue_id]
    presentation.cues.delete_if { |c| c.uuid != first_cue_id && visual_group.cue_identifiers.include?(c.uuid) }
  end
end

def fix_transitions(presentation)
  presentation.cues.each do |cue|
    cue.actions.each do |action|
      spacer = true

      if action.type == :ACTION_TYPE_PRESENTATION_SLIDE && action.slide.presentation
        base_slide = action.slide.presentation.base_slide

        if base_slide.elements.length > 0
          base_slide.elements.each do |element|
            plain = RubyRTF::Parser.new(unknown_control_warning_enabled: false).parse(element.element.text.rtf_data).sections.map{ | s | s[:text].strip }.filter{ | t | !t.empty? }
            next if plain.empty?
            spacer = false
            break
          end
        end

        if !spacer
          unless action.slide.presentation.transition
            transition = Rv::Data::Transition.new
            transition.favorite_uuid = Rv::Data::UUID.new(string: "22E1DAE1-54DE-44B1-91F0-93C0932091E0")
            effect = Rv::Data::Effect.new
            effect.uuid = Rv::Data::UUID.new(string: SecureRandom.uuid)
            effect.name = "Cut"
            effect.render_id = "AB29D07B-E9E2-4E0A-93BD-AD3EA58120FA"
            effect.behavior_description = "Cut."
            effect.category = "None"
            transition.effect = effect
            action.slide.presentation.transition = transition
          end
        else
          action.slide.presentation.transition = nil
        end
      end
    end
  end
end

Dir.chdir PRES_DIR do
    Dir.glob("**/*").each do |path|
      next unless path.end_with? ".pro"
      info "Cleaning presentation file #{path}"
      pres = Rv::Data::Presentation.decode File.read(path)
      original = Rv::Data::Presentation.decode File.read(path) # Deep copy
      fix_name(path, pres)
      pres.selected_arrangement = nil
      add_visual(pres)
      add_spacer(pres)
      fix_transitions(pres)

      if pres.== original
        info " - No changes needed"
      else
        info " - Changes detected, saving file"
        File.write path, Rv::Data::Presentation.encode(pres)
      end
    end
end
