require 'date'


# A module that simplifies logging in ruby scripts
class RubyLogger

	

	def initialize(logFilePath)
		@logFilePath = nil

		@useDate = true

		@colorHeader = true
		@colorDate = true
		@colorBody = false
		changeLogFilePath(logFilePath)
	end

	def changeLogFilePath(logFilePath)
		if (logFilePath.nil? || !logFilePath.is_a?(String))
			puts "logFilePath argument is invalid (must be string)"
			return false
		end

		# Check permissions
		if (File.exist?(logFilePath))
			# The file exists, check the permission to write in it
			if (!File.writable?(logFilePath))
				puts "File '#{logFilePath}' is not writable. Logger not initiated. Change permissions of the file or change the file name."
				return false
			end
		else
			# The file needs to be created, check the permissions to create it."
			if (!File.writable?(File.dirname(logFilePath)))
				puts "Directory '#{File.dirname(logFilePath)}' not writable. Logger not initiated. Create the file manually or grant directory write permissions."
				return false
			end
		end

		@logFilePath = logFilePath

		return true
	end

	# Useless for the moment
	def setColorRule(colorHeader:, colorDate:, colorBody:)
		@colorHeader = colorHeader
		@colorDate = colorDate
		@colorBody = colorBody
	end

	# Available colors are Red Green Grey and White (default) (but for now it does nothing)
	def log(message, color: 'White', header: '', stdPrint: false)
		return false if @logFilePath.nil?

		if (!message)
                	return false
        	end

		if stdPrint
			puts message
		end

        	message = "#{message}\n"

        	if @useDate
        	        message = "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} ~ #{message}"
        	end
        	if !header.empty?
        	        message = "#{header}: #{message}"
        	end

		begin
		    File.write(@logFilePath, message, mode: 'a')
		rescue
		    puts "Log unexpectedly failed."
		end
		return true
	end


	# Make a ruler seperator
	def makeRuler(symbol = '*', length = 100)
		return false if @logFilePath.nil?
		total = symbol*length
		    
		return if total.nil?

		File.write(@logFilePath, "#{total}\n", mode: 'a')

	end
end
