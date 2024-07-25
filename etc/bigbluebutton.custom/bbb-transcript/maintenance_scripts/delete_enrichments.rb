require 'net/http'
require 'json'
require 'yaml'
require_relative '/usr/local/bigbluebutton/core/lib/bbb-transcript/token-get.rb'
require_relative '/usr/local/bigbluebutton/core/lib/bbb-transcript/fields-checker.rb'

if (ARGV.length != 1)
	puts "Usage: "
	puts "\truby delete-enrichments.rb <filepath>"
	puts "\nThe filepath of the file containing the enrichments id to delete."
	exit
end

filepath = ARGV[0]

if (!File.exist?(filepath))
	puts "Specified file '#{filepath}' does not exist."
	exit
end


token_value = TokenManager.getToken()

config = YAML.load_file('/etc/bigbluebutton.custom/bbb-transcript/aristote-config.yml')
FieldsChecker.assertFields(config,
        # Required params
        [
                'aristote-server.url',
                'aristote-server.paths.delete-enrichment',
        ],
        # Optionnal params
        [
                # None
        ],
        { activated: true, color: true }
)


## Enrichments DELETE REQUESTS

# Get the ids from the file
file_content = File.read(filepath)
ids = file_content.split("\n")

if (ids.empty?)
	puts "Nothing to delete."
	exit
end

puts "Found #{ids.length} enrichments, are you sure you want delete them all ? (y/n) "

user_input = open('/dev/tty') { |f| f.gets.chomp }

if (user_input != "y")
	puts "Operation cancelled"
	exit
end

ids.each do |id|
	url = "#{config['aristote-server']['url']}#{config['aristote-server']['paths']['delete-enrichment'].gsub('{id}', id)}"
	uri = URI.parse(url)
	request = Net::HTTP::Delete.new(uri)
	request["Accept"] = "application/json"
	request["Authorization"] = "Bearer #{token_value}"
	req_options = {
	  use_ssl: uri.scheme == "https",
	}
	
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
	  http.request(request)
	end
	
	if (response.code != '200')
		puts "Error: #{response.code} #{response.message}: #{response.body}"
	elsif
		puts "Deleted enrichment #{id}"
	end
end
