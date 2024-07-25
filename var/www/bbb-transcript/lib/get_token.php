<?php

// MAYDO: turn this into an object so it can log properly in a logger
// require_once '/etc/bigbluebutton.custom/aristote/php/config-parser.php';


function getTokenFromServer($config_context, $server_url, $id, $password, $prevent_cache = false) {
	$data = [
	'grant_type' => 'client_credentials',
	'client_id' => $id,
	'client_secret' => $password
	];

	$ch = curl_init();

	curl_setopt($ch, CURLOPT_URL, $server_url);
	curl_setopt($ch, CURLOPT_POST, true);
	curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($data));
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	// curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);

	$response = curl_exec($ch);
	$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);

	if (curl_errno($ch) || $http_code != 200) {
		$error_message = curl_error($ch);
		curl_close($ch);
		return null;
	}

	curl_close($ch);

	$token = json_decode($response, true);

	if (isset($token['access_token'])) {
		$token_value = $token['access_token'];

		if (!$prevent_cache) {
			cacheNewToken($token_value, $token['expires_in'], $config_context);
		}

		return $token_value;
	}

	return null;
}

function cacheNewToken($token_value, $expireInSeconds, $config_context) {
	$cache_file_path = $config_context['cache']['token-path'];

	$current_time = new DateTime();
	$expiration_date = $current_time->add(new DateInterval('PT' . $expireInSeconds . 'S'));

	$token = [
		'value' => $token_value,
		'expiration_date' => $expiration_date->format(DateTime::ATOM)
	];

	if (file_put_contents($cache_file_path, json_encode($token)) !== false) {
		// Log success
	} else {
		// Log failure
	}
}

function tryGetCachedToken($config_context) {
	$cache_file_path = $config_context['cache']['token-path'];

	if (!file_exists($cache_file_path)) {
		return null;
	}

	$json_token = file_get_contents($cache_file_path);
	$token_data = json_decode($json_token, true);

	$current_time = new DateTime();
	$expiration_date = new DateTime($token_data['expiration_date']);

	if ($current_time > $expiration_date) {
		return null;
	}

	return $token_data['value'];
}

function getToken($config_context, $force_discard = false) {

	if (!$force_discard) {
		$token = tryGetCachedToken($config_context);
	} else {
		// Log force discard
	}

	if ($token !== null) {
		// Log token is still valid
		return $token;
	}

	$server_url = $config_context['aristote-server']['url'] . $config_context['aristote-server']['paths']['get-token'];
	$id = $config_context['credentials']['id'];
	$password = $config_context['credentials']['password'];
	$token = getTokenFromServer($config_context, $server_url, $id, $password);

	if ($token === null) {
		// Log error
	} else {
		// Log retrieved new token
	}

	return $token;
}
