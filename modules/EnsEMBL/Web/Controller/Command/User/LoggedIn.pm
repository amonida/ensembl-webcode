package EnsEMBL::Web::Controller::Command::User::LoggedIn;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
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
    'scriptname' => 'login_check',
    'objecttype' => 'User',
  );

  if( $webpage->has_a_problem() ) {
    $webpage->render_error_page( $webpage->problem->[0] );
  } else {
    foreach my $object( @{$webpage->dataObjects} ) {
      $webpage->configure( $object, 'login_check' );
    }
    $webpage->action();
  }

}

}

1;