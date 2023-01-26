require 'rspotify'
require 'json'
require 'yaml'
require 'net/http'
require 'nokogiri'
require 'openssl'
require 'byebug'

TOKEN = 'BQCMOe_-JsfxRHRU0xMAnRHBDj3jCXVfYZDuOMf_9w8cWcgMbJu8kiJ_007KsVataD8mfdh0cWLV2kCx0WwkntuYKXRaSklR4eiaGd3Y3EZc7CK_YehW1Mcao7bncLD3KOOe5Qn2AXd7Y3SpSaZ2Vm5iMzk7nYREVlFomRsNpb-IV2vy7vTQhmHPr4soqo7Ny5gEUTIw-F52'

def make_playlist(name, description)
  url = URI("https://api.spotify.com/v1/users/1267237896/playlists")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Post.new(url)
  request["Content-Type"] = 'application/json'
  request["Authorization"] = "Bearer #{TOKEN}"
  request.body = "{\n\t\"name\": \"#{name}\",\n\t\"description\": \"#{description}\"\n}"

  response = http.request(request)
  JSON.parse(response.read_body)
end

def add_songs(playlist_id, songs)
  url = URI("https://api.spotify.com/v1/playlists/#{playlist_id}/tracks")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Post.new(url)
  request["Content-Type"] = 'application/json'
  request["Authorization"] = "Bearer #{TOKEN}"
  request.body = "{\n\t\"uris\": #{songs.to_s.gsub!(' ', '')},\n\t\"position\": 0\n}"

  response = http.request(request)
  JSON.parse(response.read_body)
end

# pass this the URL of an Apple Music playlist and it will return the schema.org MusicPlaylist
def get_music_playlist_from_url(url)
  uri = URI(url)
  response = Net::HTTP.get(uri)
  doc = Nokogiri::HTML(response)
  script = doc.at_xpath("//script[@id='schema:music-playlist']")
  JSON.parse(script.content)
end

# Authenticate with Spotify
RSpotify.authenticate(ENV['SPOTIFY_CLIENT'], ENV['SPOTIFY_SECRET'])

puts("Click here and authorize: https://accounts.spotify.com/authorize?response_type=token&client_id=#{ENV['SPOTIFY_CLIENT']}&redirect_uri=https://localhost:8888/callback&scope=playlist-modify-public")
# token = gets('Enter the oath token:')

Dir.glob("../_posts/*.md") do |file_path|
  post = Psych.safe_load_file(file_path, permitted_classes: [Date])
  if (post['apple'])
    puts "Creating playlist for #{file_path}"
    print "Retrieving playlist data from #{post['apple']}..."
  	playlist_json = get_music_playlist_from_url(post['apple'])
    puts 'done.'
    print "Creating playlist #{playlist_json['name']}..."
    playlist = make_playlist(playlist_json["name"], 'test')
    url = playlist['external_urls']['spotify']
    puts 'done.'

    print "Parsing tracklist..."
  	tracks = playlist_json['track'].map { |track| 
			song = RSpotify::Track.search("track:#{track["name"]} artist:King Gizzard & The Lizard Wizard", limit: 1)[0]
      puts "Found song #{song.name} from #{song.album}!"
		}
    puts 'done.'

    print "Adding #{tracks.length} songs to playlist..."
		add_songs(playlist['id'], tracks)
    puts 'done.'
    print "Adding spotify url to file..."
    post['spotify'] = url
    File.open(file_path, 'w') do |file|
      file.write(post.to_yaml)
    end
    puts 'done.'
  else
    puts "Skipping #{file_path}, no Apple playlist found"
  end
end
puts "All done. Bye bye."

