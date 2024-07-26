<?php

class Logger {
	private $logFile;

	public function __construct($filePath) {
		if($filePath){
			self::setLogFile($filePath);
		}
		else {
			$logFile = null;
		}
	}

	public function __destruct() {
		if ($this->logFile) {
			fclose($this->logFile);
		}
	}


	public function setLogFile($filePath){
		if (!$filePath) {
			// echo "Filepath invalid. Will use the default php log (/var/log/php7.4.log)" . PHP_EOL;
			return;
		}
		
		$path = dirname($filePath);

# if (is_writable($path)){
# echo "$path is writable by data-www";
# }
# else
# echo "$path not writable by data-www";

		$this->logFile = fopen($filePath, 'a+'); // Open existing file in append mode

		if (!$this->logFile) {
			// echo ("Failed to open or create file: $filePath. Will use the default php log (/var/log/php7.4.log)." . PHP_EOL);
			return;
		}
	}

	public function log($message) {
		if(!$this->logFile){
			error_log("$message");
			return;
		}

		$timestamp = date('Y-m-d H:i:s');
		fwrite($this->logFile, "$timestamp ~ $message" . PHP_EOL);
	}

	public function createRuler($char = '-', $length = 50) {
		if(!$this->logFile){
			return;
		}
		$ruler = str_repeat($char, $length) . PHP_EOL;
		fwrite($this->logFile, $ruler);
	}
}
