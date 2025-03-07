
#!/usr/bin/ruby
# encoding: UTF-8

#
# BigBlueButton open source conferencing system - http://www.bigbluebutton.org/
#
# Copyright (c) 2012 BigBlueButton Inc. and by respective authors (see below).
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the Free
# Software Foundation; either version 3.0 of the License, or (at your option)
# any later version.
#
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.
#

require 'net/http'
require 'json'
require 'yaml'
require 'optimist'
require File.expand_path('../../../lib/recordandplayback', __FILE__)

opts = Optimist::options do
  opt :meeting_id, "Meeting id to archive", :type => String
  opt :format, "Playback format name", :type => String
end
meeting_id = opts[:meeting_id]

logger = Logger.new("/var/log/bigbluebutton/post_publish.log", 'weekly' )
logger.level = Logger::INFO
BigBlueButton.logger = logger

published_files = "/var/bigbluebutton/published/presentation/#{meeting_id}"
# meeting_metadata = BigBlueButton::Events.get_meeting_metadata("/var/bigbluebutton/recording/raw/#{meeting_id}/events.xml")



## BEGIN CODE

require_relative '/usr/local/bigbluebutton/core/lib/bbb-transcript/token_get.rb'
require_relative '/usr/local/bigbluebutton/core/lib/bbb-transcript/ruby_logger.rb'
require_relative '/usr/local/bigbluebutton/core/lib/bbb-transcript/fields_checker.rb'

BigBlueButton.logger.info("Loading config file...")
puts "Loading config file..."

config = YAML.load_file("/etc/bigbluebutton.custom/bbb-transcript/aristote_config.yml")
FieldsChecker.assertFields(config,
        # Required params
        [
                'aristote-server.url',
                'aristote-server.paths.new-enrichment',
		'audio-directory',
		'transcripts.base-directory',
		'transcripts.meeting-map-directory'
        ],
        # Optionnal params
        [
		'logs.paths.about-upload',
                'webhook-url',
		'enrichment-options.ai-model',
		'enrichment-options.infrastructure',
		'enrichment-options.language'
        ],
        { activated: true, color: true , logger: BigBlueButton.logger}
)

logger = RubyLogger.new(config['logs']['paths']['about-upload'])

new_enrichment_path = "#{config['aristote-server']['url']}#{config['aristote-server']['paths']['new-enrichment']}"
new_enrichment_uri = URI(new_enrichment_path)

BigBlueButton.logger.info("#{new_enrichment_path}")

# MAYDO: See the best strategy for migrating the videos (multiple enrichments or one single big file)
## 1st strategy: Merge the videos (would it be better to create seperate enrichments for each to split the work ?

audio_directory = config['audio-directory'].gsub('{meeting_id}', meeting_id)


temp_merge_filepath = "#{audio_directory}/merged.opus"
# Delete the last merge if it exists
if File.exist?(temp_merge_filepath)
	File.delete(temp_merge_filepath)
end

opus_filenames = Dir.glob("#{audio_directory}/*.opus")
n_files = opus_filenames.length

if n_files == 1
	BigBlueButton.logger.info("Single opus recording detected: no merge necessary.")
	FileUtils.cp(opus_filenames.first, temp_merge_filepath)
elsif n_files > 1
	BigBlueButton.logger.info("Multiple opus recording detected: attempting merge with ffmpeg...")
	
	temp_list_filename = "#{audio_directory}/temp"

	# Write to temp file the names
	File.open(temp_list_filename, "w+") do |temp|
		opus_filenames.each do |opus_filename|
			temp.write("file '#{opus_filename}'\n")
		end
	end
	
	system("ffmpeg -f concat -safe 0 -i #{temp_list_filename} -c copy #{temp_merge_filepath}")

	BigBlueButton.logger.info("All files have been concatenated to temp file '#{temp_merge_filepath}'.")

	if !File.delete(temp_list_filename)
		BigBlueButton.logger.error("Warning: Failed to delete temp file.")
	end
else
	# MAYDO: Try to cut the program earlier in the case of no recording to save resources
	BigBlueButton.logger.info("\e[0;32mNo recording detected. Nothing to do.\e[0m")
	exit 0
end


## VIDEO REQUEST (WORKS FINE)


upload_filepath = temp_merge_filepath
upload_filetype = 'audio/opus'
upload_original_filename = File.basename(upload_filepath)
BigBlueButton.logger.info(upload_filepath)

# Build the request to the API with an header body and authorization
token_value = TokenManager.getToken()
# Remove next line if you want to check aristote token getting
# BigBlueButton.logger.info(token_value)
video_request = Net::HTTP::Post.new(new_enrichment_uri)
video_request['Authorization'] = "Bearer #{token_value}"
form_data = [
['file', File.open(upload_filepath)],
['type', upload_filetype],
['originalFileName', upload_original_filename],
['notificationWebhookUrl', "#{config['webhook-url']}"],
['enrichmentParameters', {
        :language => "fr",
        :mediaTypes => [""],
        :disciplines => [""]
}.to_json]
]
video_request.set_form form_data, 'multipart/form-data'
BigBlueButton.logger.info("Uploading file...")
# Send the request

worker_response = Net::HTTP.start(new_enrichment_uri.hostname, new_enrichment_uri.port, :use_ssl => true) { |http|
        http.request(video_request)
}

if (!worker_response.respond_to?(:code) || !worker_response.respond_to?(:body))
        BigBlueButton.logger.info("Bad response. Returned data might be corrupted. (Missing header 'code' and 'body' container)")
        logger.log("Bad response. Returned data might be corrupted. (Missing header 'code' and 'body' container)", stdPrint: true)
        exit 1
end

BigBlueButton.logger.info("#{config['webhook-url']}")
response = JSON.parse(worker_response.body)
BigBlueButton.logger.info("#{response}")


if (worker_response.code != '200')
        BigBlueButton.logger.info("#{worker_response.code}: #{worker_response.message} - while creating enrichment")
        logger.log("#{worker_response.code}: #{worker_response.message} - while creating enrichment", stdPrint: true)
        logger.makeRuler("*")
        exit 1
end

response = JSON.parse(worker_response.body)
if (!response)
        BigBlueButton.logger.info("Parse failed. Returned data might be corrupted.")
        logger.log("Parse failed. Returned data might be corrupted.", stdPrint: true)
        exit 1
end
enrichment_id = response['id']

if (!enrichment_id)
        BigBlueButton.logger.info("No id provided. Data might be corrupted.")
        logger.log("No id provided. Data might be corrupted.")
        exit 1
end

BigBlueButton.logger.info("Created enrichment of id \"#{enrichment_id}\" successfully (meeting_id=\"#{meeting_id}\")")
logger.log("Created enrichment of id \"#{enrichment_id}\" successfully (meeting_id=\"#{meeting_id}\")", stdPrint: true)
logger.makeRuler("+")

## CREATE THE TEMPORARY FILES

# Check the folder exists
enrichments_temp_dir = "#{config['transcripts']['base-directory']}#{config['transcripts']['meeting-map-directory']}"
if !File.directory?(enrichments_temp_dir)
	BigBlueButton.logger.info("Creating '#{enrichments_temp_dir}' temp directory...")
	Dir.mkdir(enrichments_temp_dir, 0755)
end
enrichment_temp_filepath = enrichments_temp_dir + "/" + enrichment_id
# Open/Create the file and associate the meeting id with the enrichment (mapping: enrichment->meeting)
BigBlueButton.logger.info("Openning '#{enrichment_temp_filepath}' temp file for writting...")
File.open(enrichment_temp_filepath, "w+") do |temp_file|
	temp_file.write(meeting_id)
end
BigBlueButton.logger.info("\e[0;32mBegan enrichment process successfully !\e[0m")

exit 0
