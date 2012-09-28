<?php

// commentsubmit.php -- Receive comments and e-mail them to someone
// Copyright (C) 2011 Matt Palmer <mpalmer@hezmatt.org>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3, as
//  published by the Free Software Foundation.
//
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, see <http://www.gnu.org/licences/>


// Format of the date you want to use in your comments.  See
// http://php.net/manual/en/function.date.php for the insane details of this
// format.
$DATE_FORMAT = "Y-m-d H:i";

// Where the comment e-mails should be sent to.  This will also be used as
// the From: address.  Whilst you could, in theory, change this to take the
// address out of the form, it's *incredibly* highly recommended you don't,
// because that turns you into an open relay, and that's not cool.
$EMAIL_ADDRESS = "blogger@example.com";

// The contents of the following file (relative to this PHP file) will be
// displayed after the comment is received.  Customise it to your heart's
// content.
$COMMENT_RECEIVED = "comment_received.html";

// If the emails arrive in your client "garbled", you may need to change this
// line to "\n" instead.
$HEADER_LINE_ENDING = "\r\n";


/****************************************************************************
 * HERE BE CODE
 ****************************************************************************/

function get_post_field($key, $defaultValue = "")
{
	return (isset($_POST[$key]) && !empty($_POST[$key])) ? $_POST[$key] : $defaultValue;
}

function filter_name($input)
{
	$rules = array( "\r" => '', "\n" => '', "\t" => '', '"'  => "'", '<'  => '[', '>'  => ']' );
	return trim(strtr($input, $rules));
}

function filter_email($input)
{
	$rules = array( "\r" => '', "\n" => '', "\t" => '', '"'  => '', ','  => '', '<'  => '', '>'  => '' );
	return strtr($input, $rules);
}

// Taken from http://php.net/manual/en/function.preg-replace.php#80412
function filter_filename($filename, $replace = "")
{
	$reserved = preg_quote('\/:*?"<>|', '/'); //characters that are  illegal on any of the 3 major OS's
	//replaces all characters up through space and all past ~ along with the above reserved characters
	return preg_replace("/([\\x00-\\x20\\x7f-\\xff{$reserved}]+)/", $replace, $filename);
}

function get_post_data_as_yaml()
{
	$yaml_data = "";
	
	foreach ($_POST as $key => $value) 
	{
		if (strstr($value, "\n") != "") 
		{
			// Value has newlines... need to indent them so the YAML
			// looks right
			$value = str_replace("\n", "\n  ", $value);
		}
		// It's easier just to single-quote everything than to try and work
		// out what might need quoting
		$value = "'" . str_replace("'", "''", $value) . "'";
		$yaml_data .= "$key: $value\n";
	}
	
	return $yaml_data;
}


$EMAIL_ADDRESS = filter_email($EMAIL_ADDRESS);

$COMMENTER_NAME = filter_name(get_post_field('name', "Anonymous"));
$COMMENTER_EMAIL_ADDRESS = filter_email(get_post_field('email', $EMAIL_ADDRESS));
$COMMENTER_WEBSITE = get_post_field('link');
$COMMENT_BODY = get_post_field('comment', "");
$COMMENT_DATE = date($DATE_FORMAT);

$POST_TITLE = get_post_field('post_title', "Unknown post");
$POST_ID = get_post_field('post_id', "");
unset($_POST['post_id']);


$yaml_data = "post_id: $POST_ID\n";
$yaml_data .= "date: $COMMENT_DATE\n";
$yaml_data .= get_post_data_as_yaml();

$attachment_data = chunk_split(base64_encode($yaml_data));
$attachment_date = date('Y-m-d-H-i-s');
$attachment_name = filter_filename($POST_ID, '-') . "-comment-$attachment_date.yaml";


$uid = md5(uniqid(time()));

$subject = "Comment from $COMMENTER_NAME on '$POST_TITLE'";
$subject = '=?UTF-8?B?'.base64_encode($subject).'?=';

$message = "$COMMENT_BODY\n\n";
$message .= "----------------------\n";
$message .= "$COMMENTER_NAME\n";
$message .= "$COMMENTER_WEBSITE\n";

$header = "";
function add_header($value = "")
{
	global $header, $HEADER_LINE_ENDING;
	// Not passing any value will only add a line ending
	$header .= $value . $HEADER_LINE_ENDING;
}

add_header("From: $COMMENTER_NAME <$EMAIL_ADDRESS>");
if (!empty($COMMENTER_EMAIL_ADDRESS)) add_header("Reply-To: $COMMENTER_NAME <$COMMENTER_EMAIL_ADDRESS>");

add_header("X-Mailer: PHP/" . phpversion());
add_header("MIME-Version: 1.0");
add_header("Content-Type: multipart/mixed; boundary=\"$uid\"");
add_header();
add_header("This is a multi-part message in MIME format.");
add_header("--$uid"); // PLAIN-TEXT MESSAGE
add_header("Content-Type: text/plain; charset=utf-8");
add_header("Content-Transfer-Encoding: 8bit");
add_header();
add_header("$message");
add_header();
add_header("--$uid"); // COMMENT ATTACHMENT
add_header("Content-Type: application/octet-stream; name=\"$attachment_name\"");
add_header("Content-Transfer-Encoding: base64");
add_header("Content-Disposition: attachment; filename=\"$attachment_name\"");
add_header();
add_header("$attachment_data");
add_header();
add_header("--$uid--");


if (mail($EMAIL_ADDRESS, $subject, "", $header))
{
	include $COMMENT_RECEIVED;
}
else
{
	echo "There was a problem sending the comment. Please contact the site's owner.";
}
