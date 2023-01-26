require 'rspotify'
require 'json'
require 'yaml'
require 'net/http'
require 'nokogiri'
require 'openssl'
require 'cgi'
require 'byebug'

TOKEN = 'BQBtqp0TKiArl6iJIH3RL43IrTiSUp5vwCPowRL563tLiHtAPfz_PNLZfrkMky-cM6Yo0SKQiz7KC6URP5O3urXBrfnQjgkCkW1__joL-lrNVsXcOT-BxWxeILkxlepvISASQxcmsUwmx5mdUhCpFZcv1N5cU6zZBHxX70H8jkYE2zkEL0-ALVOKM7l1N09LHAqo9a78gb8V'

def find_song(name)
  query = %Q[#{name} track:#{name} artist:King Gizzard & The Lizard Wizard]
  query = CGI.escapeURIComponent(query)
  url = URI(%Q[https://api.spotify.com/v1/search?q=#{query}&type=track&limit=10])

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Get.new(url)
  request["Authorization"] = "Bearer #{TOKEN}"

  response = http.request(request)
  songs = JSON.parse(response.read_body)['tracks']['items']
  if songs.empty?
    byebug
  end
  song = songs.detect { |song| song['name'].downcase.gsub("'", '') == name.downcase}
  byebug if song.nil?
  song
end

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
  JSON.parse(script&.content)
end

# Authenticate with Spotify
RSpotify.authenticate(ENV['SPOTIFY_CLIENT'], ENV['SPOTIFY_SECRET'])

puts("Click here and authorize: https://accounts.spotify.com/authorize?response_type=token&client_id=#{ENV['SPOTIFY_CLIENT']}&redirect_uri=https://localhost:8888/callback&scope=playlist-modify-public")
# token = gets('Enter the oath token:')

Dir.glob("../_posts/*.md") do |file_path|
  post = Psych.safe_load_file(file_path, permitted_classes: [Date])
  if (post['spotify'])
    puts "Skipping #{file_path}, already done."
  elsif (post['apple'])
    puts "Processing #{file_path}..."
    print "Retrieving playlist data from #{post['apple']}..."
  	playlist_json = get_music_playlist_from_url(post['apple'])
    puts ' done.'
    print "Creating playlist #{playlist_json['name']}..."
    playlist = make_playlist(playlist_json["name"], 'test')
    url = playlist['external_urls']['spotify']
    puts ' done.'

    puts "Parsing tracklist..."
  	tracks = playlist_json['track'].map { |track| 
      puts "searching for #{track["name"]}"
			song = find_song(track["name"].gsub("'", ''))
      if song.nil? || song['name'].downcase != track['name'].downcase
        byebug
        puts "Mismatch detected!!!!!!!"
      end 
      byebug if song.nil?
      puts "Found song #{song['name']} on #{song['album']['name']}!"
      song['uri']
		}
    puts ' done.'

    print "Adding #{tracks.length} songs to playlist..."
		add_songs(playlist['id'], tracks)
    puts ' done.'
    print "Adding spotify url to file..."
    post['spotify'] = url
    File.open(file_path, 'w') do |file|
      file.write(post.to_yaml)
      file.write("---\n")
    end
    puts ' done.'
  else
    puts "Skipping #{file_path}, no Apple playlist found"
  end
end
puts "All done. Bye bye."

