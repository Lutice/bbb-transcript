<?php

define('RED_COLOR', "\033[31m");
define('YELLOW_COLOR', "\033[33m");
define('WHITE_COLOR', "\033[0m");

function getMissingFields($hashContainer, $fieldsToCheck) {
	if (empty($fieldsToCheck)) {
		return [];
	}
	//echo $fieldsToCheck;
	// Iterate through every field we want to check with the array filter
	$missingFields = array_filter($fieldsToCheck, function($fieldPath) use ($hashContainer) {

		// Get the keys hierachy from the fieldPath
		$keys = explode('.', $fieldPath);
		$current = $hashContainer;
		$levels = count($keys);
		$count = 0;
		foreach ($keys as $key) {
			if(!array_key_exists($key, $current)){
				return true; // Field doesn't exist
			}
			$count ++;
			if ($count < $levels){
				$current = $current["$key"];
				if (!is_array($current))
					return true; // Should have been an array, so field doesn't exist
			}
		}
		return false; // Field exists
	});
	return $missingFields;
}

function generateMissingWarning($type, $fields, $color = false) {
	global $RED_COLOR, $YELLOW_COLOR, $WHITE_COLOR;

//	foreach ($fields as &$field) {
//		// Replace '-' with the specified replacement
//		$field = str_replace('-', '->', $field);
//	}

	$message = '';
	if ($color) {
		$c_fatal = $RED_COLOR;
		$c_warning = $YELLOW_COLOR;
		$c_default = $WHITE_COLOR;
	}
	else {
		$c_fatal = '';
		$c_warning = '';
		$c_default = '';
	}

	if ($type === "req") {
		$message = "{$c_fatal}Fatal: Required fields missing from config file : {$c_default}'" . implode(', ', $fields)."'";
	}
	elseif ($type === "opt") {
		$message = "{$c_warning}Warning: Optional fields missing from config file : {$c_default}'" . implode(', ', $fields)."'";
	}

	return $message;
}

function validateParameters($hashContainer, $requiredFields, $optionalFields, $autoDisplay = ['activated' => false, 'color' => false, 'logger' => null]) {

	// Extract auto display options
	$activated = isset($autoDisplay['activated']) ? $autoDisplay['activated'] : false;
	$color = isset($autoDisplay['color']) ? $autoDisplay['color'] : false;
	$logger = isset($autoDisplay['logger']) ? $autoDisplay['logger'] : null;

	// Check required and optional fields
	$requiredMissing = getMissingFields($hashContainer, $requiredFields);
	$optionalMissing = getMissingFields($hashContainer, $optionalFields);

	// Return if auto display is not activated
	if (!$activated) {
		return [$requiredMissing, $optionalMissing];
	}

	// Handle optional missing fields
	if (!empty($optionalMissing)) {
		$msg = generateMissingWarning("opt", $optionalMissing, $color);
		if (!is_null($logger) && method_exists($logger, 'log'))
			$logger->log($msg, ['stdPrint' => true]);
		else
			echo $msg . PHP_EOL;
	}

	// Handle required missing fields
	if (!empty($requiredMissing)) {
		$msg = generateMissingWarning("req", $requiredMissing, $color);
		if (!is_null($logger) && method_exists($logger, 'log'))
			$logger->log($msg, ['stdPrint' => true]);
		else
			echo $msg . PHP_EOL;
	}

	return [$requiredMissing, $optionalMissing];


}

function assertFields($hashContainer, $requiredParams, $optionalParams, $autoDisplay = ['activated' => false, 'color' => false, 'logger' => null])
{
	$missingFields = validateParameters($hashContainer, $requiredParams, $optionalParams, $autoDisplay);

	if (!empty($missingFields[0]))
		exit(1);
}

function parseConfigFile($filePath, $logStream)
{
	$logging = is_resource($logStream);

	if (!file_exists($filePath)) {
		if($logging)
			fwrite($logStream, "Config file error: File not found: $filePath");
	        throw new Exception("File not found: $filePath");
	}

	return yaml_parse_file($filePath);
}
