package MojoForum::Controller::Chats;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# This action will render a template
sub title ($c) {
	$c->on(message => sub ($c, $msg) {
    my $title = $c->ua->get($msg)->result->dom->at('title')->text;
    $c->send($title);
  });
}

1;
