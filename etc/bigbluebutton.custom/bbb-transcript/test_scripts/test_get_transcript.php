<?php

require_once '/etc/bigbluebutton.custom/aristote/php/config-parser.php';
require_once '/etc/bigbluebutton.custom/aristote/php/php-logger.php';

$logger = new Logger(null);

$configFilePath = "/etc/bigbluebutton.custom/aristote/aristote-config.yml";
$config = parseConfigFile($configFilePath, null);
assertFields($config,
        [
		'get-transcript-url',
                'secret-path'
        ],
        [
        ],
        [
                'activated' => true,
                'color' => true,
                'logger' => $logger
        ]
);

function sendGetRequest($url, $params) {
    $ch = curl_init();

    $queryString = http_build_query($params);

    curl_setopt($ch, CURLOPT_URL, $url . '?' . $queryString);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json'
    ]);

    $response = curl_exec($ch);

    if (curl_errno($ch)) {
        $error_msg = curl_error($ch);
        curl_close($ch);
        return ['error' => $error_msg];
    }

    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    curl_close($ch);

    return ['response' => $response, 'http_code' => $http_code];
}

// Get arguments from the command line
$options = getopt('', ['meeting_id:', 'correct_checksum::']);

$test_meeting_id = $options['meeting_id'] ?? '';

$checksum = "fake_checksum";

if (!isset($options['correct_checksum']) || $options['correct_checksum'] !== 'false') {
	// Generate the correct checksum
	$secret_config = parse_ini_file($config['secret-path'], INI_SCANNER_RAW);
	if ($secret_config === false) {
	        echo "Failed to parse the secret file.";
	        exit();
	}
	$bbb_secret = $secret_config['securitySalt'];

	$checksum = hash('sha256', $test_meeting_id . $bbb_secret);
}

$test_fields_select = ['field1', 'field2'];

$params = [
    'meeting_id' => $test_meeting_id,
    'checksum' => $checksum,
    'fields_select' => $test_fields_select
];

// Send the GET request and get the response
$response = sendGetRequest($config['get-transcript-url'] . "/", $params);

// Display the response
if (array_key_exists('error', $response)){
	echo $response['error'];
	exit();
}

echo "HTTP Status Code: " . $response['http_code'] . "\n";
echo "Response: " . print_r(json_decode($response['response']), true . "\n");
?>
