<?php
function recode(&$item, $key) {
 $item = iconv('UTF-8','UTF-8//IGNORE', $item);
}
function array_walk_recursive(&$input, $callback, $userdata = null) {
    foreach($input as $key => $value) {
        if (is_array($value)) {
            if(!array_walk_recursive($value, $callback, $userdata)) {
                return false;
            }
        }
        else {
            call_user_func($callback, $value, $key, $userdata);
        }
    }

    return true;
}
require_once('JSON.php');
if( !function_exists('json_encode') ) {
    function json_encode($data) {
        $json = new Services_JSON();
        return( $json->encode($data) );
    }
}
// Future-friendly json_decode
if( !function_exists('json_decode') ) {
    function json_decode($data) {
        $json = new Services_JSON();
        return( $json->decode($data) );
    }
}
$extensions = get_loaded_extensions();
$data = array(
 "version" => phpversion(),
// "constants" => get_defined_constants(true),
 "ini" => ini_get_all(),
 "extensions" => $extensions,
 "extensionFuncs" => array(),
 "includedFiles" => get_included_files(),
);
foreach($extensions as $e) {
 $data['extensionFuncs'][$e] = get_extension_funcs($e);
}
array_walk_recursive($data, 'recode');
//header("Content-Type: application/json");
echo json_encode($data);

