package MojoForum;
use Mojo::Base 'Mojolicious', -signatures;
use Mojo::SQLite;
use MojoForum::Model::Posts;
use MojoForum::Controller::Posts;
use MojoForum::Model::Chats;
use MojoForum::Controller::Chats;
use MojoForum::Model::Users;
use MojoForum::Controller::Users;

# This method will run once at server start
sub startup ($self) {

  $self->plugin('Config');
  # Configure the application
  $self->secrets($self->config('secrets'));
  #$self->secrets($config->{secrets});
	
	# Model
  $self->helper(sqlite => sub { state $sql = Mojo::SQLite->new->from_filename(shift->config('sqlite')) });
  $self->helper(
    posts => sub { state $posts = MojoForum::Model::Posts->new(sqlite => shift->sqlite) });
  $self->helper(
    users => sub { state $users = MojoForum::Model::Users->new(sqlite => shift->sqlite) });
 
  # Migrate to latest version if necessary
  my $path = $self->home->child('migrations', 'mojo_forum.sql');

  $self->sqlite->auto_migrate(1)->migrations->name('blog')->from_file($path);
  $self->sqlite->auto_migrate(1)->migrations->name('chat')->from_file($path);
  $self->sqlite->auto_migrate(1)->migrations->name('users')->from_file($path);

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('Example#welcome');

	# /posts
	$r->get('/posts')->to('posts#index');
  $r->get('/posts/create')->to('posts#create')->name('create_post');
  $r->post('/posts')->to('posts#store')->name('store_post');
  $r->get('/posts/:id')->to('posts#show')->name('show_post');
  $r->get('/posts/:id/edit')->to('posts#edit')->name('edit_post');
  $r->put('/posts/:id')->to('posts#update')->name('update_post');

	# /chats
	$r->get('/chats')->to('chats#index');
	$r->websocket('/title')->to('chats#title');

	# /users
	$r->get('/users')->to('users#index');
  $r->get('/users/create')->to('users#create')->name('create_user');
  $r->post('/users')->to('users#store')->name('store_user');
  $r->get('/users/:id')->to('users#show')->name('show_user');
  $r->get('/users/:id/edit')->to('users#edit')->name('edit_user');
  $r->put('/users/:id')->to('users#update')->name('update_user');
}

1;
