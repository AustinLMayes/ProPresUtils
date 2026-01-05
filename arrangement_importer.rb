require 'common'

$LOAD_PATH.unshift "./lib"

require 'presentation_pb'

PRES_DIR = ARGV[0]
IN_DIR = ARGV[1] if ARGV.length > 1

error "Please provide a presentation directory!" unless PRES_DIR.is_a? String
error "Presentation directory #{PRES_DIR} does not exist!" unless Dir.exists? PRES_DIR

error "Please provide an input directory!" unless IN_DIR.is_a? String
error "Input directory #{IN_DIR} does not exist!" unless Dir.exists? IN_DIR

presentations = {}
Dir.chdir PRES_DIR do
    Dir.glob("**/*").each do |path|
      next unless path.end_with? ".pro"
      info "Getting text from #{path}"
      name = File.basename(path, ".pro")
      presentations[name] = {path: path, arrangement: nil}
    end
end

Dir.chdir IN_DIR do
    Dir.glob("**/*").each do |path|
      next unless path.end_with? ".txt"
      name = File.basename(path, ".txt")
      unless presentations.key? name
        warning "No presentation found for arrangement file #{path}"
        next
      end
      info "Getting arrangement from #{path}"
      lines = []
      File.open(path, 'r') do |file|
        file.each_line do |line|
          lines << line.strip
        end
      end
      presentations[name][:arrangement] = lines
    end
end

Dir.chdir PRES_DIR do
    presentations.each do |name, data|
      next unless data[:arrangement].is_a? Array
      info "Updating arrangement for presentation #{name}"
      pres = Rv::Data::Presentation.decode File.read(data[:path])
      pres.arrangements.clear
      current_arrangement = nil
      data[:arrangement].each do |line|
        if line.start_with? "Arrangement:"
          if current_arrangement.is_a? Rv::Data::Presentation::Arrangement
            pres.arrangements << current_arrangement
          end
          arrangement_name = line.match(/Arrangement:\s*"(.*)"/)[1]
          current_arrangement = Rv::Data::Presentation::Arrangement.new
          current_arrangement.uuid = Rv::Data::UUID.new(string: SecureRandom.uuid)
          current_arrangement.name = arrangement_name
        elsif line.strip.length > 0
          if current_arrangement.is_a? Rv::Data::Presentation::Arrangement
            group = pres.cue_groups.find { |g| g.group.name == line.strip }
            if group.is_a? Rv::Data::Presentation::CueGroup
              current_arrangement.group_identifiers << group.group.uuid
            else
              warning " - No cue group named '#{line.strip}' found, skipping"
            end
          end
        end
      end
      if current_arrangement.is_a? Rv::Data::Presentation::Arrangement
        pres.arrangements << current_arrangement
      end
      original = Rv::Data::Presentation.decode File.read(data[:path]) # Deep copy
      different = false
      if original.arrangements.length != pres.arrangements.length
        different = true
      else
        pres.arrangements.each do |arrangement|
          orig_arrangement = original.arrangements.find { |a| a.name == arrangement.name }
          if !orig_arrangement.is_a? Rv::Data::Presentation::Arrangement
            different = true
            break
          elsif orig_arrangement.group_identifiers != arrangement.group_identifiers
            different = true
            break
          end
        end
      end
      if different
        File.open(data[:path], 'wb') do |file|
          file.write Rv::Data::Presentation.encode(pres)
        end
        info " - Arrangement updated"
      else
        info " - No changes needed"
      end
    end
end
