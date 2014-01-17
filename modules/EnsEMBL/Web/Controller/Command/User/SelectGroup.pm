package EnsEMBL::Web::Controller::Command::User::SelectGroup;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @records = $user->find_records_by_user_record_id($cgi->param('id'), { adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor });
  my $user_record = $records[0];
  warn "Owner is ", $user_record->owner;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $user_record->owner});
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  $self->filters->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    $self->render_message;
  }
}

sub render_page {
  my $self = shift;
 
    my $webpage= new EnsEMBL::Web::Document::WebPage(
    'renderer'   => 'Apache',
    'outputtype' => 'HTML',
    'scriptname' => 'user/select_group',
    'objecttype' => 'User',
  );

  if( $webpage->has_a_problem() ) {
    $webpage->render_error_page( $webpage->problem->[0] );
  } else {
    foreach my $object( @{$webpage->dataObjects} ) {
      $webpage->configure( $object, 'select_group' );
    }
    $webpage->action();
  }
 
}

}

1;