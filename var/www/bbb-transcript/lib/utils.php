<?php

function throw_error($logger, $err_code, $errormsg, $user_err = null)
{
    if($err_code)
	http_response_code($err_code);
    if($logger){
	$logger->log("\e[0;31m$errormsg\e[0m");
	$logger->createRuler('*', 100);
    }

    if($user_err){
	echo $user_err;	
    }

    exit();
    echo "<h1>Aristote webhook page.</h1>";
    echo "<p>This page should receive a POST request holding body data as JSON-like containing :<br/>";
    echo "{ id, status, initialVersionId, failureCause }<br/></p>";
    echo "<p>If you see this, that means the request has not been processed correctly.</p>";
    exit();

    if ($errormsg)
	echo "<p>Additionnal message: <strong>$errormsg</strong></p>";
    exit();
}




