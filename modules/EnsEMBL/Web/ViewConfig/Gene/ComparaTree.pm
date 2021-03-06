=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ViewConfig::Gene::ComparaTree;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  # These data are read from the compara.species_set_tag table at startup time by the
  # ConfigPacker. We want to get the species_sets with a genetree_display tag only.
  # The other tags of interest are: name, genetree_fgcolour and genetree_bgcolour.
  # We also want to strip out 'genetree' from the tags.
  my $hash     = $self->species_defs->multi_hash->{'DATABASE_COMPARA'}{'SPECIES_SET'} || {};
  my $defaults = {
    collapsability => 'gene',
    clusterset_id  => 'default',
    colouring      => 'background',
    exons          => 'on',
    text_format    => 'msf',
    tree_format    => 'newick_mode',
    newick_mode    => 'full_web',
    nhx_mode       => 'full',
    super_tree     => 'off',
    scale          => 150,
  };
  
  foreach my $name (keys %$hash) {
    while (my ($key, $value) = each %{$hash->{$name}}) {
      $key   =~ s/^genetree_//;
      $value = join '_', @$value if ref $value eq 'ARRAY';
      $defaults->{"group_${name}_$key"} = $value;
    }
  }
  
  $self->set_defaults($defaults);
  $self->add_image_config('genetreeview', 'nodas');
  $self->code  = join '::', grep $_, 'Gene::ComparaTree', $self->hub->referer->{'ENSEMBL_FUNCTION'};
  $self->title = 'Gene Tree';
}

sub form {
  my $self = shift;
  
  my %other_clustersets;
  if ($self->hub->core_objects->{'gene'}) {
    my $tree = $self->hub->core_objects->{'gene'}->get_GeneTree;
    my $adaptor = $self->hub->database('compara')->get_adaptor('GeneTree');
    %other_clustersets = map {$_->clusterset_id => 1} @{$adaptor->fetch_all_linked_trees($tree->tree)};
    $other_clustersets{$tree->tree->clusterset_id} = 1;
    delete $other_clustersets{default};
  }

  # The groups are defined in the compara.ncbi_taxa_* tables
  # They are sorted by size first and then by name.
  my $hash     = $self->species_defs->multi_hash->{'DATABASE_COMPARA'}{'SPECIES_SET'} || {};
  my @groups   = sort { @{$hash->{$b}->{'genome_db_ids'}} <=> @{$hash->{$a}->{'genome_db_ids'}} || $a cmp $b } keys %$hash;
  my $function = $self->hub->referer->{'ENSEMBL_FUNCTION'};
  
  if ($function eq 'Align' or $function eq 'Align_pan_compara') {
    my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
    
    $self->add_fieldset('Aligment output');
    
    $self->add_form_element({
      type   => 'DropDown', 
      select => 'select',
      name   => 'text_format',
      label  => 'Output format for sequence alignment',
      values => [ map {{ value => $_, caption => $formats{$_} }} sort keys %formats ]
    });
  } elsif ($function eq 'Text' or $function eq 'Text_pan_compara') {
    my %formats = EnsEMBL::Web::Constants::TREE_FORMATS;
    
    $self->add_fieldset('Text tree output');
    
    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'tree_format',
      label  => 'Output format for tree',
      values => [ map {{ value => $_, caption => $formats{$_}{'caption'} }} sort keys %formats ]
    });

    $self->add_form_element({
      type     => 'PosInt',
      required => 'yes',
      name     => 'scale',
      label    => 'Scale size for Tree text dump'
    });

    %formats = EnsEMBL::Web::Constants::NEWICK_OPTIONS;
    
    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'newick_mode',
      label  => 'Mode for Newick tree dumping',
      values => [ map {{ value => $_, caption => $formats{$_} }} sort keys %formats ]
    });

    %formats = EnsEMBL::Web::Constants::NHX_OPTIONS;
    
    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'nhx_mode',
      label  => 'Mode for NHX tree dumping',
      values => [ map {{ value => $_, caption => $formats{$_} }} sort keys %formats ]
    });
  } else {
    $self->add_fieldset('Display options');

    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'collapsability',
      label  => 'Viewing options for tree image',
      values => [ 
        { value => 'gene',         caption => 'View current gene only' },
        { value => 'paralogs',     caption => 'View paralogs of current gene' },
        { value => 'duplications', caption => 'View all duplication nodes' },
        { value => 'all',          caption => 'View fully expanded tree' }
      ]
    });

    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'clusterset_id',
      label  => 'Model used for the tree reconstruction',
      values => [
        { value => 'default', caption => 'Final (merged) tree' },
        map {{ value => $_, caption => $_ }} sort keys %other_clustersets,
      ]
    });

    $self->add_form_element({
      'type'  => 'CheckBox',
      'label' => 'Display exon boundaries',
      'name'  => 'exons',
      'value' => 'on',
      'raw'   => 1,
    });

    $self->add_form_element({
      'type'  => 'CheckBox',
      'label' => 'Display super-tree',
      'name'  => 'super_tree',
      'value' => 'on',
    });

    if (@groups) {
      $self->add_form_element({
        type   => 'DropDown', 
        select => 'select',
        name   => 'colouring',
        label  => 'Colour tree according to taxonomy',
        values => [ 
          { value => 'none',       caption => 'No colouring' },
          { value => 'background', caption => 'Background' },
          { value => 'foreground', caption => 'Foreground' } 
        ]
      });
    }

    foreach my $group (@groups) {
      $self->add_form_element({
        type   => 'DropDown', 
        select => 'select',
        name   => "group_${group}_display",
        label  => "Display options for $group",
        values => [ 
          { value => 'default',  caption => 'Default behaviour' },
          { value => 'hide',     caption => 'Hide genes' },
          { value => 'collapse', caption => 'Collapse genes' } 
        ]
      });
    }
  }  
}

1;
