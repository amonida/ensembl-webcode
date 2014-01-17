package EnsEMBL::Web::Wizard::Feature;
                                                                                
use strict;
use warnings;
no warnings "uninitialized";
                                                                                
use EnsEMBL::Web::Wizard;
use EnsEMBL::Web::Wizard::Chromosome;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::File::Text;
                                                                                
our @ISA = qw(EnsEMBL::Web::Wizard);
  
## DATA FOR DROPDOWNS, ETC.
  
sub _init {
  my ($self, $object) = @_;
      
  ## define fields available to the forms in this wizard
  my %form_fields = (
    'type_subhead' => {
      'type'  => 'SubHeader',
      'value' => 'Select features by ID',
    },
    'type_blurb' => {
      'type'  => 'Information',
      'value' => 'Hint: to display multiple features, enter them as a space-delimited list',
    },
    'type'  => {
      'type'    =>'DropDownAndString',
      'select'  => 'select',
      'label'   =>'Feature type',
      'values'  => 'types',
      'value'   => 'Gene',
      'string_name'   => 'id',
      'string_label'  => 'ID',
    },
    'xref_subhead' => {
      'type'  => 'SubHeader',
      'value' => 'Search for features (OMIM only)',
    },
    'xref_db'  => {
      'type'    =>'MultiSelect',
      'label'   =>'Feature type',
      'values'  => 'xref',
    },
    'xref_term' => {
      'type'   => 'String',
      'label'  => 'Search term',
    },
    'xref_blurb' => {
      'type' => 'Information',
      'value' => 'N.B. If you enter more than one search term, the search will be done on the whole phrase (i.e. "prostate cancer"), NOT as an and/or search on each term.',
    },
    'pointer_blurb' => {
      'type' => 'Information',
      'value' => 'This option includes additional data, so two sets of pointers should be configured',
    },
    'col_0'       => {
      'type'=>'DropDown',
      'select'   => 'select',
      'label'=>'Colour for chosen feature type',
      'required'=>'yes',
      'values' => 'colours',
      'value' => 'red',
    },
    'style_0'       => {
      'type'=>'DropDown',
      'select'   => 'select',
      'label'=>'Style',
      'required'=>'yes',
      'values' => 'styles',
      'value' => 'rharrow',
    },
    'col_1'       => {
      'type'=>'DropDown',
      'select'   => 'select',
      'label'=>'Colour for associated features',
      'required'=>'yes',
      'values' => 'colours',
      'value' => 'blue',
    },
    'style_1'       => {
      'type'=>'DropDown',
      'select'   => 'select',
      'label'=>'Style',
      'required'=>'yes',
      'values' => 'styles',
      'value' => 'lharrow',
    },
    'zmenu'  => {
      'type'  => 'CheckBox',
      'label' => 'Display mouseovers on menus',
      'value' => 'on',
    },
  );

  ## define the nodes available to wizards based on this type of object
  my %all_nodes = (
    'fv_select' => {
      'form' => 1,
      'title' => 'Select a feature',
      'input_fields'  => [qw(type_subhead type type_blurb)],
    },
    'fv_process' => {
      'button' => 'Next',
    },
    'fv_layout' =>  {
      'form' => 1,
      'title' => 'Configure karyotype',
      'input_fields'  => [qw(layout_subhead chr rows chr_length h_padding h_spacing v_padding)],
      'back'   => 1,
    },
    'fv_display'  => {
      'button' => 'Show Feature',
      'page'   => 1,
      'back'   => 1,
    },
  );

  ## add generic karyotype stuff
  my $option = {
    'styles' => ['location'],
  };
  my ($chr_values, $colours, $styles, $widgets) = $self->EnsEMBL::Web::Wizard::Chromosome::add_karyotype_options($object, $option);
  my %all_fields = (%form_fields, %$widgets);

  ## additional object data
  my $types = [];
  ## look in species defs to find available features
  foreach my $avail_feature (@{$object->find_available_features}) {
    push @$types, { 'value'=>$avail_feature->{'value'},'name'=>$avail_feature->{'text'} },
  }
  ## values for search checkboxes
  my $xref = [
    {'name'=>'OMIM Disease', 'value'=>'MIM_MORBID'},
    {'name'=>'OMIM Trait',   'value'=>'MIM_GENE'},
  ];

  my $data = {
    'chr_values'    => $chr_values,
    'colours'       => $colours,
    'styles'        => $styles,
    'types'         => $types,
    'xref'          => $xref,
  };
                                                                                
  return [$data, \%all_fields, \%all_nodes];

}
                                                                              
## ---------------------- METHODS FOR INDIVIDUAL NODES ----------------------

sub fv_select {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'fv_select';

  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  $wizard->add_widgets($node, $form, $object);
  if ($species eq 'Homo_sapiens') {
    $wizard->add_widgets($node, $form, $object, ['xref_subhead', 'xref_db', 'xref_term', 'xref_blurb']);
  }
  $wizard->add_buttons($node, $form, $object);

  return $form;
}


sub fv_process {
  my ($self, $object) = @_;
  my %parameter;

  ## does the species have chromosomes?
  $parameter{'type'}      = $object->param('type');
  $parameter{'id'}        = $object->param('id');
  $parameter{'xref_term'} = $object->param('xref_term');
  my @db_array  = $object->param('xref_db');
  $parameter{'xref_db'}   = \@db_array;
  if (@{$object->species_defs->ENSEMBL_CHROMOSOMES} && 
             ($object->param('xref_term') || $object->feature_mapped)) {
    $parameter{'node'} = 'fv_layout';
  }
  else {
    $parameter{'node'} = 'fv_display';
  }

  return \%parameter;
}

sub fv_layout {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'fv_layout';
                                                                                
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');
                             
  $wizard->add_widgets($node, $form, $object, ['track_subhead', 'zmenu', 'col_0', 'style_0']);
  if ($object->param('type') eq 'OligoProbe') {
    $wizard->add_widgets($node, $form, $object, ['pointer_blurb', 'col_1', 'style_1']);
  }
  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub fv_display {
  ## Doesn't need to do anything except show feature info
}

1;