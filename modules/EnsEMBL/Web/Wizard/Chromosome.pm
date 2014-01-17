package EnsEMBL::Web::Wizard::Chromosome;
                                                                                
use strict;
use warnings;
no warnings "uninitialized";
                                                                                
use EnsEMBL::Web::Wizard;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::File::Text;
                                                                                
our @ISA = qw(EnsEMBL::Web::Wizard);
  

sub add_karyotype_options {
  my ($self, $object, $option) = @_;
  
  ## chromosome numbers
  my @all_chr = @{$object->species_defs->ENSEMBL_CHROMOSOMES};
  my @chr_values = ({'name'=>'ALL', 'value'=>'ALL'}) ;
  foreach my $next (@all_chr) {
    push @chr_values, {'name'=>$next, 'value'=>$next} ;
  }

  ## pointer/track styles
  my @colours = (
        {'value' => 'purple',   'name'=> 'Purple'},
        {'value' => 'magenta',  'name'=> 'Magenta'},
        {'value' => 'red',      'name' =>'Red'},
        {'value' => 'orange',   'name' => 'Orange'},
        {'value' => 'brown',    'name'=> 'Brown'},
        {'value' => 'green',    'name'=> 'Green'},
        {'value' => 'darkgreen','name'=> 'Dark Green'},
        {'value' => 'blue',     'name'=> 'Blue'},
        {'value' => 'darkblue', 'name'=> 'Dark Blue'},
        {'value' => 'violet',   'name'=> 'Violet'},
        {'value' => 'grey',     'name'=> 'Grey'},
        {'value' => 'darkgrey', 'name'=> 'Dark Grey'}
  );

  my %all_styles = (
    'density' => [
        {'value' => 'line', 'name' => 'Line graph'},
        {'value' => 'bar', 'name' => 'Bar chart, filled'},
        {'value' => 'outline', 'name' => 'Bar chart, outline'},
    ],
    'location' => [
        {'value' => 'box', 'name' => 'Filled box'},
        {'value' => 'filledwidebox', 'name' => 'Filled wide box'},
        {'value' => 'widebox', 'name' => 'Outline wide box'},
        {'value' => 'outbox', 'name' => 'Oversize outline box'},
        {'value' => 'wideline', 'name' => 'Line'},
        {'value' => 'lharrow', 'name' => 'Arrow left side'},
        {'value' => 'rharrow', 'name' => 'Arrow right side'},
        {'value' => 'bowtie', 'name' => 'Arrows both sides'},
        {'value' => 'text', 'name' => 'Text label (+ wide box)'},
    ],
  );

  my @styles;
  my $style_opt = $option->{'styles'};
  if (ref($style_opt) eq 'ARRAY') {
    foreach my $style_gp (@{$style_opt}) {
      my $group = $all_styles{$style_gp};
      if ($group) {
        my $group_name = ucfirst($style_gp);
        foreach my $style (@$group) {
          $style->{'group'} = $group_name if $option->{'group_styles'}; ## for OPTGROUP
          push(@styles, $style);
        }
      } 
    }
  }

  ## basic widgets to configure karyotype
  ## N.B. Don't include styles and colours as depends on number of tracks being done 
  my %widgets = (
    'track_subhead' => {
      'type' => 'SubHeader',
      'value' => 'Feature graphics',
    },
    'layout_subhead' => {
      'type' => 'SubHeader',
      'value' => 'Karyotype layout',
    },
    'chr'   => {
      'type'=>'DropDown',
      'select'   => 'select',
      'label'=>'Chromosome',
      'required'=>'yes',
      'values' => 'chr_values',
    },
    'rows'    => {
      'type'=>'Int',
      'label'=>'Number of rows of chromosomes',
      'value' => '2',
      'required'=>'yes',
    },
    'chr_length' => {
      'type'=>'Int',
      'label'=>'Height of the longest chromosome (pixels)',
      'value' => '200',
      'required'=>'yes',
    },
    'h_padding' => {
      'type'=>'Int',
      'label'=>'Padding around chromosomes (pixels)',
      'value' => '4',
      'required'=>'yes',
    },
    'h_spacing'    => {
      'type'=>'Int',
      'label'=>'Spacing between chromosomes (pixels)',
      'value' => '6',
      'required'=>'yes',
    },
    'v_padding'    => {
      'type'=>'Int',
      'label'=>'Spacing between rows (pixels)',
      'value' => '50',
      'required'=>'yes',
    },
  );
  return (\@chr_values, \@colours, \@styles, \%widgets);
}

sub _init {
  my ($self, $object) = @_;

  my $def_species = $object->species_defs->ENSEMBL_PRIMARY_SPECIES;

  ## define fields available to the forms in this wizard
  my %form_fields = (
    'blurb' => {
      'type'  => 'Information',
      'value' => qq{<p>Karyoview now allows you to display multiple data sets as either density plots, location pointers or a mixture of the two. Your data will be saved in a temporary cache. Once you have added all your tracks, you can configure the rest of the image options.</p> <p><a href="javascript:void(window.open('/$def_species/helpview?kw=karyoview;se=2;#FileFormats','helpview','width=700,height=550,resizable,scrollbars'))">Information about valid file formats</a>: e.g. GFF, PSL, BED</p>},
    },
    'ac_blurb' => {
      'type'  => 'Information',
      'value' => qq(<p>Assembly Converter enables you to convert your data from Mouse assembly m36 to m37. Please note that this facility is not currently compatible with any other species or assembly.</p><p>Supported formats: Only <a href="http://www.sanger.ac.uk/Software/formats/GFF/">GFF</a> files with chromosomal coordinates are currently supported. Data in this format can be exported from the <a href="http://aug2007.archive.ensembl.org/Mus_musculus/">August&nbsp;2007 Ensembl&nbsp;archive</a></p>),
    },
    'track_name'  => {
      'type'=>'String',
      'label'=>'Track name (optional)',
      'loop'=>1,
    },
    'paste_file' => {
      'type'=>'Text',
      'label'=>'Paste file content',
      'loop'=>1,
    },
    'upload_file' => {
      'type'=>'File',
      'label'=>'or upload file',
      'loop'=>1,
    },
    'url_file' => {
      'type'=>'String',
      'label'=>'or use file URL',
      'loop'=>1,
    },
    'tracks_subhead'  => {
      'type'  => 'SubHeader',
      'value' => 'Configure your tracks',
    },
    'merge'  => {
      'type'  => 'CheckBox',
      'label' => 'Merge features into a single track',
      'value' => 'on',
    },
    'maxmin'  => {
      'type'  => 'CheckBox',
      'label' => 'Show max/min lines on density plots',
      'value' => 'on',
    },
    'zmenu'  => {
      'type'  => 'CheckBox',
      'label' => 'Display mouseovers on location menus',
      'value' => 'on',
    },
    'extras_subhead'  => {
      'type'  => 'SubHeader',
      'value' => 'Add Ensembl tracks',
    },
    'track_Vpercents'  => {
      'type'  => 'CheckBox',
      'label' => 'Show GC content frequency *',
      'value' => 'on',
      'available' => '!species_defs NO_SEQUENCE'
    },
    'track_Vsnps'  => {
      'type'  => 'CheckBox',
      'label' => 'Show SNP frequency *',
      'value' => 'on',
      'available' => 'databases ENSEMBL_VARIATION'
    },
    'track_Vgenes'  => {
      'type'  => 'CheckBox',
      'label' => 'Show gene frequency *',
      'value' => 'on',
      'available' => 'database_tables ENSEMBL_DB.gene'
    },
    'track_Vsupercontigs' => {
      'type'  => 'CheckBox',
      'label' => 'Show supercontigs *',
      'value' => 'on',
      'available' => 'features MAPSET_SUPERCTGS'
    },
    'track_blurb' => {
      'type'  => 'Information',
      'value' => '* Extra tracks will only be shown if you select a single chromosome to display on your karyotype',
    },
);

  ## define the nodes available to wizards based on this type of object
  my %all_nodes = (
    'kv_datacheck' => {
      'form' => 1,
      'back'   => 'kv_add',
      'button' => 'Save this track',
    },
    'kv_tracks' => {
      'form' => 1,
      'title' => 'Configure tracks',
      'input_fields'  => [qw(extras_subhead track_Vpercents track_Vsnps track_Vgenes track_Vsupercontigs track_blurb)],
      'no_passback' => [qw(style)],
      'button' => 'Continue',
      'back'   => 1,
    },
    'kv_layout' =>  {
      'form' => 1,
      'title' => 'Configure karyotype',
      'input_fields'  => [qw(chr rows chr_length h_padding h_spacing v_padding)],
      'button' => 'Continue',
      'back'   => 'kv_add',
    },
    'kv_display'  => {
      'button' => 'Finish',
      'form' => 1,
    },
    'ac_convert' => {
      'button' => 'Preview converted file',
    },
    'ac_preview' => {
      'page' => 1,
    } 
  );
  if ($object->script eq 'assemblyconverter') {
    $all_nodes{'kv_add'} = {
      'form' => 1,
      'title' => 'Convert your data',
      'input_fields'  => [qw(ac_blurb paste_file upload_file url_file)],
      'button'  => 'Add more data',
    };
  }
  else {
    $all_nodes{'kv_add'} = {
      'form' => 1,
      'title' => 'Add your data',
      'input_fields'  => [qw(blurb track_name paste_file upload_file url_file)],
      'button'  => 'Add more data',
    };
  }

  ## feedback messages
  my %message = (
  'no_upload'    => 'Your uploaded file could not be cached for processing; please check that the file contains valid data.',
  'no_online'     => 'The URL you entered did not point to a valid data file; please check and try again.',
  'no_paste'     => 'No data was entered.',
  'no_cache'     => 'Sorry, your data could not be cached. Please try again later, or >a href="mailto:helpdesk@ensembl.org">contact our HelpDesk</a> if the problem persists.',

);


  ## which loop are we on?
  my $loops = 1;
  my @params = $object->param();
  foreach my $p (@params) {
    if ($p =~ /^cache_(.)*/) {
      $loops++;
    }
  }

  ## add generic karyotype stuff
  my $option = {
    'styles' => ['density', 'location'],
    'group_styles' => 1,
  };
  my ($chr_values, $colours, $styles, $widgets) = $self->add_karyotype_options($object, $option);
  my %all_fields = (%form_fields, %$widgets);

  my $data = {
    'loops'         => $loops,
    'chr_values'    => $chr_values,
    'colours'       => $colours,
    'styles'        => $styles,
  };

  return [$data, \%all_fields, \%all_nodes, \%message];

}
                                                                              
## ---------------------- METHODS FOR INDIVIDUAL NODES ----------------------


sub kv_add {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_add';           
      
  ## rewrite node values if we are re-doing this page for an additional track
  if ($object->param('submit_kv_add') eq 'Add more data >') {
    $wizard->redefine_node('kv_add', 'back', 1);
  }
  
  ## Change text if this node is being used by assemblyconverter
  if ($script eq 'assemblyconverter') {
    $wizard->redefine_node('kv_datacheck', 'button', 'Upload data');
  } 
                                                               
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub kv_datacheck {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_datacheck';
  my $missing = 0;
  my (%parameter, $result);     

  ## try to cache data
  my $count = $wizard->data('loops');
  my ($data, $param, $filename);
  if ($data = $object->param('paste_file_'.$count)) {
    $param = 'paste_file_'.$count;
    $filename = substr($data, 0, 5); ## use the data itself as the basis for the cache filename
    $filename =~ s/\s//g;
    my $timestamp = time();
    $filename .= '_'.$timestamp;
  }
  elsif ($data = $object->param('upload_file_'.$count)) {
    $param = 'upload_file_'.$count;
    $filename = $object->param($param);
    $filename =~ s#/usr/tmp/##;
  }
  elsif ($data = $object->param('url_file_'.$count)) {
    $param = 'url_file_'.$count;
    ($filename = $data) =~ s#^http://##;
    $filename =~ s#/##g; ## remove slashes so it's not a path!
  }

  my $error;
  if ($param) { 
    my $cache = new EnsEMBL::Web::File::Text($object->[1]->{'_species_defs'});
    $cache->set_cache_filename('kv');
    warn "Saving input file as ", $cache->filename;
    $result = $cache->save($object, $param);
    $error = $result->{'error'};
  }
  else {
    $error = 'no_paste';
  }

  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  if ($error) {
    my $error_msg = $wizard->get_message($error);
    my $msg_output = qq(There seems to be a problem with your input:<blockquote><strong>$error_msg</strong></blockquote>);
    if ($error =~ /[no_upload|no_online|no_paste]/) {
      $msg_output .= 'If this is intentional, click Continue; otherwise click on Back to enter the correct data.';
    }
    $form->add_element(
        'type'   => 'Information',
        'value'  => $msg_output,
    );
    if ($script eq 'assemblyconverter') {
      $wizard->add_outgoing_edges([['kv_datacheck', 'ac_convert']]);
    }
    else {
      $wizard->add_outgoing_edges([['kv_datacheck', 'kv_layout']]);
    }
  }
  else {
    my $cache_file = $result->{'file'};
    $form->add_element(
        'type'   => 'Information',
        'value'  => 'Thank you - your data has been saved.',
    );
    if ($script eq 'assemblyconverter') {
      $wizard->add_outgoing_edges([['kv_datacheck', 'ac_convert']]);
    }
    else {
      $wizard->add_outgoing_edges([['kv_datacheck','kv_tracks']]);
    }
    $wizard->pass_fields($node, $form, $object);
    $form->add_element(
        'type'   => 'Hidden',
        'name'   => 'cache_file_'.$count,
        'value'  => $$result{'file'},
    );
  }
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
    
}

sub kv_tracks {
  my ($self, $object) = @_;
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_tracks';
               
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');
  
  ## add widgets for each track                                                                              
  $wizard->add_widgets($node, $form, $object, ['tracks_subhead']);
  my $count = $wizard->data('loops') - 1;
  my @caches;
  for (my $i=1; $i<=$count; $i++) {
    my $track_name = $object->param('track_name_'.$i) || "(Track $i)";  
    $form->add_element(
        'type'   => 'NoEdit',
        'label'  => 'Track name',
        'value'  => $track_name,
    );
    $form->add_element(
      'type'    =>'DropDown',
      'name'    => 'style_'.$i,
      'select'  => 'select',
      'label'   =>'Style',
      'required'=>'yes',
      'values'  => $wizard->data('styles'),
    );
    $form->add_element(
      'type'    =>'DropDown',
      'name'    => 'col_'.$i,
      'select'  => 'select',
      'label'   =>'Colour',
      'required'=>'yes',
      'values'  => $wizard->data('colours'),
    );
  }
  $wizard->add_widgets($node, $form, $object, ['merge']) if $count > 1;
  $wizard->add_widgets($node, $form, $object, ['maxmin', 'zmenu']);

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub kv_layout {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_layout';
                                                                                
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');
                                                                                
  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub kv_display {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_display';
                                                                                
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  $wizard->redefine_node('kv_tracks', 'button', 'Reconfigure (with same data)');
  ## pass cache fields only
  my $count = $wizard->data('loops') - 1;
  my @caches;
  for (my $i=1; $i<=$count; $i++) {
    my $param = 'cache_file_'.$i;
    push(@caches, $param) if $object->param($param);
  }
  $wizard->pass_fields($node, $form, $object, \@caches);
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub ac_convert {
  my ($self, $object) = @_;
  my %parameter;  

  my $sa    = $object->get_adaptor('get_SliceAdaptor', 'core', $object->species);
  my $ama   = $object->get_adaptor('get_AssemblyMapperAdaptor', 'core', $object->species);
  my $csa   = $object->get_adaptor('get_CoordSystemAdaptor', 'core', $object->species);

  my $m36 = $csa->fetch_by_name('chromosome', 'NCBIM36');
  my $m37 = $csa->fetch_by_name('chromosome', 'NCBIM37');
  my $mapper = $ama->fetch_by_CoordSystems($m36, $m37);

  my $cache = new EnsEMBL::Web::File::Text($self->{'_species_defs'});
  my $data = $cache->retrieve($object->param('cache_file_1'));

  my (@new_coords, @lines);
  my %slice_names = ();
  foreach my $old_line ( split '\n', $data ) {
    next if $old_line =~ /^#/;
    my @tabs = split /(\t|  +)/, $old_line;
 
    ## map to new assembly;
    next unless $tabs[0] && $tabs[6] && $tabs[8];
    @new_coords = $mapper->map($tabs[0], $tabs[6], $tabs[8], _strand_parser($tabs[12]), $m36);

    foreach my $new (@new_coords) {
      my $line;
      my $gap = ref($new) =~ /Gap/ ? 1 : 0;
      my $count = 0;
      foreach my $tab (@tabs) {
        if ($count == 0) { ## seq region name
          if ($gap) {
            $line .= 'GAP';
          }
          else {
            $line .= $slice_names{$new->id} ||= $sa->fetch_by_seq_region_id($new->id)->seq_region_name;
          }
        }
        elsif ($count == 6) { ## start
          $line .= $new->start;
        }
        elsif ($count == 8) { ## end
          $line .= $new->end;
        }
        elsif ($count == 10) { ## score - not relevant to remapped version
          $line .= '';
        }
        elsif ($count == 12) { ## strand
          if ($gap) {
            $line .= '';
          }
          else {
            $line .= _strand_parser($new->strand);
          }
        }
        else {
          $line .= $tab;
        }
        $count++;
      }
      push @lines, $line."\n";
    }
  }
  ## cache revised file
  my $new_cache = new EnsEMBL::Web::File::Text($object->[1]->{'_species_defs'});
  $new_cache->set_cache_filename('converter');
  my $out = $new_cache->filename;
  my $fh = $new_cache->_prep_output($out);
  if( $fh ) {
    foreach my $line (@lines) {
      $fh->gzwrite( $line );
    }
    $fh->gzclose;
  }

  my $root = $object->species_defs->ENSEMBL_TMP_DIR_CACHE;
  $out =~ s/$root//;
  $parameter{'node'} = 'ac_preview';
  $parameter{'converted'} = $out;
                                                                              
  return \%parameter;
}

sub _strand_parser {
  my $strand = shift;
  if ($strand eq '+') {
    $strand = 1;
  }
  elsif ($strand eq '-') {
    $strand = -1;
  }
  elsif ($strand == 1) {
    $strand = '+';
  }
  elsif ($strand == -1) {
    $strand = '-';
  }
  elsif ($strand == 0) {
    $strand = '';
  }
  else {
    $strand = 0;
  }
  return $strand;
}

sub ac_preview {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'ac_preview';
                                                                                
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');
  #$wizard->pass_fields($node, $form, $object, \@caches);
  #$wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

1;