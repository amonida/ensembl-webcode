# $Id$

package EnsEMBL::Web::ZMenu::Transcript::CCDS;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  
  $self->SUPER::content;
  
  my $object    = $self->object;
  my $stable_id = $object->stable_id;
  
  $self->caption($object->gene->stable_id);
  
  $self->add_entry({
    type     => 'CCDS',
    label    => $stable_id,
    link     => $self->hub->get_ExtURL_link($stable_id, 'CCDS', $stable_id),
    abs_url  => 1,
    position => 2,
  });
  
  $self->delete_entry_by_type($_) for ('Transcript', 'Protein', 'Gene type', 'Gene');
}

1;
