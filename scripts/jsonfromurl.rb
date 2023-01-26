require 'net/http'
require 'json'

def get_json_from_script_tag(url)
  uri = URI(url)
  response = Net::HTTP.get(uri)
  script_tag = response.match(/<script type="application\/ld\+json">(.*?)<\/script>/m)[1]
  JSON.parse(script_tag)
end

url = "https://music.apple.com/us/playlist/live-in-adelaide-19/pl.u-8aAVXLjfWJlP9D"
json_hash = get_json_from_script_tag(url)
puts json_hash