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

package EnsEMBL::Web::ViewConfig::Compara_Alignments;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  my $alignments   = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'} || {};
  my %defaults;
  
  foreach my $key (grep { $alignments->{$_}{'class'} !~ /pairwise/ } keys %$alignments) {
    foreach (keys %{$alignments->{$key}{'species'}}) {
      my @name = split '_', $alignments->{$key}{'name'};
      my $n    = shift @name;
      $defaults{lc "species_${key}_$_"} = [ join(' ', $n, map(lc, @name), '-', $species_defs->get_config($_, 'SPECIES_COMMON_NAME') || 'Ancestral sequences'), /ancestral/ ? 'off' : 'yes' ];
    }
  }
  
  $self->SUPER::init;
  
  $self->set_defaults({
    flank5_display        => 600,
    flank3_display        => 600,
    exon_display          => 'core',
    exon_ori              => 'all',
    snp_display           => 'off',
    line_numbering        => 'off',
    display_width         => 120,
    conservation_display  => 'off',
    region_change_display => 'off',
    codons_display        => 'off',
    %defaults
  });
  
  $self->code  = $self->type . '::Compara_Alignments';
  $self->title = 'Alignments';
}

sub form {
  my $self = shift;
  my $dbs  = $self->species_defs->databases;
  
  if (!$self->{'species_only'}) {
    my %gene_markup_options    = EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;    # options shared with marked-up sequence
    my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS; # options shared with resequencing and marked-up sequence
    my %other_markup_options   = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;   # options shared with resequencing
    
    push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'vega',          caption => 'Vega exons'     } if $dbs->{'DATABASE_VEGA'};
    push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'otherfeatures', caption => 'EST gene exons' } if $dbs->{'DATABASE_OTHERFEATURES'};
    
    if (!$self->{'no_flanking'}) {
      $self->add_form_element($gene_markup_options{'flank5_display'});
      $self->add_form_element($gene_markup_options{'flank3_display'});
    }
    
    $self->add_form_element($other_markup_options{'display_width'});
    $self->add_form_element($other_markup_options{'strand'}) if $self->{'strand_option'};
    $self->add_form_element($gene_markup_options{'exon_display'});
    $self->add_form_element($general_markup_options{'exon_ori'});
    $self->variation_options if $dbs->{'DATABASE_VARIATION'};
    $self->add_form_element($general_markup_options{'line_numbering'});
    $self->add_form_element($other_markup_options{'codons_display'});

    $self->add_form_element({
      name     => 'conservation_display',
      label    => 'Conservation regions',
      type     => 'DropDown',
      select   => 'select',
      values   => [{
        value   => 'all',
        caption => 'All conserved regions'
      }, {
        value   => 'off',
        caption => 'None'
      }]
    });
    $self->add_form_element({
      name   => 'region_change_display',
      label  => 'Mark alignment start/end',
      type   => 'DropDown',
      select => 'select',
      values => [{
        value   => 'yes',
        caption => 'Yes'
      }, {
        value   => 'off',
        caption => 'No'
      }]
    });
    
    $self->add_form_element($other_markup_options{'title_display'});
  }
  
  $self->alignment_options; 
}

sub alignment_options {
  my $self         = shift;
  my $species      = $self->hub->referer->{'ENSEMBL_SPECIES'};
  my $species_defs = $self->species_defs;
  my $alignments   = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'} || {};
  
  # Order by number of species (name is in the form "6 primates EPO"
  foreach my $row (sort { $a->{'name'} <=> $b->{'name'} } grep { $_->{'class'} !~ /pairwise/ && $_->{'species'}->{$species} } values %$alignments) {
    my $sp   = $row->{'species'};
    my @name = split '_', $row->{'name'};
    my $n    = shift @name;
    
    $sp->{$_} = $species_defs->species_label($_) for keys %$sp;
    
    $self->add_fieldset(join ' ', $n, map lc, @name);
    
    foreach (sort { ($sp->{$a} =~ /^<.*?>(.+)/ ? $1 : $sp->{$a}) cmp ($sp->{$b} =~ /^<.*?>(.+)/ ? $1 : $sp->{$b}) } keys %$sp) {
      $self->add_form_element({
        type  => 'CheckBox', 
        label => $sp->{$_},
        name  => sprintf('species_%s_%s', $row->{'id'}, lc),
        value => 'yes',
        raw   => 1
      });
    }
  }
}

1;
