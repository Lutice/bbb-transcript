module FieldsChecker

	RED_COLOR = "\e[31m"
	YELLOW_COLOR = "\e[33m"
	WHITE_COLOR = "\e[0m"

	def self.getMissingFields(hash_container, fields_to_check)

		# puts "Checking missing fields in #{hash_container} for #{fields_to_check}."

		return [] if fields_to_check.nil?

		missing_fields = fields_to_check.reject do |field_path|
			hash_container.dig(*field_path.split('.'))
		end

		return missing_fields
	end

	# type = {"req" , "opt"}
	def self.generateMissingWarning(type, fields, color = false)

		c_fatal = ""
		c_warning = ""
		c_white = ""

		if color		
			c_fatal = RED_COLOR
			c_warning = YELLOW_COLOR
			c_default = WHITE_COLOR
		end
		
		fields.map! do |field|
			field = field.gsub('.','->')
		end

		if type == "req"
			message = "#{c_fatal}Fatal: Required fields missing from config file : #{c_default}#{fields}"
		end
		if type == "opt"
			message = "#{c_warning}Warning: Optionnal fields missing from config file : #{c_default}#{fields}"
		end

		return message
	end


	def self.checkFields(hash_container, required_fields, optionnal_fields = [], auto_display = { activated: false, color: false, logger: nil })

		required_missing = getMissingFields(hash_container, required_fields)
		optionnal_missing = getMissingFields(hash_container, optionnal_fields)

		return [required_missing, optionnal_missing] unless (!auto_display.nil? && auto_display[:activated])

		color = auto_display[:color]
		logger = auto_display[:logger]
		hasLogger = (logger and logger.respond_to?(:info))

		if !optionnal_missing.empty?
			msg = generateMissingWarning("opt", optionnal_missing, color)
			if hasLogger
				logger.info(msg)
			else
				puts "no logger"
			end
		end
		if !required_missing.empty?
			msg = generateMissingWarning("req", required_missing, color)
			if hasLogger
                                logger.error(msg)
                        end
		end

		
		
		return [required_missing, optionnal_missing]
	end


	def self.assertFields(hash_container, required_fields, optionnal_fields = [], auto_display = { activated: false, color: false })

		missingFields = checkFields(hash_container, required_fields, optionnal_fields, auto_display)
		if !missingFields[0].empty?
			exit 1
		end
	end

	private_class_method :getMissingFields
end
