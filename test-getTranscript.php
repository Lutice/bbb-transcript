<?php
$bbbSecret = '[BBB_SECRET_KEY]';
$meetingId='[BBB_MEETING_ID]'; // The meeting id you need to get transcript result
$serverURL='[HOOK_SERVER_URL]'; // The server url where script get_transcript run to serve the json result

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

$params = [
    'meeting_id' => $meetingId,
    'checksum' => hash('sha256',$meetingId.$bbbSecret),
    'fields_select' => ''
];


// Send the GET request and get the response
$response = sendGetRequest('https://'.$serverUrl.'/bbb-transcript/get_transcript.php', $params);

// Display the response
if (array_key_exists('error', $response)){
        echo $response['error'];
        exit();
}

echo "HTTP Status Code: " . $response['http_code'] . "\n";
echo "Response: " . print_r(json_decode($response['response']), true . "\n");

