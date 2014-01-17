package EnsEMBL::Web::Configuration::Interface::Record;

### Sub-class to do user-specific interface functions

use strict;

use CGI;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Configuration::Interface;


our @ISA = qw( EnsEMBL::Web::Configuration::Interface );

sub save {
  ### Saves changes to the record(s) and redirects to a feedback page
  my ($self, $object, $interface) = @_;
  my $primary_key = EnsEMBL::Web::Tools::DBSQL::TableName::parse_primary_key($interface->data->get_primary_key);
  my $id = $object->param($primary_key) || $object->param('id');
  if ($object->param('record_type')) {
    $interface->data->attach_owner($object->param('record_type'));
  }
  $interface->cgi_populate($object, $id);

  warn "Saving record ", $interface->data;
  ## Add owner to new records
  ## N.B. Don't need this option for group records, as they are created via sharing
  if (!$id) {
    $interface->data->user_id($ENV{'ENSEMBL_USER_ID'});
  }

  ## Do any type-specific data-munging
  if ($interface->data->type eq 'bookmark') {
    _bookmark($object, $interface);
  }
  elsif ($interface->data->type eq 'configuration' && $object->param('rename') ne 'yes') {
    _configuration($object, $interface);
  }

  my $success = $interface->data->save;
  my $script = $interface->script_name || $object->script;
  my $url;
  if ($success) {
    if ($object->param('record_type') eq 'group') {
      $interface->data->populate($id);
      $url = "/common/user/view_group?id=".$interface->data->webgroup_id;
    }
    else {
      $url = "/common/$script?dataview=success";
    }
  }
  else {
    $url = "/common/$script?dataview=failure";
  }
  if ($object->param('url')) {
    $url .= ';url='.CGI::escape($object->param('url'));
  }
  if ($object->param('mode')) {
    $url .= ';mode='.$object->param('mode');
  }
  return $url;

}

sub delete {
  ### Deletes record(s) and redirects to a feedback page
  my ($self, $object, $interface) = @_;

  my $primary_key = EnsEMBL::Web::Tools::DBSQL::TableName::parse_primary_key($interface->data->get_primary_key);
  my $id = $object->param($primary_key) || $object->param('id');
  if ($object->param('record_type')) {
    $interface->data->attach_owner($object->param('record_type'));
  }
  $interface->data->populate($id);

  my $success = $interface->data->destroy;
  my $script = $interface->script_name || $object->script;
  my $url;
  if ($success) {
    if ($object->param('record_type') eq 'group') {
      $interface->data->populate($id);
      $url = "/common/user/view_group?id=".$interface->data->webgroup_id;
    }
    else {
      $url = "/common/$script?dataview=success";
    }
    $url = "/common/$script?dataview=success";
  }
  return $url;
}


sub _bookmark {
  ## external links will fail unless they begin with http://
  my ($object, $interface) = @_;
  if ($interface->data->url && $interface->data->url !~ /^http/) {
    $interface->data->url('http://'.$interface->data->url);
  }
}

sub _configuration {
  ## Get current config settings from session
  my ($object, $interface) = @_;

  my $referer = $object->param('url');
  my $script = 'contigview';

  my ($ref_url, $ref_args) = split(/\?/, $referer);
  my @items = split(/\//, $ref_url);
  if ($#items == 4) {
    $script = pop @items;
  }

  my $session = $ENSEMBL_WEB_REGISTRY->get_session;
  $session->set_input($object->[1]->{_input});
  my $string = $session->get_script_config_as_string($script);
  $interface->data->scriptconfig($string);
}

1;