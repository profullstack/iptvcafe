#!/usr/bin/perl
# code by Robert Alexander
# robert@paperhouse.io
# https://github.com/rta10

use strict;
use warnings;
use Mojolicious::Lite;
use Mojo::Upload;
use DBI;
use LWP::UserAgent;
use HTTP::Cookies;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use File::Basename;
use File::Path 'mkpath';
use lib dirname (__FILE__);
use Minimojo;
use Dotenv -load => qw(.env .env.local);

my $domain = $ENV{'DOMAIN'};
my $db = $ENV{'DB'};
my $db_user = $ENV{'DB_USER'};
my $db_pw = $ENV{'DB_PASS'};
my $mailgun = $ENV{'MAILGUN'};
my $mailgun_domain = $ENV{'MAILGUN_DOMAIN'};


# --------------------------------------------------

get '/' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	my $is_user_logged_in = '';
	my $active_user_info = '';

	if ($self->session('session')) {

		$is_user_logged_in = 'yes';
		$active_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));

	}

	my $error = $self->param('error');

	my $are_forums = '';
	my @get_forums = Minimojo::get_all_info('*', 'forums', '', '', 'id', 'ASC');

	if ($get_forums[0][0][0]) {

		$are_forums = Minimojo::get_all_info('*', 'forums', '', '', 'id', 'ASC');

	}

	$self->stash(is_user_logged_in => $is_user_logged_in, active_user_info => $active_user_info, error => $error, are_forums => $are_forums);

	$self->render(template => 'index');

} => 'index';

# --------------------------------------------------

get '/register' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		$self->redirect_to('/account');

	}

	else {

		my $error = $self->param('error');
			$self->stash(error => $error);

		$self->render(template => 'register');

	}

} => 'register';

post '/register' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		$self->redirect_to('/account');

	}

	else {

		if (($self->param('new_username')) and ($self->param('new_email')) and ($self->param('new_pw')) and ($self->param('new_pw_repeat'))) {

			if ($self->param('terms_agree') eq 'yes') {

				my @new_user_check = Minimojo::new_user_check($self->param('new_username'), $self->param('new_email'), $self->param('new_pw'), $self->param('new_pw_repeat'));

				if ($new_user_check[0] eq 'failure') {

					$self->redirect_to('/register?error='.$new_user_check[1]);

				}

				elsif ($new_user_check[0] eq 'success') {

					my $new_user_session = Minimojo::new_user_session($self->param('new_username'));

					if ($new_user_session ne 'failure') {

						$self->session('session' => $new_user_session);
						$self->session('username' => $self->param('new_username'));

						$self->redirect_to('/account');

					}

					else {

						$self->redirect_to('/error?code=036');

					}

				}

			}

			else {

				$self->redirect_to('/register?error=You must agree to the terms of service');

			}

		}

		else {

			$self->redirect_to('/register?error=All fields required');

		}

	}

} => 'register';

# --------------------------------------------------

get '/login' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		$self->redirect_to('/account');

	}

	else {

	my $error = $self->param('error');
		$self->stash(error => $error);

	$self->render(template => 'login');

	}

} => 'login';

post '/login' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {
	
		$self->redirect_to('/account');

	}

	else {

		if (($self->param('username')) and ($self->param('pw'))) {

			my @login_check = Minimojo::login_check($self->param('username'), $self->param('pw'));

			if ($login_check[0] eq 'failure') {

				$self->redirect_to('/login?error='.$login_check[1]);

			}

			elsif ($login_check[0] eq 'success') {

				my $new_user_session = Minimojo::new_user_session($self->param('username'));

				if ($new_user_session ne 'failure') {

					$self->session('session' => $new_user_session);
					$self->session('username' => $self->param('username'));

					$self->redirect_to('/account');

				}

				else {

					$self->redirect_to('/error?code=035');

				}

			}

		}

		else {

			$self->redirect_to('/login?error=All fields required');

		}

	}

} => 'login';

# --------------------------------------------------

get '/emailconfirm' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if (($self->param('token')) and ($self->param('user'))) {

		my $check_if_verification_token_exists = Minimojo::check_if_verification_token_exists($self->param('token'), $self->param('user'));

		if ($check_if_verification_token_exists eq 'yes') {

			my @update_user_role = Minimojo::update_user_role($self->param('user'), 'user');

			if ($update_user_role[0] eq 'success') {

				my $remove_pending_verification = eval { $dbh->prepare('DELETE FROM pending_account_verifications WHERE verification_token = \''.$self->param('token').'\'') };
					$remove_pending_verification->execute();

				$self->redirect_to('/account');

			}

			elsif ($update_user_role[0] eq 'failure') {

				$self->redirect_to('/error?code='.$update_user_role[1]);

			}

			else {

				$self->redirect_to('/error?code=00');

			}

		}

		else {

			$self->redirect_to('/error?code=01');

		}

	}

	else {

		$self->redirect_to('/');

	}

} => 'emailconfirm';

# --------------------------------------------------

get '/account' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		my $user_role = Minimojo::get_info('user_role', 'users', 'user', $self->session('username'));

		if (!$user_role) {

			$self->redirect_to('/error?code=02');

		}

		elsif (($user_role eq 'unemailed') or ($user_role eq 'unconfirmed')) {

			$self->redirect_to('/account/pending');

		}

		elsif ($user_role eq 'banned') {

			$self->redirect_to('/error?code=Banned');

		}

		else {

			my $user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));
			my $error = $self->param('error');

			$self->stash(user_info => $user_info, error => $error);
			$self->render(template => 'account');

		}

	}

	else {

		$self->redirect_to('/login');

	}

} => 'account';

post '/account' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		my $user_role = Minimojo::get_info('user_role', 'users', 'user', $self->session('username'));

		if (!$user_role) {

			$self->redirect_to('/error?code=02');

		}

		elsif (($user_role eq 'unemailed') or ($user_role eq 'unconfirmed')) {

			$self->redirect_to('/account/pending');

		}

		else {

			if ($self->param('action') eq 'update_email') {

				if (!$self->param('user_id')) {

					$self->redirect_to('/error?code=04');

				}

				elsif (!$self->param('email')) {

					$self->redirect_to('/account?error=No email address provided');

				}

				else {

					my @get_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));

					if ($self->param('user_id') eq $get_user_info[0][0][0]) {

						if (($self->param('email') !~ m/^(.*?)\@(.*?)\./) or ($self->param('email') !~ m/^[0-9A-Za-z\@\.]+$/) or (length($self->param('email')) > 254)) {

							$self->redirect_to('/account?error=Please enter a valid email address');

						}

						else {

							my $check_if_email_exists = Minimojo::check_if_user_info_exists('email', $self->param('email'));

							if ($check_if_email_exists eq 'yes') {

								$self->redirect_to('/account?error=Email address already in use');

							}

							else {

								my $update_user_email = Minimojo::update_user_email($self->param('user_id'), $self->param('email'));

								if ($update_user_email eq 'success') {

									$self->redirect_to('/account');

								}

								else {

									$self->redirect_to('/error?code=037');

								}

							}

						}

					}

					else {

						$self->redirect_to('/error?code=05');

					}

				}

			}

			elsif ($self->param('action') eq 'update_pic') {

				if (!$self->param('user_id')) {

					$self->redirect_to('/error?code=04');

				}

				elsif (!$self->param('pic')) {

					$self->redirect_to('/account?error=No image submitted');

				}

				else {

					my @get_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));

					if ($self->param('user_id') eq $get_user_info[0][0][0]) {

						for my $new_img (@{$self->req->uploads('pic')}) {

							my @allowed_filetypes = ('jpg', 'jpeg', 'png');

							my ($filetype) = ($new_img->filename() =~ m/.*\.(.*?)$/);

							if (!grep {$filetype eq $_} @allowed_filetypes) {

								$self->redirect_to('/account?error=Image must be a jpg or png');

							}

							my $new_img_name = Minimojo::gen_token().'.'.$filetype;
								$new_img->move_to('/home/anthony/anthony/public/userdata/'.$new_img_name);

							if (-e '/home/anthony/anthony/public/userdata/'.$new_img_name) {

								my $update_user_pic = Minimojo::update_user_pic($self->param('user_id'), $new_img_name);

								if ($update_user_pic eq 'success') {

									$self->redirect_to('/account');

								}

								else {

									$self->redirect_to('/error?code=032');

								}

							}

							else {

								$self->redirect_to('/account?error=Error uploading image, please try again');

							}

						}

					}

					else {

						$self->redirect_to('/error?code=05');

					}

				}

			}

			else {

				$self->redirect_to('/error?code=03');

			}

		}

	}

	else {

		$self->redirect_to('/login');

	}

} => 'account';

# --------------------------------------------------

get '/account/pending' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		my $user_role = Minimojo::get_info('user_role', 'users', 'user', $self->session('username'));

		if (!$user_role) {

			$self->redirect_to('/error?code=02');

		}

		elsif (($user_role eq 'unemailed') or ($user_role eq 'unconfirmed')) {

			$self->render(template => 'unconfirmed');			

		}

		else {

			$self->redirect_to('/account');

		}

	}

	else {

		$self->redirect_to('/login');

	}

} => 'accountpending';

# --------------------------------------------------

get '/profile' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if (($self->param('id')) and ($self->param('id') =~ m/^[0-9]+$/)) {

		my $check_if_user_id_exists = Minimojo::check_if_user_id_exists($self->param('id'));

		if ($check_if_user_id_exists eq 'no') {

			$self->redirect_to('/');

		}

		elsif ($check_if_user_id_exists eq 'yes') {

			my $is_user_logged_in = '';
			my $active_user_info = '';

			if ($self->session('session')) {

				$is_user_logged_in = 'yes';
				$active_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));

			}

			my $user_profile_info = Minimojo::get_all_info('*', 'users', 'id', $self->param('id'));

			my $error = $self->param('error');

			my $user_profile_comments = '';
			my @get_user_profile_comments = Minimojo::get_all_info('*', 'user_profile_comments', 'user_id', $self->param('id'), 'id', 'DESC');

			if ($get_user_profile_comments[0][0][0]) {

				$user_profile_comments = Minimojo::get_all_info('*', 'user_profile_comments', 'user_id', $self->param('id'), 'id', 'DESC');

			}

			$self->stash(is_user_logged_in => $is_user_logged_in, active_user_info => $active_user_info, user_profile_info => $user_profile_info, error => $error, user_profile_comments => $user_profile_comments);
			$self->render(template => 'profile');

		}

	}

	else {

		$self->redirect_to('/');

	}

} => 'profile';

post '/profile' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		my $user_role = Minimojo::get_info('user_role', 'users', 'user', $self->session('username'));

		if (!$user_role) {

			$self->redirect_to('/error?code=02');

		}

		elsif (($user_role eq 'unemailed') or ($user_role eq 'unconfirmed')) {

			$self->redirect_to('/account/pending');

		}

		else {

			if ($self->param('action') eq 'user_profile_comment') {

				if (($self->param('user_id')) and ($self->param('user')) and ($self->param('author_id')) and ($self->param('author'))) {

					if (lc($self->param('author')) eq lc($self->session('username'))) {

						my @check_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));

						if ($check_user_info[0][0][0] eq $self->param('author_id')) {

							if (($self->param('comment')) and (length($self->param('comment') < 500))) {

								my @right_now = Minimojo::right_now();
									my $time_posted = $right_now[1].' '.$right_now[2].', '.$right_now[3];

								my $add_user_profile_comment = Minimojo::add_user_profile_comment($self->param('user_id'), $self->param('user'), $self->param('author_id'), $self->param('author'), $self->param('comment'), $time_posted);

								if ($add_user_profile_comment eq 'success') {

									my $add_notification = Minimojo::insert('notifications', 'user_id, notification, notification_status', '\''.$self->param('user_id').'\', \'<a href="https://anthony.paperhouse.cc/profile?id='.$self->param('author_id').'" target="_blank">'.$self->param('author').'</a> left a comment on <a href="https://anthony.paperhouse.cc/profile?id='.$self->param('user_id').'" target="_blank">your profile</a>\', \'unread\'');

									$self->redirect_to('/profile?id='.$self->param('user_id'));

								}

								elsif ($add_user_profile_comment eq 'failure') {

									$self->redirect_to('/profile?id='.$self->param('user_id').'&error=Please try again');

								}						

							}

							else {

								$self->redirect_to('/profile?id='.$self->param('user_id').'&error=Comment field cannot be empty or exceed 500 characters');

							}						

						}

						else {

							$self->redirect_to('/error?code=08');

						}

					}

					else {

						$self->redirect_to('/error?code=07');

					}


				}

				else {

					$self->redirect_to('/error?code=09');

				}

			}

			else {

				$self->redirect_to('/error?code=08');

			}

		}

	}

	else {

		$self->redirect_to('/error?code=06');

	}

} => 'profile';

# --------------------------------------------------

get '/boards' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->param('id')) {

		if ($self->param('id') =~ m/^[0-9]+$/) {

			my $get_board_data = Minimojo::get_all_info('*', 'boards', 'id', $self->param('id'));

			if ($get_board_data) {

				my $is_user_logged_in = '';
				my $active_user_info = '';

				if ($self->session('session')) {

					$is_user_logged_in = 'yes';
					$active_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));

				}

				my $error = $self->param('error');
				my $page = $self->param('page');

				$self->stash(get_board_data => $get_board_data, is_user_logged_in => $is_user_logged_in, active_user_info => $active_user_info, error => $error, page => $page);
				$self->render(template => 'boards');


			}

			else {

				$self->redirect_to('/?error=Forum with specified id does not exist');

			}

		}

		else {

			$self->redirect_to('/error?code=010');

		}

	}

	else {

		$self->redirect_to('/');

	}

} => 'boards';

# --------------------------------------------------

get '/topics' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->param('id')) {

		if ($self->param('id') =~ m/^[0-9]+$/) {

			my $get_topic_info = Minimojo::get_all_info('*', 'topics', 'id', $self->param('id'));

			if ($get_topic_info) {

				my $is_user_logged_in = '';
				my $active_user_info = '';

				if ($self->session('session')) {

					$is_user_logged_in = 'yes';
					$active_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));

				}

				my $error = $self->param('error');
				my $page = $self->param('page');
				my $reply_to = $self->param('reply_to');

				$self->stash(get_topic_info => $get_topic_info, is_user_logged_in => $is_user_logged_in, active_user_info => $active_user_info, error => $error, reply_to => $reply_to, page => $page);
				$self->render(template => 'topics');


			}

			else {

				$self->redirect_to('/?error=Topic with specified id does not exist');

			}

		}

		else {

			$self->redirect_to('/error?code=011');

		}

	}

	else {

		$self->redirect_to('/');

	}

} => 'topics';

post '/topics' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		my $user_role = Minimojo::get_info('user_role', 'users', 'user', $self->session('username'));

		if (!$user_role) {

			$self->redirect_to('/error?code=02');

		}

		elsif (($user_role eq 'unemailed') or ($user_role eq 'unconfirmed')) {

			$self->redirect_to('/account/pending');

		}

		else {

			if ($self->param('action') eq 'new_topic') {

				if (($self->param('board_id')) and ($self->param('forum_id')) and ($self->param('created_by_user_id')) and ($self->param('created_by_user'))) {

					if (!$self->param('topic')) {

						$self->redirect_to('/boards?id='.$self->param('board_id').'&error=Topic cannot be empty');

					}

					elsif (!$self->param('post_body')) {

						$self->redirect_to('/boards?id='.$self->param('board_id').'&error=Topic body be empty');

					}

					elsif (lc($self->param('created_by_user')) ne lc($self->session('username'))) {

						$self->redirect_to('/error?code=020');

					}

					elsif (length($self->param('topic')) > 150) {

						$self->redirect_to('/boards?id='.$self->param('board_id').'&error=Topic cannot exceed 150 characters');

					}

					elsif (length($self->param('post_body')) > 2000) {

						$self->redirect_to('/boards?id='.$self->param('topic_id').'&error=Posts cannot exceed 2000 characters');

					}

					else {

						my @add_topic = Minimojo::add_topic($self->param('topic'), $self->param('board_id'), $self->param('forum_id'), $self->param('created_by_user_id'), $self->session('username'), $self->param('post_body'));

						if ($add_topic[0] eq 'success') {

							$self->redirect_to('/topics?id='.$add_topic[1]);

						}

						elsif ($add_topic[0] eq 'failure') {

							$self->redirect_to('/error?code='.$add_topic[1]);

						}

						else {

							$self->redirect_to('/error?code=020');

						}

					}

				}

				else {

					$self->redirect_to('/error?code=019');

				}

			}

			else {

				$self->redirect_to('/error?code=018');

			}

		}

	}

	else {

		$self->redirect_to('/error?code=017');

	}

} => 'topics';

# --------------------------------------------------

post '/posts' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		my $user_role = Minimojo::get_info('user_role', 'users', 'user', $self->session('username'));

		if (!$user_role) {

			$self->redirect_to('/error?code=02');

		}

		elsif (($user_role eq 'unemailed') or ($user_role eq 'unconfirmed')) {

			$self->redirect_to('/account/pending');

		}

		else {

			if ($self->param('action') eq 'post_reply') {

				if (($self->param('topic_id')) and ($self->param('board_id')) and ($self->param('forum_id')) and ($self->param('created_by_user_id')) and ($self->param('created_by_user'))) {

					if (!$self->param('post_body')) {

						$self->redirect_to('/topics?id='.$self->param('topic_id').'&error=Reply cannot be empty');

					}

					elsif (length($self->param('post_body')) > 2000) {

						$self->redirect_to('/topics?id='.$self->param('topic_id').'&error=Posts cannot exceed 2000 characters');

					}

					elsif (lc($self->session('username')) ne lc($self->param('created_by_user'))) {

						$self->redirect_to('/error?code=015');

					}

					else {

						my $response_to = '';

						if (($self->param('reply_to')) and ($self->param('reply_to') ne '')) {

							my $check_if_reply_to_exists = Minimojo::get_info('created_by_user_id', 'posts', 'id', $self->param('reply_to'), ' AND topic_id = \''.Minimojo::clean_comment($self->param('topic_id')).'\'');

							if ($check_if_reply_to_exists) {

								$response_to = $self->param('reply_to');

							}

							else {

								$self->redirect_to('/error?code=048');

							}

						}

						my $add_post_reply = Minimojo::add_post_reply($self->param('post_body'), $self->param('topic_id'), $self->param('board_id'), $self->param('forum_id'), $self->param('created_by_user_id'), $self->param('created_by_user'), $response_to, $self->param('page'));

						if ($add_post_reply eq 'success') {

							if (($response_to) and ($response_to ne '')) {

								my $page = '';

								if (($self->param('page')) and ($self->param('page') > 1)) {

									$page = '&page='.$self->param('page');

								}

								my $add_notification = Minimojo::insert('notifications', 'user_id, notification, notification_status', '\''.Minimojo::get_info('created_by_user_id', 'posts', 'id', $response_to).'\', \'<a href="https://anthony.paperhouse.cc/profile?id='.$self->param('created_by_user_id').'" target="_blank">'.$self->param('created_by_user').'</a> <a href="https://anthony.paperhouse.cc/topics?id='.$self->param('topic_id').$page.'#post-'.$response_to.'" target="_blank">replied</a> to your post in <a href="https://anthony.paperhouse.cc/topics?id='.$self->param('topic_id').'" target="_blank">'.Minimojo::get_info('topic', 'topics', 'id', $self->param('topic_id')).'</a>\', \'unread\'');

							}

							$self->redirect_to('/topics?id='.$self->param('topic_id'));	

						}

						else {

							$self->redirect_to('/error?code=016');

						}

					}

				}

				else {

					$self->redirect_to('/error?code=014');

				}

			}

			else {

				$self->redirect_to('/error?code=013');

			}

		}

	}

	else {

		$self->redirect_to('/error?code=012');

	}

} => 'posts';

# --------------------------------------------------

get '/admin' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if (($self->session('session')) and (Minimojo::get_info('user_role', 'users', 'user', $self->session('username')) eq 'admin')) {

		my $active_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));

		if ($active_user_info) {

			my $error = $self->param('error');
			my $success = $self->param('success');
			my $action = $self->param('action');
			my $type = $self->param('type');
			my $forum_id = $self->param('forum_id');
			my $id = $self->param('id');

			$self->stash(active_user_info => $active_user_info, error => $error, success => $success, action => $action, type => $type, forum_id => $forum_id, id => $id);

			$self->render(template => 'admin');

		}

		else {

			$self->redirect_to('/error?code=021');

		}

	}

	else {

		$self->redirect_to('/');

	}

} => 'admin';

post '/admin' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if (($self->session('session')) and (Minimojo::get_info('user_role', 'users', 'user', $self->session('username')) eq 'admin')) {

		if ($self->param('action') eq 'add') {

			if ($self->param('type') eq 'forum') {

				if (($self->param('created_by_user')) and ($self->param('created_by_user_id'))) {

					if ($self->param('forum_name')) {

						my $get_forum_info = Minimojo::get_info('id', 'forums', 'forum_name', $self->param('forum_name'));

						if (!$get_forum_info) {

							my @add_forum = Minimojo::add_forum($self->param('forum_name'), $self->param('forum_info'));

							if ($add_forum[0] eq 'success') {

								$self->redirect_to('/');

							}

							elsif ($add_forum[0] eq 'failure') {

								$self->redirect_to('/admin?action=add&type=forum&error='.$add_forum[1]);

							}

							else {

								$self->redirect_to('/error?code=024');

							}

						}

						else {

							$self->redirect_to('/admin?action=add&type=forum&error=Forum with that name already exists');

						}

					}

					else {

						$self->redirect_to('/admin?action=add&type=forum&error=Forum name required');

					}

				}

				else {

					$self->redirect_to('/error?code=023');

				}

			}

			elsif ($self->param('type') eq 'board') {

				if (($self->param('created_by_user')) and ($self->param('created_by_user_id'))) {

					if ($self->param('board_name')) {

						my $get_board_info = Minimojo::get_info('id', 'boards', 'board_name', $self->param('board_name'), ' AND forum_id = \''.$self->param('forum_id').'\'');

						if (!$get_board_info) {

							my @add_board = Minimojo::add_board($self->param('board_name'), $self->param('board_info'), $self->param('forum_id'));

							if ($add_board[0] eq 'success') {

								$self->redirect_to('/');

							}

							elsif ($add_board[0] eq 'failure') {

								$self->redirect_to('/admin?action=add&type=board&error='.$add_board[1]);

							}

							else {

								$self->redirect_to('/error?code=026');

							}

						}

						else {

							$self->redirect_to('/admin?action=add&type=board&error=Board with that name already exists');

						}

					}

					else {

						$self->redirect_to('/admin?action=add&type=board&error=Board name required');

					}

				}				

			}

			else {

				$self->redirect_to('/error?code=025');

			}

		}

		elsif ($self->param('action') eq 'delete') {

			if (($self->param('created_by_user')) and ($self->param('created_by_user_id')) and ($self->param('type')) and ($self->param('id')) and ($self->param('are_you_sure'))) {

				if ($self->param('are_you_sure') eq 'Yes') {

					Minimojo::delete($self->param('type').'s', 'id', $self->param('id'));

					if (($self->param('type') eq 'forum') or ($self->param('type') eq 'board') or ($self->param('type') eq 'topic')) {

						Minimojo::delete('posts', $self->param('type').'_id', $self->param('id'));

					}

					elsif (($self->param('type') eq 'forum') or ($self->param('type') eq 'board')) {

						Minimojo::delete('topics', $self->param('type').'_id', $self->param('id'));

					}

					elsif ($self->param('type') eq 'forum') {

						Minimojo::delete('boards', 'forum_id', $self->param('id'));

					}

					$self->redirect_to('/');

				}

				elsif ($self->param('are_you_sure') eq 'No') {

					$self->redirect_to('/');

				}

				else {

					$self->redirect_to('/error?code=028');

				}

			}

			else {

				$self->redirect_to('/error?code=027');

			}

		}

		elsif ($self->param('action') eq 'edit') {

			if ($self->param('type') eq 'user') {

				if ($self->param('edit') eq 'role') {

					if (($self->param('user_role')) and ($self->param('admin')) and ($self->param('admin_id')) and ($self->param('id'))) {

						my $update_user_role = Minimojo::update('users', 'user_role', $self->param('user_role'), 'id', $self->param('id'));

						if ($update_user_role eq $self->param('user_role')) {

							$self->redirect_to('/admin?action=edit&type=user&id='.$self->param('id').'&success=User role updated');

						}

						else {

							$self->redirect_to('/error?code=041');

						}

					}

					else {

						$self->redirect_to('/error?code=040');

					}

				}

				else {

					$self->redirect_to('/error?code=039');

				}

			}

			else {

				$self->redirect_to('/error?code=038');
			}

		}

		elsif ($self->param('action') eq 'head_admin_setting') {

			my $head_admin_check = Minimojo::get_info('id', 'settings', 'setting_name', 'head_admin_user', ' AND setting_value = \''.$self->session('username').'\'');

			if (($head_admin_check) and ($head_admin_check ne '')) {

				if (lc($self->session('username')) eq lc($self->param('admin'))) {

					if ($self->param('type') eq 'domain') {

						if ($self->param('domain')) {

							my $update_domain = Minimojo::update('settings', 'setting_value', $self->param('domain'), 'setting_name', 'domain');

							if ($update_domain eq $self->param('domain')) {

								$self->redirect_to('/');

							}

							else {

								$self->redirect_to('/admin?error=Please try again');

							}

						}

						else {

							$self->redirect_to('/error?code=052');

						}

					}

					elsif ($self->param('type') eq 'site_name') {

						if ($self->param('site_name')) {

							my $update_site_name = Minimojo::update('settings', 'setting_value', $self->param('site_name'), 'setting_name', 'site_name');

							if ($update_site_name eq $self->param('site_name')) {

								$self->redirect_to('/');

							}

							else {

								$self->redirect_to('/admin?error=Please try again');

							}

						}

						else {

							$self->redirect_to('/admin?error=Site name cannot be empty');

						}

					}

					elsif ($self->param('type') eq 'add_head_admin') {

						if ($self->param('admin_user')) {

							my $check_admin_user_user_role = Minimojo::get_info('user_role', 'users', 'user', $self->param('admin_user'));

							if ($check_admin_user_user_role) {

								if ($check_admin_user_user_role eq 'admin') {

									my $check_if_already_head_admin = Minimojo::get_info('id', 'settings', 'setting_name', 'head_admin_user', ' AND setting_value = \''.Minimojo::clean_comment($self->param('admin_user')).'\'');

									if ($check_if_already_head_admin) {

										$self->redirect_to('/admin?error=User already head admin');

									}

									else {

										my $add_head_admin = Minimojo::insert('settings', 'setting_name, setting_value', '\'head_admin_user\', \''.Minimojo::clean_comment($self->param('admin_user')).'\'');

										$self->redirect_to('/admin');

									}

								}

								else {

									$self->redirect_to('/admin?error=User must first be promoted to admin');

								}

							}

							else {

								$self->redirect_to('/error?code=053');

							}

						}

						else {

							$self->redirect_to('/admin?error=Admin user cannot be empty');

						}

					}

					else {

						$self->redirect_to('/error?code=051');

					}

				}

				else {

					$self->redirect_to('/error?code=050');

				}

			}

			else {

				$self->redirect_to('/error?code=049');

			}

		}

		else {

			$self->redirect_to('/error?code=022');

		}

	}

	else {

		$self->redirect_to('/');

	}

} => 'admin';

# --------------------------------------------------

get '/mod' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		if (Minimojo::get_info('user_role', 'users', 'user', $self->session('username')) eq 'mod') {

			my $active_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));

			if ($active_user_info) {

				my $error = $self->param('error');
				my $success = $self->param('success');
				my $action = $self->param('action');
				my $type = $self->param('type');
				my $forum_id = $self->param('forum_id');
				my $id = $self->param('id');

				$self->stash(active_user_info => $active_user_info, error => $error, success => $success, action => $action, type => $type, forum_id => $forum_id, id => $id);

				$self->render(template => 'mod');

			}

			else {

				$self->redirect_to('/error?code=038');

			}

		}

		elsif (Minimojo::get_info('user_role', 'users', 'user', $self->session('username')) eq 'admin') {

			$self->redirect_to('/admin');

		}

		else {

			$self->redirect_to('/');

		}

	}

	else {

		$self->redirect_to('/login');

	}


} => 'mod';

post '/mod' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		if (Minimojo::get_info('user_role', 'users', 'user', $self->session('username')) eq 'mod') {

			if ($self->param('action') eq 'ban') {

				if (($self->param('mod_id') eq Minimojo::get_info('id', 'users', 'user', $self->session('username'))) and (lc($self->param('mod')) eq lc($self->session('username')))) {

					if (($self->param('user_role')) and ($self->param('id'))) {

						my $current_user_role = Minimojo::get_info('user_role', 'users', 'id', $self->param('id'));

						if ($current_user_role) {

							if (($current_user_role eq 'admin') or ($current_user_role eq 'mod')) {

								$self->redirect_to('/mod?action=ban&id='.$self->param('id').'&error=Cannot alter '.$current_user_role.' user');

							}

							elsif ($current_user_role eq $self->param('user_role')) {

								$self->redirect_to('/mod?action=ban&id='.$self->param('id').'&error=User role already set as '.$self->param('user_role'));

							}

							else {

								my $update_user_role = Minimojo::update('users', 'user_role', $self->param('user_role'), 'id', $self->param('id'));

								if ($update_user_role eq $self->param('user_role')) {

									$self->redirect_to('/mod?action=ban&id='.$self->param('id').'&success=User role updated');

								}

								else {

									$self->redirect_to('/mod?action=ban&id='.$self->param('id').'&error=Please try again');

								}

							}

						}

						else {

							$self->redirect_to('/error?code=045');

						}

					}

					else {

						$self->redirect_to('/error?code=044');

					}

				}

				else {

					$self->redirect_to('/error?code=043');

				}

			}

			elsif ($self->param('action') eq 'delete') {

				if (($self->param('mod_id') eq Minimojo::get_info('id', 'users', 'user', $self->session('username'))) and ($self->param('mod') eq $self->session('username'))) {

					if (($self->param('type')) and ($self->param('id')) and ($self->param('are_you_sure'))) {

						if ($self->param('type') =~ m/^(post|topic)$/) {

							if ($self->param('are_you_sure') eq 'Yes') {

								Minimojo::delete($self->param('type').'s', 'id', $self->param('id'));

								if ($self->param('type') eq 'topic') {

									Minimojo::delete('posts', $self->param('type').'_id', $self->param('id'));

								}

								$self->redirect_to('/');	

							}

							elsif ($self->param('are_you_sure') eq 'No') {

								$self->redirect_to('/');

							}

							else {

								$self->redirect_to('/error?code=047');

							}

						}

					}

					else {

						$self->redirect_to('/error?code=046');

					}

				}

				else {

					$self->redirect_to('/error?code=043');

				}

			}

			else {

				$self->redirect_to('/error?code=042');

			}

		}

		elsif (Minimojo::get_info('user_role', 'users', 'user', $self->session('username')) eq 'admin') {

			$self->redirect_to('/admin');

		}

		else {

			$self->redirect_to('/');

		}

	}

	else {

		$self->redirect_to('/login');

	}


} => 'mod';

# --------------------------------------------------

get '/notifications' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		my $user_role = Minimojo::get_info('user_role', 'users', 'user', $self->session('username'));

		if (!$user_role) {

			$self->redirect_to('/error?code=02');

		}

		elsif (($user_role eq 'unemailed') or ($user_role eq 'unconfirmed')) {

			$self->redirect_to('/account/pending');

		}

		elsif ($user_role eq 'banned') {

			$self->redirect_to('/error?code=Banned');

		}

		else {

			my $active_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));
			my $error = $self->param('error');

			$self->stash(active_user_info => $active_user_info, error => $error);

			$self->render(template => 'notifications');

			Minimojo::update('notifications', 'notification_status', 'read', 'user_id', Minimojo::get_info('id', 'users', 'user', $self->session('username')));

		}

	}

	else {

		$self->redirect_to('/login');

	}


} => 'notifications';

# --------------------------------------------------

get '/search' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		my $user_role = Minimojo::get_info('user_role', 'users', 'user', $self->session('username'));

		if (!$user_role) {

			$self->redirect_to('/error?code=02');

		}

		elsif (($user_role eq 'unemailed') or ($user_role eq 'unconfirmed')) {

			$self->redirect_to('/account/pending');

		}

		elsif ($user_role eq 'banned') {

			$self->redirect_to('/error?code=Banned');

		}

		else {

			my $active_user_info = Minimojo::get_all_info('*', 'users', 'user', $self->session('username'));
			my $query = $self->param('q');
				my $search = eval { $dbh->prepare('SELECT * FROM posts WHERE (post_body REGEXP \''.Minimojo::clean_comment($self->param('q')).'\' OR created_by_user REGEXP \''.Minimojo::clean_comment($self->param('q')).'\') ORDER BY id DESC') };
					$search->execute();
				my $search_response = $search->fetchall_arrayref();
			my $error = $self->param('error');

			$self->stash(active_user_info => $active_user_info, query => $query, search_response => $search_response, error => $error);

			$self->render(template => 'search');

		}

	}

	else {

		$self->redirect_to('/login');

	}	

} => 'search';

post '/search' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		my $user_role = Minimojo::get_info('user_role', 'users', 'user', $self->session('username'));

		if (!$user_role) {

			$self->redirect_to('/error?code=02');

		}

		elsif (($user_role eq 'unemailed') or ($user_role eq 'unconfirmed')) {

			$self->redirect_to('/account/pending');

		}

		elsif ($user_role eq 'banned') {

			$self->redirect_to('/error?code=Banned');

		}

		else {

			if (($self->param('q')) and ($self->param('q') ne '')) {

				$self->redirect_to('/search?q='.$self->param('q'));

			}

			else {

				$self->redirect_to('/');

			}

		}

	}

	else {

		$self->redirect_to('/login');

	}

} => 'search';

# --------------------------------------------------

any '/chat' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if ($self->session('session')) {

		my $user_role = Minimojo::get_info('user_role', 'users', 'user', $self->session('username'));

		if (!$user_role) {

			$self->redirect_to('/error?code=02');

		}

		elsif (($user_role eq 'unemailed') or ($user_role eq 'unconfirmed')) {

			$self->redirect_to('/account/pending');

		}

		elsif ($user_role eq 'banned') {

			$self->redirect_to('/error?code=Banned');

		}

		else {

			$self->render(template => 'chat');

		}

	}

	else {

		$self->redirect_to('/login');

	}	



} => 'chat';

websocket '/stream' => sub {

	my $self = shift;
	Mojo::IOLoop->stream($self->tx->connection)->timeout(1200);

	my $username = $self->session('username');
		$self->add_client($username);

	$self->on(message => sub {
		my ($self, $text) = @_;
			my $cleaned_text = Minimojo::clean_js($text);
		$self->send_to_all("$username: $cleaned_text");
	} );

	$self->on(finish => sub {
	  my $self = shift;
	  $self->remove_client($username);
	} );

};

# --------------------------------------------------

any '/logout' => sub {

  my $self = shift;

  if ($self->session('session')) {

    $self->session(expires => 1);
    $self->redirect_to('/');

  }

  else {

    $self->redirect_to('/');

  }

} => 'logout';

# --------------------------------------------------

get '/error' => sub {

	my $self = shift;
	my $dbh = DBI->connect('DBI:mysql:'.$db, $db_user, $db_pw);

	if (($self->param('code')) or ($self->param('code') ne '')) {

		$self->stash(code => $self->param('code'));
		$self->render(template => 'error');

	}

	else {

		$self->redirect_to('/');

	}

} => 'error';

# --------------------------------------------------

app->start;

# --------------------------------------------------

