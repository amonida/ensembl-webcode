=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::ImageExport::ImageFormats;

use strict;
use warnings;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Constants;

use parent qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  ### Options for gene sequence output
  my $self  = shift;
  my $hub   = $self->hub;

  my $html = '<h1>Image download</h1>';

  my $form = $self->new_form({'id' => 'export', 'action' => $hub->url({'action' => 'ImageOutput',  '__clear' => 1}), 'method' => 'post', 'class' => 'freeform-stt'});

  my $intro_fieldset = $form->add_fieldset();

  $intro_fieldset->add_field({
                        'type'  => 'String',
                        'name'  => 'filename',
                        'label' => 'File name',
                        'value' => $self->default_file_name,
                        });

  my $fieldset = $form->add_fieldset({'legend' => 'Select Format'});

  ## Hidden fields needed for redirection to image output
  $fieldset->add_hidden({'name' => 'data_type', 'value' => $hub->param('data_type')});
  $fieldset->add_hidden({'name' => 'component', 'value' => $hub->param('component')});

  my $radio_info  = EnsEMBL::Web::Constants::IMAGE_EXPORT_PRESETS;
  my $formats     = [];

  foreach (sort {$radio_info->{$a}{'order'} <=> $radio_info->{$b}{'order'}} keys %$radio_info) {
    my $info_icon = $radio_info->{$_}{'info'} 
                      ? sprintf '<img src="/i/16/info.png" class="alignright _ht" title="<p>%s</p>%s" />', 
                                    $radio_info->{$_}{'label'}, $radio_info->{$_}{'info'} 
                      : '';
    my $caption = sprintf('<b>%s</b> - %s%s', 
                            $radio_info->{$_}{'label'}, $radio_info->{$_}{'desc'}, $info_icon);
    push @$formats, {'value' => $_, 'class' => '_stt', 'caption' => {'inner_HTML' => $caption}};
  }

  ## Radio buttons for different formats
  my %params = (
                'type'    => 'Radiolist',
                'name'    => 'format',
                'values'  => $formats,
                'value'   => 'journal',
                );
  $fieldset->add_field(\%params);

  ## Options for custom format
  my $opt_fieldset  = $form->add_fieldset({'class' => '_stt_custom', 'legend' => 'Options'});

  my $image_formats = [{'value' => '', 'caption' => '-- Choose --', 'class' => '_stt'}];
  my %format_info   = EnsEMBL::Web::Constants::IMAGE_EXPORT_FORMATS;
  foreach (sort keys %format_info) {
    my $params = {'value' => $_, 'caption' => $format_info{$_}{'name'}, 'class' => ['_stt']};
    push @{$params->{'class'}}, '_stt__raster ' if $format_info{$_}{'type'} eq 'raster';
    push @$image_formats, $params;
  }
  $opt_fieldset->add_field({'type' => 'Dropdown', 'name' => 'image_format', 'class' => '_stt', 
                            'label' => 'Format', 'values' => $image_formats});

  ## Contrast change hasn't been implemented in non-PNG formats yet
  $opt_fieldset->add_field({'type' => 'Checkbox', 'name' => 'contrast', 'field_class' => '_stt_raster',
                            'label' => 'Increase contrast', 'value' => '2'}); 

  ## Size and resolution are only relevant to raster formats like PNG
  my $image_sizes = [{'value' => '', 'caption' => 'Current size'}];
  my @sizes = qw(500 750 1000 1250 1500 1750 2000);
  foreach (@sizes) {
    push @$image_sizes, {'value' => $_, 'caption' => "$_ px"};
  }
  $opt_fieldset->add_field({'type' => 'Dropdown', 'name' => 'resize', 'field_class' => '_stt_raster', 
                            'label' => 'Image size', 'values' => $image_sizes});

  my $image_scales = [
                      {'value' => '', 'caption' => 'Standard'},
                      {'value' => '2', 'caption' => 'High (x2)'},
                      {'value' => '5', 'caption' => 'Very high (x5)'},
                      ];

  $opt_fieldset->add_field({'type' => 'Dropdown', 'name' => 'scale', 'field_class' => '_stt_raster',
                            'label' => 'Resolution', 'values' => $image_scales});

  ## Place submit button at end of form
  my $final_fieldset = $form->add_fieldset();

  ## Don't forget the core params!
  my @core_params = keys %{$hub->core_object('parameters')};
  push @core_params, qw(extra align);
  foreach (@core_params) {
    $final_fieldset->add_hidden([
      {
        'name'    => $_,
        'value'   => $hub->param($_) || '',
      },
    ]);
  }

  $final_fieldset->add_button('type' => 'Submit', 'name' => 'submit', 'value' => 'Download', 'class' => 'download');

  my $wrapped_form = $self->dom->create_element('div', {
    'id'        => 'ImageExport',
    'class'     => 'js_panel',
    'children'  => [ {'node_name' => 'input', 'class' => 'subpanel_type', 'value' => 'ImageExport', 'type' => 'hidden' }, $form ]
  });

  $html .= $wrapped_form->render;

  $html .= '<p>For more information about print options, see our <a href="/Help/Faq?id=502" class="popup">image export FAQ</a>';

  return $html;
}

sub default_file_name {
  my $self  = shift;
  my $hub   = $self->hub;
  my $name  = $hub->species_defs->SPECIES_COMMON_NAME;

  my $type = $hub->param('data_type');

  if ($type eq 'Location') {
    ## Replace hyphens, because they aren't export-friendly
    (my $location = $hub->param('r')) =~ s/-/_/g;
    $name .= "_$location";
  }
  elsif ($type eq 'Gene') {
    my $data_object = $hub->param('g') ? $hub->core_object('gene') : undef;
    if ($data_object) {
      $name .= '_';
      my $stable_id = $data_object->stable_id;
      my ($disp_id) = $data_object->display_xref;
      $name .= $disp_id || $stable_id;
    }
  }
  return $name.'.png';
}

1;