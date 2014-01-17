package EnsEMBL::Web::Controller::Command::User::LoadConfig;

### Sets a configuration as the one in current use

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Object::Data::Configuration;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  my $config = EnsEMBL::Web::Object::Data::Configuration->new({'id'=>$cgi->param('id')});
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $config->user->id});

}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->process;
  } else {
    $self->render_message; 
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;

  my @scripts = qw(contigview cytoview);

  ## This bit only applies if you want to load the config and not jump to the bookmark saved with it
  my $url = $cgi->param('url');
  if ($url) {
    my ($host, $params) = split(/\?/, $url);
    my (@parameters) = split(/;/, $params);
    my $new_params = "";
    foreach my $p (@parameters) {
      if ($p !~ /bottom/) {
        $new_params .= ";" . $p;
      }
    }

    $new_params =~ s/^;/\?/;
    $url = $host . $new_params;
  }

  my $session = $ENSEMBL_WEB_REGISTRY->get_session;
  $session->set_input($cgi);
  my $configuration = EnsEMBL::Web::Object::Data::Configuration->new({'id'=>$cgi->param('id')});

  my $string = $configuration->scriptconfig;
  my $r = Apache2::RequestUtil->request();
  $session->create_session_id($r);
  foreach my $script_name (@scripts) {
    warn "SETTING CONFIG ", $cgi->param('id'), " FOR SCRIPT: " , $script_name;
    $session->set_script_config_from_string($script_name, $string);
  }
  my $new_url = '/common/user/set_config?id=' . $cgi->param('id');
  if ($url) {
    $new_url .= ';url=' . CGI::escape($url);
  }
  $cgi->redirect($new_url);
}

}

1;