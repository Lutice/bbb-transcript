<?php

require_once 'lib/php_logger.php';
require_once 'lib/config_parser.php';
require_once 'lib/get_token.php';
require_once 'lib/utils.php';



$configFilePath = "/etc/bigbluebutton.custom/bbb-transcript/aristote_config.yml";

$logger = new Logger(null);

$config = parseConfigFile($configFilePath, null);
assertFields($config,
	[
		'aristote-server.url',
		'aristote-server.paths.get-enrichment-last-version',
		'aristote-server.paths.delete-enrichment',
		'transcripts.base-directory',
		'transcripts.meeting-map-directory',
		'cache.token-path'
	],
	[
		'logs.paths.about-webhook'
	],
	[
		'activated' => true,
		'color' => true,
		'logger' => $logger
	]
);


$logger->setLogFile($config['logs']['paths']['about-webhook']);


$req_method = getenv('REQUEST_METHOD');
$logger->log("New " . $req_method . " connection to webhook");

($req_method === "POST")?:throw_error($logger, 405, "Request not processed: method (" . getenv('REQUEST_METHOD') . ") not allowed (try with POST). Request discarded.");

$input = file_get_contents('php://input');
if (!$input)
	throw_error($logger, 400, "No content. Can't process request.");

$data = json_decode($input, true);
if (!$data)
	throw_error($logger, 400, "Unable to parse data. Request discarded.");
if(array_key_exists('isTest', $data))
	$logger->log("This connection is marked as a (\e[0;33mTEST\e[0m)"); // Triggers if request is empty or if contains the isTest property


if(filter_var($config['logs']['print-webhook-requests'], FILTER_VALIDATE_BOOLEAN))
	$logger->log("Printing data:\n" . print_r($data, true));


$status = filter_var($data['status'], FILTER_SANITIZE_STRING);
if ($status != 'SUCCESS')
{
	$reason = filter_var($data['failureCause'], FILTER_SANITIZE_STRING);
	throw_error($logger, 400, "Reponse status is not 'SUCCESS': '$status' cause: '$reason'. Request discarded.");
}

$enrichmentId = filter_var($data['id'], FILTER_SANITIZE_STRING);
$enrichmentVersionId = filter_var($data['initialVersionId'], FILTER_SANITIZE_STRING);

if (!$enrichmentId || !$enrichmentVersionId)
{
	throw_error($logger, 400, "No valid id or versionId provided. Request discarded.");
}

$logger->log("Status received is SUCCESS");


// Get the authorization key (from the cache)
$authorization = getToken($config);

if(!$authorization)
	throw_error($logger, 500, "Failed to get token. Cannot process request.");


// Make the request of the enrichment
$url_get_enrichment = str_replace('{id}', $enrichmentId, $config['aristote-server']['paths']['get-enrichment-last-version']);
$curl_req = curl_init(); // GET by default
curl_setopt($curl_req, CURLOPT_URL, $config['aristote-server']['url'] . $url_get_enrichment);
curl_setopt($curl_req, CURLOPT_RETURNTRANSFER, 1);
curl_setopt($curl_req, CURLOPT_HTTPHEADER, [
	"Accept: application/json",
	"Authorization: Bearer ". $authorization
]);

$response = curl_exec($curl_req);

if (curl_errno($curl_req))
	throw_error($logger, 500, "Error: " . curl_error($curl_req));

$return_code = curl_getinfo($curl_req, CURLINFO_RESPONSE_CODE);

if ($return_code != 200)
{
	$errormsg = "Error $return_code from the Aristote server : $response";
	if ($return_code == 401)
		$errormsg = "$errormsg TIP : Check your token bearer. It probably expired.";
	$errormsg = "$errormsg Request discarded.";
	throw_error($logger, 500, $errormsg);
}

curl_close($curl_req);

$json_response = json_decode($response, true);

if ($json_response['id'] != $enrichmentVersionId)
{
    $logger->log("Warning: The returned enrichment version does not bear the same id than the webhook's notification's enrichment (Webhook's version id: $enrichmentVersionId)");
}

// Get the associated meeting id with the tempfile
$base_dir = $config['transcripts']['base-directory'];
$temp_meeting_filepath = $base_dir . $config['transcripts']['meeting-map-directory'] . "/$enrichmentId";

if (file_exists($temp_meeting_filepath)){
    $meeting_id = file_get_contents($temp_meeting_filepath);
}
else {
    $meeting_id = "unknown_$enrichmentId";
    $logger->log("Warning : enrichment $enrichmentId has no meeting_id associated. Saving it at $meeting_id");
}   
$storageDir = $base_dir;

if (!is_dir($storageDir)){
	if (!mkdir($storageDir, 0755, true))
		throw_error($logger, 500, "Unable to create folder '$storageDir'. Check the permissions. Request discarded.");
}
$transcriptfilepath = str_replace('{meeting_id}', $meeting_id, $config['transcripts']['base-directory'] . "/" . $config['transcripts']['filename']);
$transcriptfile = fopen($transcriptfilepath, "w+");
fwrite($transcriptfile, json_encode($json_response));
fclose($transcriptfile);

$logger->log("Successfully saved enrichment $enrichmentId (Version $enrichmentVersionId) at '$transcriptfilepath'");
$logger->createRuler('+', 100);

if($config['aristote-server']['keep-clean']){
    $logger->log("Deleting enrichment...");
    $delete_req = curl_init();
    $del_url = str_replace("{id}", $enrichmentId, $config['aristote-server']['url'] . $config['aristote-server']['paths']['delete-enrichment']);
    curl_setopt($delete_req, CURLOPT_URL, $del_url);
    curl_setopt($delete_req, CURLOPT_CUSTOMREQUEST, 'DELETE');
    curl_setopt($delete_req, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($delete_req, CURLOPT_HTTPHEADER, [
	    "Accept: application/json",
	    "Authorization: Bearer ". $authorization
    ]);

    curl_exec($delete_req);

    if (curl_errno($delete_req))
	    throw_error($logger, 500, "Error: " . curl_error($delete_req));

    $return_code = curl_getinfo($delete_req, CURLINFO_RESPONSE_CODE);

    if ($return_code != 200)
    {
	    $errormsg = "Error $return_code from the Aristote server while clearing enrichment: $response";
	    if ($return_code == 401)
		    $errormsg = "$errormsg TIP : Check your token bearer. It probably expired.";
	    $errormsg = "$errormsg Request discarded.";
	    throw_error($logger, 500, $errormsg);
    }

    curl_close($delete_req);
    $logger->log("Enrichment cleared successfully.");
}

http_response_code(204);
// echo "Request execution complete.\n";
