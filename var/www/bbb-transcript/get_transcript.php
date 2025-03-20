<?php

require_once 'lib/php_logger.php';
require_once 'lib/config_parser.php';
require_once 'lib/utils.php';


header('Content-Type: application/json');

$logger = new Logger("");

$configFilePath = "/etc/bigbluebutton.custom/bbb-transcript/aristote_config.yml";
$config = parseConfigFile($configFilePath, null);
assertFields($config,
        [
                'aristote-server.url',
                'aristote-server.paths.get-enrichment-last-version',
//              'aristote-server.paths.delete-enrichment',
                'transcripts.base-directory',
                'transcripts.filename',
		'secret-path'
        ],
        [
                'logs.paths.about-get-transcript'
        ],
        [
                'activated' => true,
                'color' => true,
                'logger' => $logger
        ]
);

$logger->setLogFile($config['logs']['paths']['about-get-transcript']);


$req_method = getenv('REQUEST_METHOD');
($req_method === "GET")?:throw_error($logger, 405,"Request not processed: method (" . $req_method . ") not allowed (GET allowed). Request discarded.");

// Get parameters from GET request (meeting_id, secret, field_select ?)
$args = [
	'meeting_id' => FILTER_SANITIZE_STRING,
	'checksum' => FILTER_SANITIZE_STRING,
	'fields_select' => [
		'filter' => FILTER_SANITIZE_STRING,
		'flags' => FILTER_REQUIRE_ARRAY
		]
	];
$params = filter_input_array(INPUT_GET, $args);

$meeting_id = $params['meeting_id'];
$checksum = $params['checksum'];
$fields = $params['fields_select'];

// MAYDO: Pull the error throw to Logger code
if (!$meeting_id) {
	$error = json_encode(['error' => 'Missing parameter "meeting_id".']);
	throw_error($logger, 400, 'Missing parameter "meeting_id".', $error);
}
if (!$checksum) {
	$error = json_encode(['error' => 'Missing parameter "checksum".']);
	throw_error($logger, 400, 'Missing parameter "checksum".', $error);
}

// Check secret code with secret bbb-conf (sha256)
$secret_config = parse_ini_file($config['secret-path'], INI_SCANNER_RAW);
if ($secret_config === false) {
        $error = json_encode(['error' => 'Unable to verify checksum (failed to parse secret file).']);
	throw_error($logger, 500, 'Unable to verify checksum (failed to parse secret file).', $error);
}


$bbb_secret = $secret_config['securitySalt'];
if (hash('sha256', $meeting_id . $bbb_secret) != $checksum) {
	$error = json_encode(['error' => 'Invalid secret.']);
	throw_error($logger, 401, 'Invalid secret.', $error);
}

// TEST
// $meeting_id = "adbad27fac00883d91f3f069ea258e2c0bb6ebda-1721291778753";

// Check if exists and get transcript (which is the contents of /var/bigbluebutton/transcripts/{meeting_id})
$transcript_path_expression = $config['transcripts']['base-directory'] . "/" . $config['transcripts']['filename'];
$transcript_path = str_replace('{meeting_id}', $meeting_id, $transcript_path_expression);

if (!file_exists($transcript_path)) {
	$error = json_encode(['error' => "Transcript for meeting_id $meeting_id not found"]);
	throw_error($logger, 404, "Transcript for meeting_id $meeting_id not found", $error);
}

$transcript = file_get_contents($transcript_path);
if (!$transcript) {
        $error = json_encode(['error' => "Couldn't read transcript of meeting_id '$meeting_id'."]);
	throw_error($logger, 500, "Couldn't read transcript of meeting_id '$meeting_id'.", $error);
}

$json_transcript = json_decode($transcript);
if ($json_transcript === false) {
	$error = json_encode(['error' => 'Failed to read transcript in json.', 'raw-data' => $transcript ]);
	throw_error($logger, 500, 'Failed to read transcript in json.', $error);
}

// TODO: Trim data to requested (see later for that)
$trimmed_transcript = $json_transcript;

// Send data back
echo json_encode($trimmed_transcript);

