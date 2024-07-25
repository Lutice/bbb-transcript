require 'net/http'
require 'json'
require 'yaml'
require_relative '/usr/local/bigbluebutton/core/lib/bbb-transcript/token_get.rb'
require_relative '/usr/local/bigbluebutton/core/lib/bbb-transcript/fields_checker.rb'


token_value = TokenManager.getToken(false)


# puts "Loading configuration..."
config = YAML.load_file("/etc/bigbluebutton.custom/bbb-transcript/aristote_config.yml")
FieldsChecker.assertFields(config,
	# Required params
	[
		'aristote-server.url',
		'aristote-server.paths.list-enrichments'
	],
	# Optionnal params
	[
		# None
	],
	{ activated: true, color: true }
)


## Enrichments ID REQUEST
req_url = "#{config['aristote-server']['url']}#{config['aristote-server']['paths']['list-enrichments']}"
uri = URI(req_url)
request = Net::HTTP::Get.new(uri)
request["Accept"] = "application/json"
request["Authorization"] = "Bearer #{token_value}"

req_options = {
	use_ssl: uri.scheme == "https",
}

response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
	http.request(request)
end

if (response.code != '200')
	puts "Error: #{response.code} #{response.message} - #{response.body}"
	exit
end

enrichments=JSON.parse(response.body)['content']

# puts enrichments

enrichments.each do |enrichment|
	puts enrichment['id']
end
