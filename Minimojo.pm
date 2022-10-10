#!/usr/bin/perl
# code by Robert Alexander
# robert@paperhouse.io
# https://github.com/rta10

package Minimojo;

use strict;
use warnings;
use DBI;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Email::Sender::Transport::Mailgun qw( );
use Dotenv -load => qw(.env .env.local);

my $domain = $ENV{'DOMAIN'};
my $db = $ENV{'DB'};
my $db_user = $ENV{'DB_USER'};
my $db_pw = $ENV{'DB_PASS'};
my $mailgun = $ENV{'MAILGUN'};
my $mailgun_domain = $ENV{'MAILGUN_DOMAIN'};
my $mailgun_registration_sender $ENV{'MAILGUN_REG_SENDER'};

sub new_user_check {

	my ($new_username, $new_email, $new_pw, $new_pw_repeat) = (shift, shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($new_username !~ m/^[0-9A-Za-z\s+]+$/) {

		return ('failure', 'Usernames are alphanumeric and spaces only');

	}

	$new_username = username_clean($new_username);

	if (length($new_username) > 16) {

		return ('failure', 'Usernames cannot exceed 16 characters');

	}

	my $check_if_username_exists = check_if_user_info_exists('user', $new_username);

	if ($check_if_username_exists eq 'yes') {

		return ('failure', 'Username already exists');

	}

	if (($new_email !~ m/^(.*?)\@(.*?)\./) or ($new_email !~ m/^[0-9A-Za-z\@\.]+$/) or (length($new_email) > 254)) {

		return ('failure', 'Please enter a valid email address');

	}

	my $check_if_email_exists = check_if_user_info_exists('email', $new_email);

	if ($check_if_email_exists eq 'yes') {

		return ('failure', 'Email address already in use');

	}

	if (($new_pw =~ m/\s+/) or ($new_pw_repeat =~ m/\s+/)) {

		return ('failure', 'Passwords are alphanumeric and special characters only');

	}

	if ($new_pw ne $new_pw_repeat) {

		return ('failure', 'Passwords do not match');

	}


	if (length($new_pw) > 16) {

		return ('failure', 'Passwords cannot exceed 16 characters');

	}

	elsif (length($new_pw) < 8) {

		return ('failure', 'Password must be at least eight characters');

	}

	my $new_pw_md5_hex = md5_hex($new_pw);

	my @right_now = right_now();

	my $add_new_user = eval { $dbh->prepare('INSERT INTO users (user, pass, email, user_role, member_since, total_posts) VALUES (\''.$new_username.'\', \''.$new_pw_md5_hex.'\', \''.$new_email.'\', \'unemailed\', \''.$right_now[1].' '.$right_now[3].'\', \'0\')') };
		$add_new_user->execute();

	my $check_if_new_user_added = check_if_user_info_exists('user', $new_username);

	if ($check_if_new_user_added eq 'yes') {

		return ('success');			

	}

	else {

		return ('failure', 'Other');

	}

}

sub username_clean {

	my ($username) = (shift);

	$username =~ s/ +/ /g;
	$username =~ s/(^ | $)//g;

	return ($username);

}

sub check_if_user_info_exists {

	my ($type, $info) = (shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $check_if_exists = eval { $dbh->prepare('SELECT id FROM users WHERE '.$type.' = \''.$info.'\'') };
		$check_if_exists->execute();
	my $check_if_exists_response = $check_if_exists->fetchrow_hashref();

	if (${$check_if_exists_response}{'id'}) {

		return ('yes');

	}

	else {

		return ('no');

	}

}

sub check_if_user_id_exists {

	my ($user_id) = (shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $check_if_exists = eval { $dbh->prepare('SELECT user FROM users WHERE id = \''.$user_id.'\'') };
		$check_if_exists->execute();
	my $check_if_exists_response = $check_if_exists->fetchrow_hashref();

	if (${$check_if_exists_response}{'user'}) {

		return ('yes');

	}

	else {

		return ('no');

	}

}

sub gen_email_verification_token {

	my ($username, $email) = (shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $new_token = '';
	my $new_token_is_unique = '';

	until ($new_token_is_unique eq 'yes') {

		$new_token = gen_token().gen_token();

		my $check_if_new_token_is_unique = eval { $dbh->prepare('SELECT id FROM pending_account_verifications WHERE verification_token = \''.$new_token.'\'') };
			$check_if_new_token_is_unique->execute();
		my $check_if_new_token_is_unique_response = $check_if_new_token_is_unique->fetchrow_hashref();

		if (!${$check_if_new_token_is_unique_response}{'id'}) {

			$new_token_is_unique = 'yes';

		}

	}

	my $add_email_verification_token = eval { $dbh->prepare('INSERT INTO pending_account_verifications (verification_token, user) VALUES (\''.$new_token.'\', \''.$username.'\')') };
		$add_email_verification_token->execute();

	# will update this
	my $sender = $mailgun_registration_sender;
	my $to = $email;
	#my $from = 'From Sender <'.$sender.'>';
	my $subject = 'Account Registration';
	my $message = 'To: '.$to."\n".'From: '.$sender."\n".'Subject: Account Registration'."\n".'Content-type: text/html'."\n\n".'<html>'."\r\n".'<body>Verify your account at '."\r\n".' '.$domain.'emailconfirm?token='.$new_token.'&user='.$username.'</body></html>';

	send_email($message);
	update_user_role($username, 'unconfirmed');

}

sub gen_token {

	my @characters = ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z');

	my $token = $characters[rand @characters].$characters[rand @characters].$characters[rand @characters].$characters[rand @characters].$characters[rand @characters].(int(rand(9999999999))+100000);

	return ($token);

}

sub check_if_verification_token_exists {

	my ($verification_token, $username) = (shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $check_if_verification_token_exists = eval { $dbh->prepare('SELECT id FROM pending_account_verifications WHERE verification_token = \''.$verification_token.'\' AND user = \''.$username.'\'') };
		$check_if_verification_token_exists->execute();
	my $check_if_verification_token_exists_resposne = $check_if_verification_token_exists->fetchrow_hashref();

	if (${$check_if_verification_token_exists_resposne}{'id'}) {

		return ('yes');

	}

	else {

		return ('no');

	}

}

sub update_user_role {

	my ($username, $new_role) = (shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $check_if_username_exists = check_if_user_info_exists('user', $username);

	if ($check_if_username_exists eq 'yes') {
		
		my $update_user_role = eval { $dbh->prepare('UPDATE users SET user_role = \''.$new_role.'\' WHERE user = \''.$username.'\'') };
			$update_user_role->execute();

		my $check_if_user_role_updated = eval { $dbh->prepare('SELECT id FROM users WHERE user = \''.$username.'\' AND user_role = \''.$new_role.'\'') };
			$check_if_user_role_updated->execute();
		my $check_if_user_role_updated_response = $check_if_user_role_updated->fetchrow_hashref();

		if (${$check_if_user_role_updated_response}{'id'}) {

			return ('success');

		}

		else {

			return ('failure', '034');

		}

	}

	else {

		return ('failure', '033');

	}

}

sub new_user_session {

	my ($username) = (shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $session_id = '';
	my $session_id_is_unique = '';

	until ($session_id_is_unique eq 'yes') {

		$session_id = gen_token();

		my $check_if_session_id_is_unique = eval { $dbh->prepare('SELECT id FROM sessions WHERE session_id = \''.$session_id.'\'') };
			$check_if_session_id_is_unique->execute();
		my $check_if_session_id_is_unique_response = $check_if_session_id_is_unique->fetchrow_hashref();

		if (!${$check_if_session_id_is_unique_response}{'id'}) {

			$session_id_is_unique = 'yes';

		}

	}

	my $create_session = eval { $dbh->prepare('INSERT INTO sessions (session_id, user) VALUES (\''.$session_id.'\', \''.$username.'\')') };
		$create_session->execute();

	my $check_if_session_added = eval { $dbh->prepare('SELECT id FROM sessions WHERE session_id = \''.$session_id.'\' AND user = \''.$username.'\'') };
		$check_if_session_added->execute();
	my $check_if_session_added_response = $check_if_session_added->fetchrow_hashref();

	if (${$check_if_session_added_response}{'id'}) {

		return ($session_id);

	}

	else {

		return ('failure');
	}	

}

sub login_check {

	my ($username, $pw) = (shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($username !~ m/^[0-9A-Za-z\s+]+$/) {

		return ('failure', 'Usernames are alphanumeric and spaces only');

	}

	$username = username_clean($username);

	my $check_if_username_exists = check_if_user_info_exists('user', $username);

	if ($check_if_username_exists eq 'no') {

		return ('failure', 'No account with that username registered');

	}

	my $user_pw = get_info('pass', 'users', 'user', $username);

	if (md5_hex($pw) eq $user_pw) {

		return ('success', 'Logging in');

	}

	else {

		return ('failure', 'Password incorrect');

	}

}

sub update_user_pic {

	my ($user_id, $pic) = (shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $update_user_pic = eval { $dbh->prepare('UPDATE users SET profile_pic = \''.$pic.'\' WHERE id = \''.$user_id.'\'') };
		$update_user_pic->execute();

	my $check_if_user_pic_updated = eval { $dbh->prepare('SELECT user FROM users WHERE id = \''.$user_id.'\' AND profile_pic = \''.$pic.'\'') };
		$check_if_user_pic_updated->execute();
	my $check_if_user_pic_updated_response = $check_if_user_pic_updated->fetchrow_hashref();

	if (${$check_if_user_pic_updated_response}{'user'}) {

		return ('success');

	}

	else {

		return ('failure');
	}

}

sub update_user_email {

	my ($user_id, $email) = (shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $update_user_email = eval { $dbh->prepare('UPDATE users SET email = \''.$email.'\' WHERE id = \''.$user_id.'\'') };
		$update_user_email->execute();

	my $check_if_user_email_updated = eval { $dbh->prepare('SELECT user FROM users WHERE id = \''.$user_id.'\' AND email = \''.$email.'\'') };
		$check_if_user_email_updated->execute();
	my $check_if_user_email_updated_resonse = $check_if_user_email_updated->fetchrow_hashref();

	if (${$check_if_user_email_updated_resonse}{'user'}) {

		return ('success');

	}

	else {

		return ('failure');

	}

}

sub right_now {

	my $right_now = localtime();
		my @time_parts = split(' ', $right_now);
	 		my $day_of_the_week = $time_parts[0];
	 		my $month = $time_parts[1];
	 		my $day = $time_parts[2];
	 		my $year = $time_parts[4];
	 		my @time_parts_2 = split('\:', $time_parts[3]);
	 			my $hour = $time_parts_2[0];
	 			my $minute = $time_parts_2[1];

	return ($day_of_the_week, $month, $day, $year, $hour, $minute);

}

sub add_user_profile_comment {

	my ($user_id, $user, $author_id, $author, $comment, $time_posted) = (shift, shift, shift, shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if (($user_id =~ m/^[0-9]+$/) and ($user =~ m/^[0-9A-Za-z\s+]+$/) and ($author_id =~ m/^[0-9]+$/) and ($author =~ m/^[0-9A-Za-z\s+]+$/)) {

		$comment = clean_comment($comment);

		my $add_user_profile_comment = eval { $dbh->prepare('INSERT INTO user_profile_comments (user_id, user, author_id, author, comment, time_posted) VALUES (\''.$user_id.'\', \''.$user.'\', \''.$author_id.'\', \''.$author.'\', \''.$comment.'\', \''.$time_posted.'\')') };
			$add_user_profile_comment->execute();

		return ('success');

	}

	else {

		return ('failure');

	}

}

sub clean_comment {

	my ($comment) = (shift);

	$comment =~ s/\\/\\\\/g;
	$comment =~ s/\'/\\\'/g;

	return ($comment);

}

sub get_user_profile_pic {

	my ($by, $info) = (shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $get_user_profile_pic = eval { $dbh->prepare('SELECT profile_pic FROM users WHERE '.$by.' = \''.$info.'\'') };
		$get_user_profile_pic->execute();
	my $get_user_profile_pic_resposne = $get_user_profile_pic->fetchrow_hashref();

	if (${$get_user_profile_pic_resposne}{'profile_pic'}) {

		return 'userdata/'.(${$get_user_profile_pic_resposne}{'profile_pic'});

	}

	else {

		return ('none.jpg');

	}

}

sub add_post_reply {

	my ($post_body, $topic_id, $board_id, $forum_id, $created_by_user_id, $created_by_user, $response_to, $page) = (shift, shift, shift, shift, shift, shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	$post_body = clean_comment($post_body);

	if (($topic_id =~ m/^[0-9]+$/) and ($board_id =~ m/^[0-9]+$/) and ($forum_id =~ m/^[0-9]+$/) and ($created_by_user_id =~ m/^[0-9]+$/)) {

		my @right_now = right_now();
			my $time_created = $right_now[2].' '.$right_now[1].', '.$right_now[3];

		my $add_post_reply = eval { $dbh->prepare('INSERT INTO posts (post_body, topic_id, board_id, forum_id, created_by_user_id, created_by_user, time_created, response_to, page) VALUES (\''.$post_body.'\', \''.$topic_id.'\', \''.$board_id.'\', \''.$forum_id.'\', \''.$created_by_user_id.'\', \''.$created_by_user.'\', \''.$time_created.'\', \''.$response_to.'\', \''.$page.'\')') };
			$add_post_reply->execute();

		my $get_new_post_id = eval { $dbh->prepare('SELECT LAST_INSERT_ID()') };
			$get_new_post_id->execute();
		my $get_new_post_id_response = $get_new_post_id->fetchrow_hashref();

		my $update_topic = eval { $dbh->prepare('UPDATE topics SET last_post_by = \''.$created_by_user.'\', last_post_id = \''.${$get_new_post_id_response}{'LAST_INSERT_ID()'}.'\' WHERE id = \''.$topic_id.'\'') };
			$update_topic->execute();

		return ('success');

	}

	else {

		return ('failure');

	}

}

sub add_topic {

	my ($topic, $board_id, $forum_id, $created_by_user_id, $created_by_user, $post_body) = (shift, shift, shift, shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	$topic = clean_comment($topic);
	$post_body = clean_comment($post_body);

	if (($board_id =~ m/^[0-9]+$/) and ($forum_id =~ m/^[0-9]+$/) and ($created_by_user_id =~ m/^[0-9]+$/)) {

		my @right_now = right_now();
			my $time_created = $right_now[2].' '.$right_now[1].', '.$right_now[3];

		my $post_preview = substr($post_body, 0, 150);

		my $add_topic = eval { $dbh->prepare('INSERT INTO topics (topic, board_id, forum_id, created_by_user_id, created_by_user, time_created, post_preview, replies, last_post_by) VALUES (\''.$topic.'\', \''.$board_id.'\', \''.$forum_id.'\', \''.$created_by_user_id.'\', \''.$created_by_user.'\', \''.$time_created.'\', \''.$post_preview.'\', \'0\', \''.$created_by_user.'\')') };
			$add_topic->execute();

		my $get_new_topic_id = eval { $dbh->prepare('SELECT id FROM topics WHERE topic = \''.$topic.'\' AND board_id = \''.$board_id.'\' ORDER BY id DESC') };
			$get_new_topic_id->execute();
		my $get_new_topic_id_response = $get_new_topic_id->fetchrow_hashref();

		if (${$get_new_topic_id_response}{'id'}) {

			my $add_post_reply = add_post_reply($post_body, ${$get_new_topic_id_response}{'id'}, $board_id, $forum_id, $created_by_user_id, $created_by_user);

			if ($add_post_reply eq 'success') {

				return ('success', ${$get_new_topic_id_response}{'id'});

			}

			else {

				return ('failure', '029');

			}

		}

		else {

			return ('failure', '030');

		}

	}

	else {

		return ('failure', '031');

	}	

}

sub add_forum {

	my ($forum_name, $forum_info) = (shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if (length($forum_name) > 150) {

		return ('failure', 'Forum name cannot exceed 150 characters');

	}

	elsif (($forum_info) and (length($forum_info) > 500)) {

		return ('failure', 'Forum info cannot exceed 500 characters');

	}

	else {

		$forum_name = clean_comment($forum_name);

		if ($forum_info) {

			$forum_info = clean_comment($forum_info);

		}

		my $add_forum = eval { $dbh->prepare('INSERT INTO forums (forum_name, forum_info) VALUES (\''.$forum_name.'\', \''.$forum_info.'\')') };
			$add_forum->execute();

		return ('success', 'Forum added');

	}

}

sub add_board {

	my ($board_name, $board_info, $forum_id) = (shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if (length($board_name) > 150) {

		return ('failure', 'Board name cannot exceed 150 characters');

	}

	elsif (($board_info) and (length($board_info) > 500)) {

		return ('failure', 'Board info cannot exceed 500 characters');

	}

	else {

		$board_name = clean_comment($board_name);

		if ($board_info) {

			$board_info = clean_comment($board_info);

		}

		my $add_board = eval { $dbh->prepare('INSERT INTO boards (board_name, board_info, forum_id, topic_count, post_count) VALUES (\''.$board_name.'\', \''.$board_info.'\', \''.$forum_id.'\', \'0\', \'0\')') };
			$add_board->execute();

		return ('success', 'Board added');

	}

}

sub delete {

	my ($table, $by, $info) = (shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $delete = eval { $dbh->prepare('DELETE FROM '.$table.' WHERE '.$by.' = \''.$info.'\'') };
		$delete->execute();

}

sub get_count {

	my ($table, $by, $info, $and_what) = (shift, shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $and = '';

	if ($and_what) {

		$and = $and_what;

	}

	my $count = '0';

	my $get_count = eval { $dbh->prepare('SELECT COUNT(*) FROM '.$table.' WHERE '.$by.' = \''.$info.'\''.$and) };
		$get_count->execute();
	my $get_count_response = $get_count->fetchrow_hashref();

	if (${$get_count_response}{'COUNT(*)'}) {

		$count = ${$get_count_response}{'COUNT(*)'};

	}

	return ($count);

}

sub get_info {

	my ($get_what, $from_what, $where_what, $is_what, $what_else) = (shift, shift, shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $and_what = '';

	if ($what_else) {

		$and_what = $what_else;

	}

	my $get_info = eval { $dbh->prepare('SELECT '.clean_comment($get_what).' FROM '.clean_comment($from_what).' WHERE '.clean_comment($where_what).' = \''.clean_comment($is_what).'\''.$and_what) };
		$get_info->execute();
	my $get_info_response = $get_info->fetchrow_hashref();

	return (${$get_info_response}{$get_what});

}

sub get_all_info {

	my ($get_what, $from_what, $where_what, $is_what, $order_by, $order_type, $and_anything_else) = (shift, shift, shift, shift, shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $where = '';

	if (($where_what) and ($where_what ne '') and ($is_what) and ($is_what ne '')) {

		$where = ' WHERE '.clean_comment($where_what).' = \''.clean_comment($is_what).'\'';

	}

	my $order = '';

	if (($order_by) and ($order_by ne '') and ($order_type) and ($order_type ne '')) {

		$order = ' ORDER BY '.$order_by.' '.$order_type;

	}

	my $anything_else = '';

	if ($and_anything_else) {

		$anything_else = $and_anything_else;

	}

	my $get_account_info = eval { $dbh->prepare('SELECT '.clean_comment($get_what).' FROM '.clean_comment($from_what).$where.$order.$anything_else) };
		$get_account_info->execute();
	my $get_account_info_response = $get_account_info->fetchall_arrayref();

	return ($get_account_info_response);

}

sub user_roles {

	my @user_groups = ('unconfirmed', 'user', 'mod', 'admin', 'banned');

	return (@user_groups);

}

sub update {

	my ($update_what, $set_what, $set_what_to, $where_what, $is_what) = (shift, shift, shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $update = eval { $dbh->prepare('UPDATE '.clean_comment($update_what).' SET '.clean_comment($set_what).' = \''.clean_comment($set_what_to).'\' WHERE '.clean_comment($where_what).' = \''.clean_comment($is_what).'\'') };
		$update->execute();

	my $check_update = eval { $dbh->prepare('SELECT '.clean_comment($set_what).' FROM '.clean_comment($update_what).' WHERE '.clean_comment($where_what).' = \''.clean_comment($is_what).'\'') };
		$check_update->execute();
	my $check_update_response = $check_update->fetchrow_hashref();

	return (${$check_update_response}{$set_what});

}

sub insert {

	my ($table, $columns, $values) = (shift, shift, shift);

	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $insert = eval { $dbh->prepare('INSERT INTO '.$table.' ('.$columns.') VALUES ('.$values.')') };
		$insert->execute();

}

sub send_email {

	my ($message) = (shift);

	my $transport = Email::Sender::Transport::Mailgun->new(
		api_key => $mailgun,
		domain  => $mailgun_domain
	);

	sendmail($message, { transport => $transport });

}

sub uri_encode {

	my ($string) = (shift);

	my @string_parts = split(//, $string);
		my $string_length = scalar(@string_parts);

	my $translated_string = '';
	my $counter = 0;

	while ($counter < $string_length) {

		my $character = $string_parts[$counter];

		my %uri_character_map = (
			'!' => '21%', '@' => '40%', '#' => '23%', '$' => '24%', '%' => '25%', '^' => '%5E', '&' => '26%',
			'*' => '%2A', '(' => '28%', ')' => '29%', '=' => '%3D', '+' => '%2B', '[' => '%5B', ']' => '%5D',
			'{' => '%7B', '}' => '%7D', '|' => '%7C', '\\' => '%5C', ';' => '%3B', ':' => '%3A', '\'' => '27%',
			'"' => '22%', ',' => '%2C', '<' => '%3C', '>' => '%3E', '?' => '%3F', '/' => '%2F', '`' => '60%',
			);

		if ($uri_character_map{$character}) {

			my $translated_character = $uri_character_map{$character};
				$translated_string = $translated_string.$translated_character;

		}

		else {

			$translated_string = $translated_string.$character;

		}

		$counter++;


	}

	return ($translated_string);

}

1;



