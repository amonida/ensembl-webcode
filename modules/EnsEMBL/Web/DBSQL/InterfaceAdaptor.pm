package EnsEMBL::Web::DBSQL::InterfaceAdaptor;

### 'Replacement' for ViewAdaptor - generic adaptor for connecting to a MySQL database

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;
use Data::Dumper;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::DBSQL::SQL::Result;

{

my %Hostname_of;
my %Port_of;
my %Database_of;
my %Table_of;
my %Username_of;
my %Password_of;
my %Handle_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Hostname_of{$self}          = defined $params{hostname} ? $params{hostname} : "";
  $Port_of{$self}              = defined $params{port}     ? $params{port}     : "";
  $Database_of{$self}          = defined $params{database} ? $params{database} : "";
  $Table_of{$self}             = defined $params{table}    ? $params{table}    : "";
  $Username_of{$self}          = defined $params{username} ? $params{username} : "";
  $Password_of{$self}          = defined $params{password} ? $params{password} : "";
  $Handle_of{$self}            = defined $params{handle}   ? $params{handle}   : undef;
  if (defined $params{db}) {
    $Hostname_of{$self} = $params{db}->{HOST};
    $Port_of{$self} = $params{db}->{PORT};
    $Database_of{$self} = $params{db}->{NAME};
    $Username_of{$self} = $params{db}->{USER};
    $Password_of{$self} = $params{db}->{PASS};
  }
  return $self;
}

#-------------------------------- Accessors ------------------------------------------

sub hostname {
  ### a
  my $self = shift;
  $Hostname_of{$self} = shift if @_;
  return $Hostname_of{$self};
}

sub port {
  ### a
  my $self = shift;
  $Port_of{$self} = shift if @_;
  return $Port_of{$self};
}

sub database {
  ### a
  my $self = shift;
  $Database_of{$self} = shift if @_;
  return $Database_of{$self};

}

sub table {
  ### a
  my $self = shift;
  $Table_of{$self} = shift if @_;
  return $Table_of{$self};
}

sub username {
  ### a
  my $self = shift;
  $Username_of{$self} = shift if @_;
  return $Username_of{$self};
}

sub password {
  ### a
  my $self = shift;
  $Password_of{$self} = shift if @_;
  return $Password_of{$self};
}


sub handle {
  ### a
  ### Returns a database handle (creates one if it doesn't exist)
  my $self = shift;
  $Handle_of{$self} = shift if @_;
  if ($Handle_of{$self}) {
  } else {
    $Handle_of{$self} = $self->create_handle;
  }
  return $Handle_of{$self};
}

#--------------------------- Generic functions --------------------------------------

sub create_handle {
  ### Creates a standard DBI database handle
  my $self = shift;
  my $dbh = DBI->connect(
                         "DBI:mysql:database=" . $self->database . 
                         ";host=" . $self->hostname . 
                         ";port=" . $self->port, 
                         $self->username , 
                         $self->password
  );
  unless ($dbh) {
    warn ("Unable to connect to database");
    $dbh = undef;
  }
  warn "DBH: " . $dbh;
  return $dbh;
}


sub discover {
  ### Queries the database metadata for information about available fields. 
  ### Returns: a reference to an array of hashrefs. Each hashref
  ### contains the defintion of the database field. For example, the name 
  ### of the field can be accessed by $fields->[0]->{'Field'}.
  my ($self, $query_table) = @_;
  my $table = $self->table;
  if ($query_table) {
    $table = $query_table;
  } 
  my $sql = "DESCRIBE " . $table . ";"; 
  my $results = $self->query($sql, 'Field');
  my $fields = [];
  foreach my $key (keys %{ $results }) {
    push @{ $fields }, $results->{$key};
  }
  return $fields;
}

sub fetch_id {
  my ($self, $id) = @_;
  my $table = $self->table;
  my $key = $table . "_id";
  return $self->fetch_by({ $key => $id });
}

sub fetch_by {
  my ($self, $primary_key, $where) = @_;
  my $sql_where = "";
  foreach my $key (keys %{ $where }) {
    $sql_where .= $key . " = '" . $where->{$key} . "', ";
  }
  $sql_where =~ s/, $//;
  my $table = $self->table;
  my $sql = "SELECT * FROM $table WHERE $sql_where;"; 
  warn "SQL: " . $sql;
  return $self->query($sql, $primary_key);
}


sub fetch_list {
  ### Fetches a list of all records, containing only the selected column values
  my ($self, $table, $primary_key, $columns, $parameters, $order) = @_;
  my $col_list = join(', ', @$columns);
  my $sql = "SELECT $primary_key";
  if ($col_list) {
    $sql .= ", $col_list";
  }
  $sql .= " FROM $table";
  if ($parameters) {
    $sql .= qq( WHERE $parameters);
  }
  if ($order) {
    $sql .= " ORDER BY $order;";
  }
  else {
    $sql .= " ORDER BY $primary_key ASC;";
  }
  warn "SQL: " . $sql;
  return $self->handle->selectall_arrayref($sql);
}


#--------------------------- Active Record methods --------------------------------

sub dump_data {
  ### Uses Data::Dumper to format a record's data for storage,
  ### and also handles escaping of quotes to avoid SQL errors
  my ($self, $data) = @_;
  my %temp_fields;
  foreach my $key (keys %{ $data }) {
    ## check for multi-value parameters
    my $value = $data->{$key};
    $value =~ s/'/\\'/g;
    if ($value =~ /\0/) {
      my @array = split('\0', $value);
      $temp_fields{$key} = \@array;
    }
    else {
      $temp_fields{$key} = $value;
    }
  }
  my $dump = Dumper(\%temp_fields);
  $dump =~ s/^\$VAR1 = //;
  return $dump;
}

sub exists {
  ### Checks if a row exists in the table. 
  my ($self, $id) = @_;

}

sub edit {
  ### Updates an existing entry in the table
  my ($self, %params) = @_;
  my $result = EnsEMBL::Web::DBSQL::SQL::Result->new({ action => 'edit' });
  my %set_parameters = %{ $params{set} };
  my $id = $params{id};
  my @multiple_ids = undef;
  if ($params{multiple_ids}) {
    @multiple_ids = @{ $params{multiple_ids} };
  }
  my @definition = undef;
  my $user = undef;
  my $label = undef;

  if ($params{definition}) {
    @definition = @{ $params{definition} };
  } 

  if ($params{label}) {
    $label = $params{label};
  }

  if ($params{user}) {
    $user = $params{user};
    delete $set_parameters{user_id};
  }

  if ($params{record}) {
    %set_parameters = %{ $self->record_parameters(\%set_parameters, $params{record}, $user, $label) };
  }

  foreach my $key (keys %set_parameters) {
    $set_parameters{$key} =~ s/'/\\'/g;
    $set_parameters{$key} =~ s/\\.'/\\'/g;
  }

  if ($set_parameters{password}) {
    my $salt = $params{salt}; 
    my $password = $set_parameters{password};
    $set_parameters{password} = EnsEMBL::Web::Object::User->encrypt($password);
  }
  
  my $in = "'$id'";
  if ($#multiple_ids > 0) {
    $in = join(", ", @multiple_ids);
    warn "PERFORMING MULTIPLE UPDATES: " . $in;
  }

  my $table = $self->table;
  my $sql = "UPDATE $table ";
  $sql .= $self->set_sql_with_parameters(\%set_parameters, \@definition, $user);
  $sql .= "WHERE " . $table . "_id IN (" . $in . ")";  

  warn "SQL: " . $sql;

  my $return = $self->execute($sql); 
  $result->set_result($return);
  $result->set_set_parameters(\%set_parameters);
  if ($return) { 
    $result->set_success("yes");
  }

  return $result;
}

sub execute {
  my ($self, $sql) = @_;
  warn "=================== VIEW SQL: " . $sql; 
  my $sth = $self->handle->prepare($sql);
  my $result = $sth->execute();
  return $result;
}

sub set_sql_with_parameters {
  my ($self, $set, $def, $user) = @_;
  my $sql = "SET ";
  foreach my $key (keys %{ $set }) {
    $sql .= $key . " = '" . $set->{$key} . "', ";
  }
  if ($self->definition_contains('created_at', @{ $def })) {
    $sql .= "created_at=CURRENT_TIMESTAMP, ";
  }
  if ($self->definition_contains('modified_at', @{ $def })) {
    $sql .= "modified_at=CURRENT_TIMESTAMP, ";
  }
  if ($user) {
    if ($self->definition_contains('created_by', @{ $def })) {
      $sql .= "created_by = '" . $user . "', ";
    }
    if ($self->definition_contains('modified_by', @{ $def })) {
      $sql .= "modified_by = '" . $user . "', ";
    }
  }
  $sql =~ s/, $/ /;
  return $sql;
}

sub create {
  ### Creates a new entry in the table
  my ($self, %params) = @_;
  my $result = EnsEMBL::Web::DBSQL::SQL::Result->new({ action => 'create' });
  my %set_parameters = %{ $params{set} };
  my @definition = undef;
  my $user = undef;
  my $record = undef;

  if ($params{definition}) {
    @definition = @{ $params{definition} };
  } 

  if ($params{user}) {
    $user = $params{user};
    if ($params{type} ne "relationship") {
      delete $set_parameters{user_id};
    }
  }

  if ($params{record}) {
    warn "CREATING FOR USER: " . $user;
    %set_parameters = %{ $self->record_parameters(\%set_parameters, $params{record}, $user) };
    $set_parameters{user_id} = $user;
    warn "USER: " . $set_parameters{user_id};
  }

  my $table = $self->table;
  if ($params{table}) {
    $table = $params{table};
    @definition = @{ $self->discover($table) };
  }

  foreach my $key (keys %set_parameters) {
    $set_parameters{$key} =~ s/'/\\'/g;
    $set_parameters{$key} =~ s/\\.'/\\'/g;
  }

  my $sql = "INSERT INTO " . $table . " ";
  $sql .= $self->set_sql_with_parameters(\%set_parameters, \@definition, $user);
  $sql .= ";";

  if ($self->execute($sql)) {
    $result->last_inserted_id($self->last_inserted_id);
    $result->success('yes');
  }
  return $result; 
}

sub record_parameters {
  my ($self, $parameters, $record, $ident, $ident_label) = @_;
  if (!$ident_label) {
    $ident_label = "user_id";
  }
  my %set_parameters = %{ $parameters };
  my $dump = $self->dump_data($parameters);

  foreach my $key (keys %set_parameters) {
    delete $set_parameters{$key};
  }

  $set_parameters{type} = $record;
  $set_parameters{data} = $dump;

  return \%set_parameters;
}

sub last_inserted_id {
  my ($self) = @_;
  my $sql = "SELECT LAST_INSERT_ID()";
  my $T = $self->handle->selectall_arrayref($sql);
  return '' unless $T;
  my @A = @{$T->[0]}[0];
  my $result = $A[0];
  return $result;
}


sub definition_contains {
  my ($self, $name, @definition) = @_;
  my $found = 0;
  foreach my $field (@definition) {
    if ($field->{'Field'} eq $name) {
      $found = 1;
    }
  }
  return $found;
}

sub query {
  ### Simple wrapper for a SELECT query
  ### Argument: string (SQL)
  my ($self, $sql, $key) = @_;
  my $results = undef;
  if ($key) {
    $results = $self->handle->selectall_hashref($sql, $key);
  } else {
    $results = $self->handle->selectall_hashref($sql);
  }
  return $results;
}
sub DESTROY {
  ### d
  my $self = shift;
  $self->disconnect;
  delete $Hostname_of{$self};
  delete $Port_of{$self};
  delete $Database_of{$self};
  delete $Table_of{$self};
  delete $Username_of{$self};
  delete $Password_of{$self};
}

sub disconnect {
  my $self = shift;
  $self->handle->disconnect();
}

}

1;