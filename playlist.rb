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

library = Rv::Data::PlaylistDocument.decode File.read(LIBRARY_PLAYLIST)
first_playlist = library.root_node.playlists.playlists[0]
first_playlist.items.items.each do |item|
  path = item.presentation.document_path.local.path
  path = File.join(PRO_PRES_DIR, path)
  next unless File.exist? path
  pres = Rv::Data::Presentation.decode File.read(path)
  original = Rv::Data::Presentation.decode File.read(path) # Deep copy
  pl_arrangement = item.presentation.arrangement

  found = false
  pres.arrangements.each do |arrangement|
    if arrangement.name == "v0 - Praise Break"
      found = true
      pl_arrangement = arrangement.uuid
      break
    end
  end

  item.presentation.arrangement = pl_arrangement

  next if found

  arrangement = Rv::Data::Presentation::Arrangement.new
  arrangement.uuid = Rv::Data::UUID.new(string: SecureRandom.uuid)
  arrangement.name = "v0 - Praise Break"

  # add to the first of the arrangements list
  pres.arrangements.unshift arrangement

  item.presentation.arrangement = arrangement.uuid

  if pres.== original
    debug " - No changes needed"
  else
    info " - Changes detected, saving file #{path}"
    File.write path, Rv::Data::Presentation.encode(pres)
  end
end

# sort items by name and re-add them
first_playlist.items.items.sort_by! { |item| item.presentation.document_path.local.path.downcase }

# write playlist back
File.open(LIBRARY_PLAYLIST, 'w') do |file|
  file.write Rv::Data::PlaylistDocument.encode(library)
end
