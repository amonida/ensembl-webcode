# $Id$

package EnsEMBL::Web::ImageConfig::MultiTop;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::MultiSpecies);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title             => 'Top panel',
    sortable_tracks   => 1,     # allow the user to reorder tracks
    show_labels       => 'yes', # show track names on left-hand side
    label_width       => 113,   # width of labels on left-hand side
    opt_empty_tracks  => 0,     # include empty tracks
    opt_lines         => 1,     # draw registry lines
    opt_restrict_zoom => 1,     # when we get "zoom" working draw restriction enzyme info on it
    global_options    => 1   
  });

  $self->create_menus(
    options     => 'Comparative features',
    sequence    => 'Sequence',
    marker      => 'Markers',
    transcript  => 'Genes',
    synteny     => 'Synteny',
    decorations => 'Additional features',
    information => 'Information'
  );
  
  $self->add_options( 
    [ 'opt_join_genes', 'Join genes', undef, undef, 'off' ]
  );
  
  if ($self->species_defs->valid_species($self->species)) {
    $self->get_node('opt_join_genes')->set('menu', 'no');
    
    $self->add_track('sequence',    'contig', 'Contigs',     'stranded_contig', { display => 'normal', strand => 'f' });
    $self->add_track('information', 'info',   'Information', 'text',            { display => 'normal' });
    
    $self->load_tracks;

    $self->add_tracks('decorations',
      [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', menu => 'no' }],
      [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'f', menu => 'no' }],
      [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
    );
    
    $self->modify_configs(
      [ 'transcript' ],
      { qw(render gene_label strand r) }
    );
  } else {
    $self->set_parameters({
      active_menu => 'options',
      extra_menus => 'no'
    });
  }
}

sub join_genes {
  my ($self, $prev_species, $next_species) = @_;
  
  foreach ($self->get_node('transcript')->nodes) {
    $_->set('previous_species', $prev_species) if $prev_species;
    $_->set('next_species', $next_species) if $next_species;
    $_->set('join', 1);
  }
}

sub highlight {
  my ($self, $gene) = @_;
  $_->set('g', $gene) for $self->get_node('transcript')->nodes; 
}

1;
