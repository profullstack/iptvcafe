package MojoForum::Controller::Users;
use Mojo::Base 'Mojolicious::Controller';
 
sub create {
	my $self = shift;

	$self->render(user => {},
		error    => $self->flash('error'),
		message  => $self->flash('message')
	)
}
 
sub edit {
  my $self = shift;
  $self->render(user => $self->users->find($self->param('id')),
		error    => $self->flash('error'),
		message  => $self->flash('message')
	)
}
 
sub index {
  my $self = shift;
  $self->render(users => $self->users->all);
}
 
sub remove {
  my $self = shift;
  $self->users->remove($self->param('id'));
  $self->redirect_to('users');
}
 
sub show {
  my $self = shift;
  $self->render(user => $self->users->find($self->param('id')));
}
 
sub store {
  my $self = shift;
 
  my $validation = $self->_validation;
  return $self->render(action => 'create', user => {},
		error    => $self->flash('error'),
		message  => $self->flash('message')
	)
    if $validation->has_error;
 
  my $id = $self->users->add($validation->output);
  $self->redirect_to('show_user', id => $id);
}
 
sub update {
  my $self = shift;
 
  my $validation = $self->_validation;
  return $self->render(action => 'edit', user => {},
		error    => $self->flash('error'),
		message  => $self->flash('message')
) if $validation->has_error;
 
  my $id = $self->param('id');
  $self->users->save($id, $validation->output);
  $self->redirect_to('show_user', id => $id);
}
 
sub _validation {
  my $self = shift;
 
  my $validation = $self->validation;
  $validation->required('email', 'not_empty');
  $validation->required('username',  'not_empty');
  $validation->required('password',  'not_empty');
  $validation->required('repeat_password',  'not_empty');
 
  return $validation;
}
 
1;
