package Integration;

use strict;
use warnings;

use IntegrationView;
use Integration::Log::YAML;
use Integration::Task;

{

my %Checkout_of;
my %Log_of;
my %LogLocation_of;
my %HtdocsLocation_of;
my %Configuration_of;
my %Tests_of;
my %TestResult_of;
my %CriticalFail_of;
my %Event_of;
my %Rollback_of;
my %View_of;

sub new {
  ### c
  ### Inside out class for creating a new continuous integration server.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Checkout_of{$self} = defined $params{checkout} ? $params{checkout} : [];
  $HtdocsLocation_of{$self} = defined $params{htdocs} ? $params{htdocs} : "";
  $LogLocation_of{$self} = defined $params{log_location} ? $params{log_location} : "";
  $Configuration_of{$self} = defined $params{configuration} ? $params{configuration} : [];
  $Rollback_of{$self} = defined $params{rollback} ? $params{rollback} : [];
  $Tests_of{$self} = defined $params{tests} ? $params{tests} : [];
  $TestResult_of{$self} = undef; 
  $CriticalFail_of{$self} = undef; 
  $Event_of{$self} = { date => '?', status => '?' }; 
  $View_of{$self} = defined $params{view} ? $params{view} : IntegrationView->new(( server => $self, output => $self->htdocs_location));
  $Log_of{$self} = Integration::Log::YAML->new(( location => $self->log_location));
  return $self;
}

sub checkout {
  ### Checks out modules from CVS 
  my $self = shift;

  $self->message("Checkout in progress.", "red");

  foreach my $task (@{ $self->checkout_tasks }) {
    $self->message("Checkout in progress", "red");
    $task->process;
  }
  $self->event->{checkout} = "yes";
  return 1;
}

sub purge_rollback {
  my $self = shift;
  warn "PURGING previous version";
  foreach my $task (@{ $self->rollback_tasks }) {
    $task->purge;
  }
}

sub rollback {
  my $self = shift;
  warn "ROLLING BACK to previous version";
  foreach my $task (@{ $self->rollback_tasks }) {
    $task->rollback;
  }
  my $rollback_event = $self->log->latest_ok_event;
  my $rollback_build = $rollback_event->{build};
  my $failed_build = $self->log->latest_event->{build} + 1;
  my $now = `date`;
  $self->message("$now - Build $failed_build failed: rolled back to build $rollback_build (" . $rollback_event->{date}. ")", "red");
}

sub message {
  my ($self, $message, $colour) = @_;
  $self->view->message($message, $colour);
}

sub configure {
  ### Performs configuration tasks to setup the integration server.
  my $self = shift;

  foreach my $task (@{ $self->rollback_tasks }) {
    $task->process;
  }

  $self->message("Configuring new checkout", "yellow");

  my $warnings = 0;

  foreach my $task (@{ $self->configuration }) {
    $warnings += $task->process;
  }
  return 1;
}

sub test {
  ### Runs all automated tests in the test suite and returns the test percentage. The code isn't clean until the bar turns green.
  my $self = shift;
  my $total = 0;
  my $failed = 0;
  my $passed = 0;
  $self->message("Testing new checkout", "yellow");
  foreach my $task (@{ $self->tests }) {
    $task->process;
    if ($task->did_fail) {
      $failed++;
      if ($task->critical) {
        $self->critical_fail("yes");
      }
    } else {
      $passed++;
    }
    $total++;
  }
  my $result = ($passed / $total) * 100;
  $self->test_result($result);
  return $result; 
} 

sub generate_output {
  ### Generates the output of both checkout and test runs in HTML by default. This output can be altered by reassigning a new view object using {{view}}.
  my $self = shift;
  return $self->view->generate_html;
}

sub htdocs_location {
  ### a
  my $self = shift;
  $HtdocsLocation_of{$self} = shift if @_;
  return $HtdocsLocation_of{$self};
}

sub view {
  ### a
  my $self = shift;
  $View_of{$self} = shift if @_;
  return $View_of{$self};
}

sub configuration {
  ### a
  ### Returns an array ref of {{Integration::Task}} objects.
  my $self = shift;
  $Configuration_of{$self} = shift if @_;
  return $Configuration_of{$self};
}

sub log {
  ### a
  ### Returns an array ref of {{Integration::Task}} objects.
  my $self = shift;
  $Log_of{$self} = shift if @_;
  return $Log_of{$self};
}

sub update_log {
  my $self = shift;
  my $status = "ok";
  my $now = `date`;
  if ($self->test_result < 100) {
    $status = "failed";
  }
  if ($self->critical_fail) {
    $status = "critical";
  }
  my $event = $self->event; 
  $event->{date} = $now;
  $event->{status} = $status;
  if ($self->test_result) {
    $event->{test} = $self->test_result;
  }
  if ($status eq "ok") {
    $self->message("Ensembl is up-to-date (" . `date` . ")", "green");
  }
  $self->log_event($event);
  $self->log->save;
}

sub log_event {
  ### Adds a new event to the log
  my ($self, $event) = @_;
  $self->log->add_event($event);
}

sub log_location {
  ### a
  my $self = shift;
  $LogLocation_of{$self} = shift if @_;
  return $LogLocation_of{$self};
}

sub tests {
  ### a
  my $self = shift;
  $Tests_of{$self} = shift if @_;
  return $Tests_of{$self};
}

sub rollback_tasks {
  ### a
  my $self = shift;
  $Rollback_of{$self} = shift if @_;
  return $Rollback_of{$self};
}

sub add_rollback_task {
  my ($self, $task) = @_;
  push @{ $self->rollback_tasks }, $task;
}

sub test_result {
  ### a
  my $self = shift;
  $TestResult_of{$self} = shift if @_;
  return $TestResult_of{$self};
}

sub critical_fail {
  ### a
  my $self = shift;
  $CriticalFail_of{$self} = shift if @_;
  return $CriticalFail_of{$self};
}

sub event {
  ### a
  my $self = shift;
  $Event_of{$self} = shift if @_;
  return $Event_of{$self};
}

sub checkout_tasks {
  ### a
  ### Returns an array ref of {{Integration::Task}} objects to be performed at checkout.
  my $self = shift;
  $Checkout_of{$self} = shift if @_;
  return $Checkout_of{$self};
}

sub add_configuration_task {
  my ($self, $task) = @_;
  push @{ $self->configuration }, $task;
}

sub add_checkout_task {
  my ($self, $task) = @_;
  push @{ $self->checkout_tasks }, $task;
}

sub add_test_task {
  my ($self, $task) = @_;
  push @{ $self->tests }, $task;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $HtdocsLocation_of{$self};
  delete $View_of{$self};
  delete $Configuration_of{$self};
  delete $Checkout_of{$self};
  delete $LogLocation_of{$self};
  delete $Log_of{$self};
  delete $Tests_of{$self};
  delete $Event_of{$self};
  delete $TestResult_of{$self};
  delete $CriticalFail_of{$self};
  delete $Rollback_of{$self};
}

}


1;