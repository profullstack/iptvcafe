package MojoForum::Model::Users;
use Mojo::Base -base;
 
has 'sqlite';
 
sub add {
  my ($self, $user) = @_;
  return $self->sqlite->db->insert('users', $user)->last_insert_id;
}
 
sub all { shift->sqlite->db->select('users')->hashes->to_array }
 
sub find {
  my ($self, $id) = @_;
  return $self->sqlite->db->select('users', undef, {id => $id})->hash;
}
 
sub remove {
  my ($self, $id) = @_;
  $self->sqlite->db->delete('users', {id => $id});
}
 
sub save {
  my ($self, $id, $user) = @_;
  $self->sqlite->db->update('users', $user, {id => $id});
}
 
1;
