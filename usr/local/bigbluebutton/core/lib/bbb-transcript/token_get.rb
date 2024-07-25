
require 'net/http'
require 'json'
require 'yaml'
require 'date'
require_relative '/usr/local/bigbluebutton/core/lib/bbb-transcript/ruby_logger.rb'
require_relative '/usr/local/bigbluebutton/core/lib/bbb-transcript/fields_checker.rb'

## THIS A MODULE THAT SHOULD BE USABLE ANYWHERE ON THE SYSTEM, DO NOT HARD CODE ANY RELATIVE PATH IN IT


module TokenManager
	
	CONFIG_FILE_PATH = "/etc/bigbluebutton.custom/bbb-transcript/aristote_config.yml"
	
	@@cacheFilePath = nil
	@@logger = nil
	@@config = nil

	def self.loadConfigFile()

		return if !@@config.nil?

		@@config = YAML.load_file(CONFIG_FILE_PATH)	
		FieldsChecker.assertFields(@@config,			[
				'aristote-server.url',
				'aristote-server.paths.get-token',
				'credentials.id',
				'credentials.password'
			],
			[
				'logs.paths.about-token',
				'cache.token-path'
			],
			{ activated: true, color: true }
		)
		@@logger = RubyLogger.new(@@config['logs']['paths']['about-token'])
	end


	# DEPRECATED
#	def self.getPathsFromConfigFile()

#		logFilePath = ''

#		File.open(CONFIG_FILE_PATH, 'r') do |file|
#			lines = file.readlines
#                       lines.each do |line|
#				line = line.strip
#                               next if line.start_with?('#') || line.empty?

#                                key, value = line.split(':', 2).map(&:strip)

#				case key
#				when 'TokenCacheFilePath'
#					@@cacheFilePath = value
#				when 'TokenLogFilePath'
#					logFilePath = value
#				end
#			end
#		end

#		errs = []
#		if (logFilePath.nil?)
#			errs.append('TokenLogFilePath')
#		end
#		if (@@cacheFilePath.nil?)
#			errs.append('TokenCacheFilePath')
#		end

#		if errs.length > 0
#			puts "Error: Missing parameters required parameters in config file : #{errs} (/etc/bigbluebutton.custom/aristote/credentials.config)"
#		end

#		@@logger = RubyLogger.new(logFilePath)
#	end

#	# DEPRECATED
#	def self.getCredentialsFromConfigFile()

#		server_url = ""
#		id = ""
#		password = ""

#		File.open(CONFIG_FILE_PATH, 'r') do |file|
#			lines = file.readlines
#			lines.each do |line|
#       			line = line.strip
#				next if line.start_with?('#') || line.empty?

#				key, value = line.split(':', 2).map(&:strip)
#				case key
#				when 'Id'
#					id = value
#     				when 'Password'
#    					password = value
#				when 'ServerTokenPath'
#					server_url = value
#				else
#					# @@logger.log "Warning: Unrecognized parameter \"#{key}\" at \"#{line}\"\n(in file #{CONFIG_FILE_PATH})"
#				end
#			end
#		end
#
#		errs = []
#		warns = []
#
#		if (id.empty?)
#			warns.append('Id')
#		end
#		if (password.empty?)
#			warns.append('Password')
#		end
#		if (server_url.empty?)
#			errs.append('ServerTokenPath')
#		end
#
#		if warns.length > 0
#			@@logger.log("Warning: Missing parameters in config file : #{warns} (/etc/bigbluebutton.custom/aristote/credentials.config)")
#		end
#		if errs.length > 0
#			@@logger.log("Error: Missing required parameters in config file : #{errs} (/etc/bigbluebutton.custom/aristote/credentials.config)")
#			return false
#		end

#		return [server_url, id, password]
#	end


	def self.getTokenFromServer(server_url, id, password, prevent_cache=false)

		token_url_uri = URI(server_url)
		token_request = Net::HTTP::Post.new(token_url_uri)
		token_request.set_form_data({ 'grant_type' => 'client_credentials', 'client_id' => id, 'client_secret' => password })
		token_response = Net::HTTP.start(token_url_uri.hostname, token_url_uri.port, :use_ssl => true) { |http|
			http.request(token_request)
		}

		if (token_response.code != '200')
			@@logger.log "#{token_response.code} #{token_response.message} - #{token_response.body}"
			return nil
		end

		token = JSON.parse(token_response.body)
		token_value = token['access_token']

		if (!prevent_cache)
			cacheNewToken(token_value, token['expires_in'])
		end

		return token_value
	end


	# Saves the token at CACHE_FILE_PATH for future uses
	# Overwites the already existing one if there is
	def self.cacheNewToken(token_value, expireInSeconds)

		# Compute the expiration date
		current_time = DateTime.now
		expiration_date = current_time + Rational(expireInSeconds, 86400)

		token = {
			value: token_value,
			expiration_date: expiration_date.to_s
		}
		
		cache_file_path = @@config['cache']['token-path']

		if !File.writable?(cache_file_path)
		    @@logger.log("Not enough write permissions to cache permission at #{cache_file_path}")
		    return
		end
		
		File.open(@@config['cache']['token-path'], 'w') do |file|
		    if file.write(token.to_json)
			@@logger.log "Cached new token that expires at #{expiration_date}."
		    else
			@@logger.log "Failed to cache the new token."
		    end
		end
	end
	
	def self.tryGetCachedToken()
		
		return nil if !File.exist?(@@config['cache']['token-path'])

		begin
		    json_token = File.read(@@config['cache']['token-path'])
		rescue Errno::EACCES
		    message = "Warning: Token cache unavailable, permission denied. Did you try to run as user bigbluebutton or data-www ?"
		    puts message if !@@logger.log message
		    return nil
		end
		token_data = JSON.parse(json_token, symbolize_names: true)
		
		return nil if DateTime.now > DateTime.parse(token_data[:expiration_date])

		return token_data[:value]
	end


	# Gets a valid token, from the cache or the server.
	# It is guarenteed to return a token that has not expired in time.
	# In case the token has been cancelled before its expiration date, the 'force_discard' option might be useful by indicating that we want to discard the cache.
	def self.getToken(force_discard=false)

		loadConfigFile()

		# First check is the cached token is still valid (only if user does not force discard)
		if !force_discard
			token = tryGetCachedToken()
		else
			@@logger.log "Note: Force discard is set to true => refreshing the token"
		end

		if !token.nil?
			@@logger.log "Passed cached token still time-valid."
			@@logger.makeRuler('=')
			return token
		end

		# If it has expired (or if force discard), ask for a new one
		# credentials = getCredentialsFromConfigFile()
		token = getTokenFromServer("#{@@config['aristote-server']['url']}#{@@config['aristote-server']['paths']['get-token']}", @@config['credentials']['id'], @@config['credentials']['password'])

		if token.nil?
			@@logger.log "Error: Failed to authenticate to the server. Exiting..."
			@@logger.makeRuler('*')
		else
			@@logger.log "Retrived a new token from server."
			@@logger.makeRuler('+')
		end
		
		
		return token
	end


	def self.checkToken(tokenToVerify)
		currentToken = tryGetCachedToken()

		if (!currentToken)
			return false
		end

		return currentToken == tokenToVerify

	end

	private_class_method :tryGetCachedToken, :cacheNewToken, :getTokenFromServer #, :getCredentialsFromConfigFile, :getPathsFromConfigFile
end
