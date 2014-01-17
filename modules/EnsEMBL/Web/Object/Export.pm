# $Id$

package EnsEMBL::Web::Object::Export;

### NAME: EnsEMBL::Web::Object::Export
### Wrapper around a dynamically generated Bio::EnsEMBL data object  

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk

### DESCRIPTION
### An 'empty' wrapper object with on-the-fly creation of 
### data objects that are to be exported

use strict;

use Data::Dumper;
use Bio::AlignIO;
use IO::String;

use EnsEMBL::Web::Component::Compara_Alignments;
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::SeqDumper;
use Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter;
use Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter;

use base qw(EnsEMBL::Web::Object);

sub caption                { return 'Export Data';                                                      }
sub get_location_object    { return $_[0]->{'_location'} ||= $_[0]->hub->core_objects->{'location'};    }
sub get_all_transcripts    { return $_[0]->hub->core_objects->{'gene'}->Obj->get_all_Transcripts || []; }
sub check_slice            { return shift->get_location_object->check_slice(@_);                        }
sub get_ld_values          { return shift->get_location_object->get_ld_values(@_);                      }
sub get_pop_name           { return shift->get_location_object->pop_name_from_id(@_);                   }
sub get_samples            { return shift->get_object->get_samples(@_);                                 }
sub get_genetic_variations { return shift->get_object->get_genetic_variations(@_);                      }
sub stable_id              { return shift->get_object->stable_id;                                       }
sub availability           { return shift->get_object->availability;                                    }

sub slice {
  my $self     = shift;
  my $location = $self->get_location_object;
  my $hub = $self->hub;
  my $lrg = $hub->param('lrg');
  my $lrg_slice;
  
  if ($location) {
     my ($flank5, $flank3) = map $self->param($_), qw(flank5_display flank3_display);
     my $slice = $location->slice;     
     $slice = $slice->invert if ($hub->param('strand') eq '-1');

     return $flank5 || $flank3 ? $slice->expand($flank5, $flank3) : $slice; 
   }
   
  if ($lrg) {
    eval { $lrg_slice = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
  }  
  return $lrg_slice;
}

sub config {
  my $self = shift;
  
  $self->__data->{'config'} = {
    fasta => {
      label => 'FASTA sequence',
      formats => [
        [ 'fasta', 'FASTA sequence' ]
      ],
      params => [
        [ 'cdna',    'cDNA' ],
        [ 'coding',  'Coding sequence' ],
        [ 'peptide', 'Peptide sequence' ],
        [ 'utr5',    "5' UTR" ],
        [ 'utr3',    "3' UTR" ],
        [ 'exon',    'Exons' ],
        [ 'intron',  'Introns' ]
      ]
    },
    features => {
      label => 'Feature File',
      formats => [
        [ 'csv',  'CSV (Comma separated values)' ],
        [ 'tab',  'Tab separated values' ],
        [ 'gtf',  'Gene Transfer Format (GTF)' ],
        [ 'gff',  'Generic Feature Format' ],
        [ 'gff3', 'Generic Feature Format Version 3' ],
      ],
      params => [
        [ 'similarity', 'Similarity features' ],
        [ 'repeat',     'Repeat features' ],
        [ 'genscan',    'Prediction features (genscan)' ],
        [ 'variation',  'Variation features' ],
        [ 'probe',      'Probe features' ],
        [ 'gene',       'Gene information' ],
        [ 'transcript', 'Transcripts' ],
        [ 'exon',       'Exons' ],
        [ 'intron',     'Introns' ],
        [ 'cds',        'Coding sequences' ]
      ]
    },
    bed => {
      label => 'Bed Format',
      formats => [
        [ 'bed',  'BED Format' ],
      ],
      params => [
        [ 'variation',  'Variation features' ],
        [ 'probe',      'Probe features' ],
        [ 'gene',       'Gene information' ],
        [ 'repeat',     'Repeat features' ],
        [ 'similarity', 'Similarity features' ],
        [ 'genscan',    'Prediction features (genscan)' ],
        [ 'userdata',  'Uploaded Data' ],
      ]
    },
#     PSL => {
#       label => 'PSL Format',
#       formats => [
#         [ 'PSL',  'PSL Format' ],
#       ],
#       params => [
#           [ 'name',  'Bed Line Name' ],
#         ]
#     },
    flat => {
      label => 'Flat File',
      formats => [
        [ 'embl',    'EMBL' ],
        [ 'genbank', 'GenBank' ]
      ],
      params => [
        [ 'similarity', 'Similarity features' ],
        [ 'repeat',     'Repeat features' ],
        [ 'genscan',    'Prediction features (genscan)' ],
        [ 'contig',     'Contig Information' ],
        [ 'variation',  'Variation features' ],
        [ 'marker',     'Marker features' ],
        [ 'gene',       'Gene Information' ],
        [ 'vegagene',   'Vega Gene Information' ],
        [ 'estgene',    'EST Gene Information' ]
      ]
    },
    pip => {
      label => 'PIP (%age identity plot)',
      formats => [
        [ 'pipmaker', 'Pipmaker / zPicture format' ],
        [ 'vista',    'Vista Format' ]
      ]
    },
    genetree => {
      label => 'Gene Tree',
      formats => [
        [ 'phyloxml',    'PhyloXML from Compara' ],
        [ 'phylopan',    'PhyloXML from Pan-taxonomic Compara' ]
      ],
      params => [
        [ 'cdna', 'cDNA rather than protein sequence' ],
        [ 'aligned', 'Aligned sequences with gaps' ],
        [ 'no_sequences', 'Omit sequences' ],
      ]
    },
    homologies => {
      label => 'Homologies',
      formats => [
        [ 'orthoxml',    'OrthoXML from Compara' ],
        [ 'orthopan',    'OrthoXML from Pan-taxonomic Compara' ]
      ],
      params => [
        [ 'possible_orthologs', 'Treat not supported duplications as speciations (makes a non species-tree-compliant tree)' ],
      ]
    }  
  };

if(! $self->get_object->can('get_GeneTree') ){
	delete $self->__data->{'config'}{'genetree'};
	delete $self->__data->{'config'}{'homologies'};
}
  
  my $func = sprintf 'modify_%s_options', lc $self->function;
  $self->$func if $self->can($func);
  
  return $self->__data->{'config'};
}

sub modify_location_options {
  my $self = shift;
  
  my $misc_sets = $self->species_defs->databases->{'DATABASE_CORE'}->{'tables'}->{'misc_feature'}->{'sets'} || {};
  my @misc_set_params = map [ "miscset_$_", $misc_sets->{$_}->{'name'} ], keys %$misc_sets;
  
  $self->__data->{'config'}->{'fasta'}->{'params'} = [];
  push @{$self->__data->{'config'}->{'features'}->{'params'}}, @misc_set_params;
  
}

sub modify_gene_options {
  my $self = shift;
  
  my $options = { translation => 0, three => 0, five => 0 };
  
  foreach (@{$self->get_all_transcripts}) {
    $options->{'translation'} = 1 if $_->translation;
    $options->{'three'}       = 1 if $_->three_prime_utr;
    $options->{'five'}        = 1 if $_->five_prime_utr;
    
    last if $options->{'translation'} && $options->{'three'} && $options->{'five'};
  }
  
  $self->__data->{'config'}->{'fasta'}->{'params'} = [
    [ 'cdna',    'cDNA'                                        ],
    [ 'coding',  'Coding sequence',  $options->{'translation'} ],
    [ 'peptide', 'Peptide sequence', $options->{'translation'} ],
    [ 'utr5',    "5' UTR",           $options->{'five'}        ],
    [ 'utr3',    "3' UTR",           $options->{'three'}       ],
    [ 'exon',    'Exons'                                       ],
    [ 'intron',  'Introns'                                     ]
  ];
}

sub params :lvalue {$_[0]->{'params'};  }
sub string { return shift->output('string', @_); }
sub html   { return shift->output('html',   @_); }
sub image_width { return $ENV{'ENSEMBL_IMAGE_WIDTH'}; }
sub _warning { return shift->_info_panel('warning', @_ ); } # Error message, but not fatal

sub html_format {
  my $self = shift;
  return $self->{'html_format'} = 'HTML';
}

sub _info_panel {
  my ($self, $class, $caption, $desc, $width, $id) = @_;
  
  return $self->html_format ? sprintf(
    '<div%s style="width:%s" class="%s"><h3>%s</h3><div class="error-pad">%s</div></div>',
    $id ? qq{ id="$id"} : '',
    $width || $self->image_width . 'px', 
    $class, 
    $caption, 
    $desc
  ) : '';
}

sub output {
  my ($self, $key, $string) = @_;
  $self->{$key} .= "$string\r\n" if defined $string;
  return $self->{$key};
}

#function to get location, gene, transcript or LRG object for the export data.
sub get_object {
  my $self  = shift;
  my $hub   = $self->hub;
  
  if($hub->function eq 'Transcript') {
    return $self->hub->core_objects->{'transcript'} ;
  }elsif ($hub->function eq 'Gene') {
    return $self->hub->core_objects->{'gene'};
  }elsif ($hub->function eq 'LRG') {
    return $self->hub->core_objects->{'lrg'};
  }elsif ($hub->function eq 'Variation') {
    return $self->hub->core_objects->{'variation'};
  }else {
    return $self->hub->core_objects->{'location'};
  }
}

sub process {  
  my $self           = shift;
  my $custom_outputs = shift || {};

  my $hub            = $self->hub;  
  my $o              = $hub->param('output');
  my $strand         = $hub->param('strand');

  my $object         = $self->get_object;   
  my @inputs         = ($hub->function eq 'Gene' || $hub->function eq 'LRG') ? $object->get_all_transcripts : @_;  
  @inputs            = [$object] if($hub->function eq 'Transcript');  

  my $slice          = $object->slice('expand');
  $slice             = $self->slice if($slice == 1);
   
  my $feature_strand = $slice->strand;
  $strand            = undef unless $strand == 1 || $strand == -1; # Feature strand will be correct automatically  
  $slice             = $slice->invert if $strand && $strand != $feature_strand;
  my $params         = { feature_strand => $feature_strand };
  my $html_format    = $self->html_format;

  if ($slice->length > 5000000) {
    my $error = 'The region selected is too large to export. Please select a region of less than 5Mb.';
    
    $self->string($html_format ? $self->_warning('Region too large', "<p>$error</p>") : $error);    
  } else {
    my $outputs = {
      fasta     => sub { return $self->fasta(@inputs);  },
      csv       => sub { return $self->features('csv'); },
      tab       => sub { return $self->features('tab'); },
      bed       => sub { return $self->bed;    },
      gtf       => sub { return $self->features('gtf'); },
      psl       => sub { return $self->psl_features;    },
      gff       => sub { return $self->features('gff'); },
      gff3      => sub { return $self->gff3_features;   },
      embl      => sub { return $self->flat('embl');    },
      genbank   => sub { return $self->flat('genbank'); },
      alignment => sub { return $self->alignment;       },
      phyloxml  => sub { return $self->phyloxml('compara');},
      phylopan  => sub { return $self->phyloxml('compara_pan_ensembl');},
      orthoxml  => sub { return $self->orthoxml('compara');},
      orthopan  => sub { return $self->orthoxml('compara_pan_ensembl');},
      %$custom_outputs
    };

    if ($outputs->{$o}) {      
      map { $params->{$_} = 1 if $_ } $hub->param('param');
      map { $params->{'misc_set'}->{$_} = 1 if $_ } $hub->param('misc_set'); 
      $self->params = $params;      
      $outputs->{$o}();
    }
  }
  
  my $string = $self->string;
  my $html   = $self->html; # contains html tags
  
  if ($html_format) {
    $string = "<pre>$string</pre>" if $string;
  } else {    
    if($o ne "phyloxml" && $o ne "phylopan" && $o ne "orthoxml" && $o ne "orthopan"){
      s/<.*?>//g for $string, $html; # Strip html tags;
    }
    $string .= "\r\n" if $string && $html;
  }
  
  return ($string . $html) || 'No data available';
}

sub phyloxml{
  my ($self,$cdb) = @_;
  my $params = $self->params;
  my $handle          = IO::String->new();
  my $w = Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter->new(
          -SOURCE => $cdb eq 'compara' ? $SiteDefs::ENSEMBL_SITETYPE:'Ensembl Genomes',
          -ALIGNED => $params->{'aligned'},
          -CDNA => $params->{'cdna'},
          -NO_SEQUENCES => $params->{'no_sequences'},
          -HANDLE => $handle
  ); 
  $self->writexml($cdb, $handle, $w);
}
sub orthoxml{
  my ($self,$cdb) = @_;
  my $params = $self->params;
  my $handle          = IO::String->new();
  my $w = Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter->new(
          -SOURCE => $cdb eq 'compara' ? $SiteDefs::ENSEMBL_SITETYPE:'Ensembl Genomes',
	    -SOURCE_VERSION => $SiteDefs::SITE_RELEASE_VERSION, 
          -HANDLE => $handle,
          -POSSIBLE_ORTHOLOGS => $params->{'possible_orthologs'},
  ); 
  $self->writexml($cdb, $handle, $w);
}
sub writexml{
  my ($self,$cdb,$handle,$w) = @_;
  my $hub             = $self->hub;
  my $object          = $self->get_object;
  if(! $object->can('get_GeneTree')){return $self->string('no data');}
  my $tree = $object->get_GeneTree($cdb);
  $w->write_trees($tree);
  $w->finish();
  my $out = ${$handle->string_ref()};
  do{
     $out =~ s/</&lt\;/g;
     $out =~ s/>/&gt\;/g;
  }unless $hub->param('_format') eq 'TextGz';
  $self->string($out);
}
sub fasta {
  my ($self, $trans_objects) = @_;

  my $hub             = $self->hub;
  my $object          = $self->get_object;
  my $object_id       = ($hub->function eq 'Gene' || $hub->function eq 'LRG') ? $object->stable_id : '';
  my $slice           = $object->slice('expand');
  $slice              = $self->slice if($slice == 1);
  my $strand          = $hub->param('strand');
  if(($strand ne 1) && ($strand ne -1)) {$strand = $slice->strand;}
  if($strand != $slice->strand){ $slice=$slice->invert; }
  my $params          = $self->params;
  my $genomic         = $hub->param('genomic');
  my $seq_region_name = $object->seq_region_name;
  my $seq_region_type = $object->seq_region_type;
  my $slice_name      = $slice->name;
  my $slice_length    = $slice->length;
  my $fasta;
  if (scalar keys %$params) {
    my $intron_id;
    
    my $output = {
      cdna    => sub { my ($t, $id, $type) = @_; [[ "$id cdna:$type", $t->spliced_seq ]] },
      coding  => sub { my ($t, $id, $type) = @_; [[ "$id cds:$type", $t->translateable_seq ]] },
      peptide => sub { my ($t, $id, $type) = @_; eval { [[ "$id peptide: " . $t->translation->stable_id . " pep:$type", $t->translate->seq ]] }},
      utr3    => sub { my ($t, $id, $type) = @_; eval { [[ "$id utr3:$type", $t->three_prime_utr->seq ]] }},
      utr5    => sub { my ($t, $id, $type) = @_; eval { [[ "$id utr5:$type", $t->five_prime_utr->seq ]] }},
      exon    => sub { my ($t, $id, $type) = @_; eval { [ map {[ "$id " . $_->id . " exon:$type", $_->seq->seq ]} @{$t->get_all_Exons} ] }},
      intron  => sub { my ($t, $id, $type) = @_; eval { [ map {[ "$id intron " . $intron_id++ . ":$type", $_->seq ]} @{$t->get_all_Introns} ] }}
    };
    
    foreach (@$trans_objects) {
      my $transcript = $_->Obj;
      my $id         = ($object_id ? "$object_id:" : '') . $transcript->stable_id;
      my $type       = $transcript->isa('Bio::EnsEMBL::PredictionTranscript') ? $transcript->analysis->logic_name : $transcript->status . '_' . $transcript->biotype;
      
      $intron_id = 1;
      
      foreach (sort keys %$params) {      
        my $o = $output->{$_}($transcript, $id, $type) if exists $output->{$_};
        
        next unless ref $o eq 'ARRAY';
        
        foreach (@$o) {
          $self->string(">$_->[0]");
          $self->string($fasta) while $fasta = substr $_->[1], 0, 60, '';
        }
      }
      
      $self->string('');
    }
  }

  if (defined $genomic && $genomic ne 'off') {
    my $masking = $genomic eq 'soft_masked' ? 1 : $genomic eq 'hard_masked' ? 0 : undef;
    my ($seq, $start, $end, $flank_slice);

    if ($genomic =~ /flanking/) {      
      for (5, 3) {
        if ($genomic =~ /$_/) {
          if ($strand == $params->{'feature_strand'}) {
            ($start, $end) = $_ == 3 ? ($slice_length - $hub->param('flank3_display') + 1, $slice_length) : (1, $hub->param('flank5_display'));
          } else {
            ($start, $end) = $_ == 5 ? ($slice_length - $hub->param('flank5_display') + 1, $slice_length) : (1, $hub->param('flank3_display'));
          }
          
          $flank_slice = $slice->sub_Slice($start, $end);
          
          if ($flank_slice) {
            $seq  = $flank_slice->seq;
            
            $self->string(">$_' Flanking sequence " . $flank_slice->name);
            $self->string($fasta) while $fasta = substr $seq, 0, 60, '';
          }
        }
      }
    } else {
      $seq = defined $masking ? $slice->get_repeatmasked_seq(undef, $masking)->seq : $slice->seq;
      
      $self->string(">$seq_region_name dna:$seq_region_type $slice_name");
      $self->string($fasta) while $fasta = substr $seq, 0, 60, '';
    }
  }

}

sub flat {
  my $self          = shift;
  my $format        = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $slice         = $self->slice;
  my $params        = $self->params;
  my $plist         = $species_defs->PROVIDER_NAME;
  my $vega_db       = $hub->database('vega');
  my $estgene_db    = $hub->database('otherfeatures');
  my $dumper_params = {};
  
  # Check where the data came from.
  if ($plist) {
    my $purls         = $species_defs->PROVIDER_URL;
    my @providers     = ref $plist eq 'ARRAY' ? @$plist : ($plist);
    my @providers_url = ref $purls eq 'ARRAY' ? @$purls : ($purls);
    my @list;

    foreach my $ds (@providers) {
      my $purl = shift @providers_url;
      
      $ds .= " ( $purl )" if $purl;
      
      push @list, $ds;
    }
    
    $dumper_params->{'_data_source'} = join ', ' , @list;
  }

  my $seq_dumper = new EnsEMBL::Web::SeqDumper(undef, $dumper_params);

  foreach (qw( genscan similarity gene repeat variation contig marker )) {
    $seq_dumper->disable_feature_type($_) unless $params->{$_};
  }

  if ($params->{'vegagene'} && $vega_db) {
    $seq_dumper->enable_feature_type('vegagene');
    $seq_dumper->attach_database('vega', $vega_db);
  }
  
  if ($params->{'estgene'} && $estgene_db) {
    $seq_dumper->enable_feature_type('estgene');
    $seq_dumper->attach_database('estgene', $estgene_db);
  }
  
  $self->string($seq_dumper->dump($slice, $format));
}

sub alignment {
  my $self = shift;
  my $hub  = $self->hub;
  
  # Nasty hack to link export to the view config for alignments. Eww.
  $hub->get_viewconfig('Compara_Alignments', $hub->type, 'cache');
  
  $self->{'alignments_function'} = 'get_SimpleAlign';
  
  my $alignments = EnsEMBL::Web::Component::Compara_Alignments::get_alignments($self, $self->slice, $hub->param('align'), $hub->species);
  my $export;

  my $align_io = Bio::AlignIO->newFh(
    -fh     => new IO::String($export),
    -format => $hub->param('format')
  );

  print $align_io $alignments;
  
  $self->string($export);
}

sub features {
  my $self          = shift;
  my $format        = shift;
  my $slice         = $self->slice;
  my $params        = $self->params;
  my @common_fields = qw(seqname source feature start end score strand frame);
  my @extra_fields  = $format eq 'gtf' ? qw(gene_id transcript_id) : qw(hid hstart hend genscan gene_id transcript_id exon_id gene_type variation_name probe_name);  
  my $availability  = $self->availability;
  
  $self->{'config'} = {
    extra_fields  => \@extra_fields,
    format        => $format,
    delim         => $format eq 'csv' ? ',' : "\t"
  };
  
  if($format ne 'bed'){$self->string(join $self->{'config'}->{'delim'}, @common_fields, @extra_fields) unless $format eq 'gff';}
  
  if ($params->{'similarity'}) {
    foreach (@{$slice->get_all_SimilarityFeatures}) {
      $self->feature('similarity', $_, { 
        hid    => $_->hseqname, 
        hstart => $_->hstart, 
        hend   => $_->hend 
      });
    }
  }
  
  if ($params->{'repeat'}) {
    foreach (@{$slice->get_all_RepeatFeatures}) {
      $self->feature('repeat', $_, { 
        hid    => $_->repeat_consensus->name, 
        hstart => $_->hstart, 
        hend   => $_->hend 
      });
    }
  }
  
  if ($params->{'genscan'}) {
    foreach my $t (@{$slice->get_all_PredictionTranscripts}) {
      foreach my $e (@{$t->get_all_Exons}) {
        $self->feature('pred.trans.', $e, { genscan => $t->stable_id });
      }
    }
  }
  
  if ($params->{'variation'}) {
    foreach (@{$slice->get_all_VariationFeatures}) {
      $self->feature('variation', $_, { variation_name => $_->variation_name });	    
    }
  }

  if($params->{'probe'} && $availability->{'database:funcgen'}) {
    my $fg_db = $self->database('funcgen'); 
    my $probe_feature_adaptor = $fg_db->get_ProbeFeatureAdaptor;     
    my @probe_features = @{$probe_feature_adaptor->fetch_all_by_Slice($slice)};
    
    foreach my $pf(@probe_features){
      my $probe_details = $pf->probe->get_all_complete_names();
      my @probes = split(/:/,@$probe_details[0]);
      $self->feature('ProbeFeature', $pf, { probe_name => @probes[1] },{ source => @probes[0]});
    }
  }
  
  if ($params->{'gene'}) {
    my $species_defs = $self->hub->species_defs;
    
    my @dbs = ('core');
    push @dbs, 'vega'          if $species_defs->databases->{'DATABASE_VEGA'};
    push @dbs, 'otherfeatures' if $species_defs->databases->{'DATABASE_OTHERFEATURES'};
    
    foreach my $db (@dbs) {
      foreach my $g (@{$slice->get_all_Genes(undef, $db)}) {
        foreach my $t (@{$g->get_all_Transcripts}) {
          foreach my $e (@{$t->get_all_Exons}) {            
            $self->feature('gene', $e, { 
               exon_id       => $e->stable_id, 
               transcript_id => $t->stable_id, 
               gene_id       => $g->stable_id, 
               gene_type     => $g->status . '_' . $g->biotype
            }, { source => $db eq 'vega' ? 'Vega' : 'Ensembl' });
          }
        }
      }
    }
  }
 
  $self->misc_sets(keys %{$params->{'misc_set'}}) if $params->{'misc_set'};
}

sub bed {
  my $self   = shift;
  my $hub    = $self->hub;
  
  my $object = $self->get_object;  
  my $slice  = $object->slice('expand');
  $slice     = $self->slice if($slice == 1);
  
  my $params = $self->params;
  my ($output,$title);

  $self->{'config'} = {   
    format => 'bed',
    delim  => "\t"
  };
  
  my $config = $self->{'config'}; 
  my (%vals, @column, $trackname);

  my $types_to_print = {};
  foreach my $bed_option (@{ $self->config->{'bed'}->{'params'}}){
    my ($bed_option_key,$bed_option_desc) = @$bed_option;
    next unless $params->{$bed_option_key};
    $types_to_print->{$bed_option_key} = $bed_option_desc;
    $params->{$bed_option_key} = 0;
  }
  foreach my $type(keys %$types_to_print){
    $params->{$type} = 1;
    my $backup = $self->{'string'};
    $self->string(sprintf('track name=%s description="%s"',$type,$types_to_print->{$type}));
    my $length = length $self->{'string'};
    $self->features('bed');
    $params->{$type} = 0;
    if($length == length $self->{'string'}){$self->{'string'}=$backup;}
    else{
      $self->string("");
    }
  }
  
  #get data from files user uploaded if any and display   
  if($params->{'userdata'}){
       my @fs = $self->get_user_data('BED');

       #displaying Uploaded data
       foreach my $f (@fs)
       {        
         if(!$trackname || $trackname ne $f->{'trackname'})
         {
           $self->string(join $self->{'config'}->{'delim'});
           $trackname = $f->{'trackname'};
           $title = qq{Browser position chr$f->{'seqname'}: $f->{'start'}-$f->{'end'} };
           $self->string(join $self->{'config'}->{'delim'}, $title);
              
           if($params->{'description'}){
             $self->string(sprintf("track name=%s description=%s useScore=%s color=%s",
               $trackname,$f->{'description'},$f->{'usescore'},$f->{'color'}));
           }
         }
         $f->{strand} = ($f->{strand} eq -1) ? '-' : '+';
         $self->string(join("\t",map {$f->{$_}} qw/seqname start end bedname score strand thick_start thick_end item_color BlockCount BlockSizes BlockStart/));
       }
   }
}

sub get_user_data {
  my $self = shift; 
  my $format = shift;
  
  my $hub  = $self->hub;
  my $user = $hub->user;
  my (@fs, $class, $start, $end, $seqname);
  
  my @user_file = $hub->session->get_data('type' => 'upload');

  foreach my $row (@user_file) {
     next unless ($row->{'code'} && $row->{'format'} eq $format);
     my $file = "upload_$row->{'code'}";
     my $name = $row->{'name'};
     my $data = $hub->fetch_userdata_by_id($file);     
  
     if (my $parser = $data->{'parser'}) {
       foreach my $type (keys %{$parser->{'tracks'}}) {
         my $features = $parser->fetch_features_by_tracktype($type);
         ## Convert each feature into a proper API object
         foreach (@$features) {
           my $ddaf = Bio::EnsEMBL::DnaDnaAlignFeature->new($_->cigar_string);
           $ddaf->species($hub->species);
           $ddaf->start($_->rawstart);
           $ddaf->end($_->rawend);
           $ddaf->strand($_->strand);
           $ddaf->seqname($_->seqname);
           $ddaf->score($_->score);
           $ddaf->extra_data($_->external_data);
           $ddaf->{'bedname'} = $_->id;
           $ddaf->{'trackname'} = $type;
           $ddaf->{'description'} = exists($parser->{'tracks'}->{$type}->{'config'}->{'name'}) ? $parser->{'tracks'}->{$type}->{'config'}->{'name'} : '';
           $ddaf->{'usescore'} = exists($parser->{'tracks'}->{$type}->{'config'}->{'useScore'}) ? $parser->{'tracks'}->{$type}->{'config'}->{'useScore'} : '';
           $ddaf->{'color'} = exists($parser->{'tracks'}->{$type}->{'config'}->{'color'}) ? $parser->{'tracks'}->{$type}->{'config'}->{'color'} : '';
           push @fs, $ddaf;
         }
       }
     }
     elsif ($data->{'features'}) {
       push @fs, @{$data->{'features'}};
     }
   }
   return @fs;
}

sub psl_features {
  my $self = shift;
   
}

sub gff3_features {
  my $self         = shift;
  my $slice        = $self->slice;
  my $params       = $self->params;
  my $species_defs = $self->hub->species_defs;
  
  # Always use the forward strand, else CDS coordinates are incorrect (Bio::EnsEMBL::Exon->coding_region_start and _end return coords for forward strand only. Thanks, Core API team.)
  $slice = $slice->invert if $slice->strand == -1;
  
  $self->{'config'} = {
    format             => 'gff3',
    delim              => "\t",
    ordered_attributes => {},
    feature_order      => {},
    feature_type_count => 0,
    
    # TODO: feature types
    #    feature_map => {
    #      dna_align          => { func => 'get_all_DnaAlignFeatures',          type => 'nucleotide_match' },
    #      marker             => { func => 'get_all_MarkerFeatures',            type => 'region' },
    #      repeat             => { func => 'get_all_RepeatFeatures',            type => 'repeat_region' },
    #      assembly_exception => { func => 'get_all_AssemblyExceptionFeatures', type => '' },
    #      ditag              => { func => 'get_all_DitagFeatures',             type => '' },
    #      external           => { func => 'get_all_ExternalFeatures',          type => '' },
    #      oligo              => { func => 'get_all_OligoFeatures',             type => 'oligo' },
    #      qtl                => { func => 'get_all_QtlFeatures',               type => 'region' },
    #      simple             => { func => 'get_all_SimpleFeatures',            type => '' },
    #      protein_align      => { func => 'get_all_ProteinAlignFeatures',      type => 'protein_match' }
    #    }
  };
  
  my @dbs = ('core');
  push @dbs, 'vega'          if $species_defs->databases->{'DATABASE_VEGA'};
  push @dbs, 'otherfeatures' if $species_defs->databases->{'DATABASE_OTHERFEATURES'};
  
  my ($g_id, $t_id);
  
  foreach my $db (@dbs) {
    my $properties = { source => $db eq 'vega' ? 'Vega' : 'Ensembl' };
    
    foreach my $g (@{$slice->get_all_Genes(undef, $db)}) {
      if ($params->{'gene'}) {
        $g_id = $g->stable_id;
        $self->feature('gene', $g, { ID => $g_id, Name => $g_id, biotype => $g->biotype }, $properties);
      }
      
      foreach my $t (@{$g->get_all_Transcripts}) {
        if ($params->{'transcript'}) {
          $t_id = $t->stable_id;
          $self->feature('transcript', $t, { ID => $t_id, Parent => $g_id, Name => $t_id, biotype => $t->biotype }, $properties);
        }
        
        if ($params->{'intron'}) {
          $self->feature('intron', $_, { Parent => $t_id, Name => $self->id_counter('intron') }, $properties) for @{$t->get_all_Introns};
        }
        
        if ($params->{'exon'} || $params->{'cds'}) {
          foreach my $e (@{$t->get_all_Exons}) {
            $self->feature('exon', $e, { Parent => $t_id, Name => $e->stable_id }, $properties) if $params->{'exon'};
            
            if ($params->{'cds'}) {
              my $start = $e->coding_region_start($t);
              my $end   = $e->coding_region_end($t);
              
              next unless $start || $end;
              
              $_ += $slice->start - 1 for $start, $end; # why isn't there an API call for this?
              
              $self->feature('CDS', $e, { Parent => $t_id, Name => $t->translation->stable_id }, { start => $start, end => $end, %$properties });
            }
          }
        }
      }
    }
  }
  
  my %order = reverse %{$self->{'config'}->{'feature_order'}};
  
  $self->string(join "\t", '##gff-version', '3');
  $self->string(join "\t", '##sequence-region', $slice->seq_region_name, '1', $slice->seq_region_length);
  $self->string('');
  $self->string($self->output($order{$_})) for sort { $a <=> $b } keys %order;
}

sub feature {
  my ($self, $type, $feature, $attributes, $properties) = @_;
  my $config = $self->{'config'};
  my $format = $config->{'format'};
  
  my (%vals, @mapping_result);
  
  if ($feature->can('seq_region_name')) {
    %vals = (
      seqid  => $feature->seq_region_name,
      start  => $feature->seq_region_start,
      end    => $feature->seq_region_end,
      strand => $feature->seq_region_strand
    );
  } else {
    %vals = (
      seqid  => $feature->can('entire_seq') && $feature->entire_seq ? $feature->entire_seq->name : $feature->can('seqname') ? $feature->seqname : undef,
      start  => $feature->can('start')  ? $feature->start  : undef,
      end    => $feature->can('end')    ? $feature->end    : undef,
      strand => $feature->can('strand') ? $feature->strand : undef
    );
  }   
  if($format eq 'bed'){
    @mapping_result = qw(seqid start end name score strand);
    $vals{'name'} = $feature->display_id;
  }
  else {
    @mapping_result = qw(seqid source type start end score strand phase);
  }
  %vals = (%vals, (
     type   => $type || ($feature->can('primary_tag') ? $feature->primary_tag : '.sdf'),
     source => $feature->can('source_tag') ? $feature->source_tag  : $feature->can('source') ? $feature->source : 'Ensembl',
     score  => $feature->can('score') ? $feature->score : '.',
     phase  => '.'
   ));   
  if($format eq 'bed' && $vals{'score'} eq '.'){$vals{'score'}='0';}
  
  # Overwrite values where passed in
  foreach (keys %$properties) {
    $vals{$_} = $properties->{$_} if defined $properties->{$_};
  }
  
  if ($vals{'strand'} == 1) {
    $vals{'strand'} = '+';
    $vals{'phase'}  = $feature->phase if $feature->can('phase');
  } elsif ($vals{'strand'} == -1) {
    $vals{'strand'} = '-';
    $vals{'phase'}  = $feature->end_phase if $feature->can('end_phase');
  }
  
  $vals{'phase'}    = '.' if $vals{'phase'} == -1;
  $vals{'strand'} = '.' unless defined $vals{'strand'};
  $vals{'seqid'}  ||= 'SEQ';
  
  my @results = map { $vals{$_} =~ s/ /_/g; $vals{$_} } @mapping_result;

  if ($format eq 'gff') {
    push @results, join ';', map { defined $attributes->{$_} ? "$_=$attributes->{$_}" : () } @{$config->{'extra_fields'}};
  } elsif ($config->{'format'} eq 'gff3') {
    push @results, join ';', map { "$_=" . $self->escape_attribute($attributes->{$_}) } $self->order_attributes($type, $attributes);
  } elsif($format ne 'bed'){
    push @results, map { $attributes->{$_} } @{$config->{'extra_fields'}};
  }
  
  if ($format eq 'gff3') {
    $config->{'feature_order'}->{$type} ||= ++$config->{'feature_type_count'};
    $self->output($type, join "\t", @results);
  } else {
    $self->string(join $config->{'delim'}, @results);
  }
}

sub misc_sets {
  my $self      = shift;
  my $hub       = $self->hub;
  my $slice     = $self->slice;
  my $sets      = $hub->species_defs->databases->{'DATABASE_CORE'}->{'tables'}->{'misc_feature'}->{'sets'};
  my @misc_sets = sort { $sets->{$a}->{'name'} cmp $sets->{$b}->{'name'} } @_;
  my $region    = $slice->seq_region_name;
  my $start     = $slice->start;
  my $end       = $slice->end;
  my $db        = $hub->database('core');
  my $delim     = $self->{'config'}->{'delim'};
  my ($header, $table, @sets);
  
  my $header_map = {
    _gene   => { 
      title   => "Genes in Chromosome $region $start - $end",
      columns => [ 'SeqRegion', 'Start', 'End', 'Ensembl ID', 'DB', 'Name' ]
    },
    default => {
      title   => "Features in set %s in Chromosome $region $start - $end",
      columns => [ 'SeqRegion', 'Start', 'End', 'Name', 'Well name', 'Sanger', 'EMBL Acc', 'FISH', 'Centre', 'State' ]
    }
  };
  
  foreach (@misc_sets, '_gene') {
    $header = $header_map->{$_} || $header_map->{'default'};
    $table = new EnsEMBL::Web::Document::SpreadSheet if $self->html_format;
    
    $self->html(sprintf "<h2>$header->{'title'}</h2>", $sets->{$_}->{'name'});
    
    if ($table) {
      $table->add_columns(map {{ title => $_, align => 'left' }} @{$header->{'columns'}});
    } else {
      $self->html(join $delim, @{$header->{'columns'}});
    }
    
    @sets = $_ eq '_gene' ? $self->misc_set_genes : $self->misc_set($_, $sets->{$_}->{'name'}, $db);
  
    if (scalar @sets) {
      foreach (@sets) {
        if ($table) {
          $table->add_row($_);
        } else {
          $self->html(join $delim, @$_);
        }
      }
      
      $self->html($table->render) if $table;
    } else {
      $self->html('No data available');
    }
  
    $self->html('<br /><br />');
  }
}

sub misc_set {
  my ($self, $misc_set, $name, $db) = @_;
  my $adaptor;
  my @rows;

  eval {
    $adaptor = $db->get_MiscSetAdaptor->fetch_by_code($misc_set);
  };
  
  if ($adaptor) {    
    foreach (sort { $a->start <=> $b->start } @{$db->get_MiscFeatureAdaptor->fetch_all_by_Slice_and_set_code($self->slice, $adaptor->code)}) {
      push @rows, [
        $_->seq_region_name,
        $_->seq_region_start,
        $_->seq_region_end,
        join (';', @{$_->get_all_attribute_values('clone_name')}, @{$_->get_all_attribute_values('name')}),
        join (';', @{$_->get_all_attribute_values('well_name')}),
        join (';', @{$_->get_all_attribute_values('synonym')},    @{$_->get_all_attribute_values('sanger_project')}),
        join (';', @{$_->get_all_attribute_values('embl_acc')}),
        $_->get_scalar_attribute('fish'),
        $_->get_scalar_attribute('org'),
        $_->get_scalar_attribute('state')
      ];
    }
  }
  
  return @rows;
}

sub misc_set_genes {
  my $self  = shift;
  my $slice = $self->slice;
  my @rows;
  
  foreach (sort { $a->seq_region_start <=> $b->seq_region_start } map @{$slice->get_all_Genes($_) || []}, qw(ensembl havana ensembl_havana_gene)) {
    push @rows, [
      $_->seq_region_name,
      $_->seq_region_start,
      $_->seq_region_end,
      $_->stable_id,
      $_->external_db   || '-',
      $_->external_name || '-novel-'
    ];
  }
  
  return @rows;
}

# Orders attributes - predefined array first, then all other keys in alphabetical order
# Also strip any attributes for which we have keys but no values
sub order_attributes {
  my ($self, $key, $attrs) = @_;
  my $attributes = $self->{'config'}->{'ordered_attributes'};
  
  return @{$attributes->{$key}} if $key && $attributes->{$key}; # Reduce the work done
  
  my $i          = 1;
  my %predefined = map { $_ => $i++ } qw(ID Name Alias Parent Target Gap Derives_from Note Dbxref Ontology_term);
  my %order      = map { defined $attrs->{$_} ? ($predefined{$_} || $i++ => $_) : () } sort keys %$attrs;
  my @rtn        = map { $order{$_} } sort { $a <=> $b } keys %order;
  
  @{$attributes->{$key}} = @rtn if $key;
  
  return @rtn;
}

sub id_counter {
  my ($self, $type) = @_;
  return sprintf '%s%05d', $type, ++$self->{'id_counter'}->{$type};
}

sub escape {
  my ($self, $string, $match) = @_;
  
  return '' unless defined $string;
  
  $match ||= '([^a-zA-Z0-9.:^*$@!+_?-|])';
  $string  =~ s/$match/sprintf("%%%02x",ord($1))/eg;
  
  return $string;
}

# Can take array, will return comma separated string if this is the case
sub escape_attribute {
  my $self = shift;
  my $attr = shift;
  
  return '' unless defined $attr;
  
  my $match = '([,=;\t])';
  
  $attr = ref $attr eq 'ARRAY' ? join ',', map { $_ ? $self->escape($_, $match) : () } @$attr : $self->escape($attr, $match);
  
  return $attr;
}

1;