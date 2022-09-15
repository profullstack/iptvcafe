package MojoForum::Model::Chats;
use Mojo::Base -base;
 
has 'sqlite';
 
sub add {
  my ($self, $post) = @_;
  return $self->sqlite->db->insert('chats', $post)->last_insert_id;
}
 
sub all { shift->sqlite->db->select('chats')->hashes->to_array }
 
sub find {
  my ($self, $id) = @_;
  return $self->sqlite->db->select('chats', undef, {id => $id})->hash;
}
 
sub remove {
  my ($self, $id) = @_;
  $self->sqlite->db->delete('chats', {id => $id});
}
 
sub save {
  my ($self, $id, $post) = @_;
  $self->sqlite->db->update('chats', $post, {id => $id});
}
 
1;
