package EnsEMBL::Web::Component::StructuralVariation::Summary;

use strict;

use base qw(EnsEMBL::Web::Component::StructuralVariation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self                = shift;
  my $hub                 = $self->hub;
  my $object              = $self->object;
	my $sv_obj              = $object->Obj;
  my $name                = $object->name;
  my $class               = $object->class;
  my $source              = $object->source;
  my $source_description  = $object->source_description;
	my $states              = $object->validation_status;
	my $html;
	
	my %mappings = %{$object->variation_feature_mapping};
  
	# SV name
	$name = qq{<dt>Variation class</dt><dd>$class ($name)</dd>};
	
	# Allele type(s);
	my $allele_types = $self->get_allele_types($source);
	
  # Study
  my $study = $self->get_study;
	
	# Validation status
	my $vstates = $self->get_validation_status($states);
	
	$html .= qq{<dl class="summary">};
	$html .= $name;                                          # SV name
  $html .= $allele_types if ($allele_types);               # Allele type(s)
  $html .= $self->get_source($source,$source_description); # Source
  $html .= $study if ($study);                             # Study
	$html .= $self->location(\%mappings);                    # Location
	$html .= $self->size(\%mappings);                        # Genomic size
	$html .= $vstates if ($vstates);                         # Validation status
	$html .= qq{</dl>};
	return $html;
}


# Method to add a pubmed link to the expression "PMID:xxxxxxx"
# in the source or study description, if it is present.
sub add_pubmed_link{
	my $self          = shift;
	my $s_description = shift;
	my $hub = $self->hub;
	
	if($s_description =~/PMID/){ 
		my @temp = split('\s', $s_description);
    foreach (@temp ){
			if ($_ =~/PMID/){
      	my $pubmed_id = $_; 
        my $id = $pubmed_id;  
        $id =~s/PMID\://; 
        my $pubmed_url = $hub->get_ExtURL_link($pubmed_id, 'PUBMED', $id); 
        $s_description =~s/$_/$pubmed_url/;
			}
		}
 	}
	return $s_description;
}


# Returns the list of the allele types (supporting evidence classes) with the associate colour
sub get_allele_types {
	my $self   = shift;
	my $source = shift;
	my $html;
	
	return $html if ($source ne 'DGVa');
	
	my $object = $self->object;
	
	my $ssvs = $object->supporting_sv;
	my @allele_types;
	
	foreach my $ssv (@$ssvs) {
		my $SO_term = $ssv->class_SO_term;
		if (!grep {$ssv->class_SO_term eq $_} @allele_types) {
			push (@allele_types, $SO_term);
			my $colour = $object->get_class_colour($SO_term);
			my $class  = $ssv->var_class;
			$html .= qq{<td style="width:5px"></td>} if (defined($html));
			$html .= qq{
									<td style="vertical-align:middle">
										<table style="border-spacing:0px"><tr><td style="background-color:$colour;width:7px;height:7px"></td></tr></table>
									</td>
									<td style="padding-left:2px">$class</td>
								 };
		}
	}
	if (defined($html)) {
		$html = qq{<dt>Allele type(s)</dt><dd><table style="border-spacing:0px"><tr>$html</tr></table></dd>\n};
	}
	return $html;
}


sub get_source {
	my $self   = shift;
	my $source = shift; 
	my $description = shift;
	
	my $hub = $self->hub;

	my $source_link = $source;
	if ($source eq 'DGVa') {
	 $source_link = $hub->get_ExtURL_link($source, 'DGVA', $source);
 	}
	elsif ($source =~ /affy/i ) {
		$source_link = $hub->get_ExtURL_link($source, 'AFFYMETRIX', $source);
	}
	elsif ($source =~ /illumina/i) {
		$source_link = $hub->get_ExtURL_link($source, 'ILLUMINA', $source);
	}
	
  $description = $self->add_pubmed_link($description);
  
	$source = "$source_link - $description";
	
	return qq{<dt>Source</dt><dd>$source</dd>};
}


sub get_study {
	my $self = shift;
	my $object = $self->object;
	my $hub    = $self->hub;
	
	my $study_name = $object->study_name;
	return '' if (!$study_name);
	
  my $study_description = $self->add_pubmed_link($object->study_description, $hub);
  my $study_line = sprintf ('<a href="%s">%s</a>',$object->study_url,$study_name);
  
	return  qq{<dt>Study</dt><dd>$study_line - $study_description</dd>};
}


sub location { 
	my $self     = shift;
	my $mappings = shift;
  my $object   = $self->object;
  my $count    = scalar keys (%$mappings);
  
  return '<dl class="summary"><dt>Location</dt><dd>This feature has not been mapped.</dd></dl>' unless $count;
  
	my $hub  = $self->hub;
  my $svf  = $hub->param('svf');
  my $name = $object->name;
  my ($location_link,$html,$location,$region,$start,$end);
 
 	if ($count > 1) {
    my $params = $hub->core_params;
    my @values;
    
    # create form
    my $form = $self->new_form({
      name   => 'select_loc',
      action => $hub->url({ svf => undef, sv => $name, source => $object->source }), 
      method => 'get', 
      class  => 'nonstd check'
    });
    
    push @values, { value => 'null', name => 'None selected' }; # add default value
    
    # add values for each mapping
    foreach (sort { $mappings->{$a}->{'Chr'} cmp $mappings->{$b}->{'Chr'} || $mappings->{$a}->{'start'} <=> $mappings->{$b}->{'start'}} keys (%$mappings)) {
      $region = $mappings->{$_}{'Chr'}; 
      $start  = $mappings->{$_}{'start'};
      $end    = $mappings->{$_}{'end'};
      my $str = $mappings->{$_}{'strand'};
      
      push @values, {
        value => $_,
        name  => sprintf('%s (%s strand)', ($start == $end ? "$region:$start" : "$region:$start-$end"), ($str > 0 ? 'forward' : 'reverse'))
      };
    }
    
    # add dropdown
    $form->add_element(
      type   => 'DropDown',
      select => 'select',
      name   => 'svf',
      values => \@values,
      value  => $svf,
    );
    
    # add submit
    $form->add_element(
      type  => 'Submit',
      value => 'Go',
    );
    
    # add hidden values for all other params
    foreach (grep defined $params->{$_}, keys %$params) {
      next if $_ eq 'svf' || $_ eq 'r'; # ignore svf and region as we want them to be overwritten
      
      $form->add_element(
        type  => 'Hidden',
        name  => $_,
        value => $params->{$_},
      );
    }
    
    $html = "This feature maps to $count genomic locations" . $form->render;                    # render to string
    $html =~ s/\<\/?(div|tr|th|td|table|tbody|fieldset)+.*?\>\n?//g;                            # strip off unwanted HTML layout tags from form
    $html =~ s/\<form.*?\>/$&.'<span style="font-weight: bold;">Selected location: <\/span>'/e; # insert text
  }    
  
  if ($svf) {
    $region   = $mappings->{$svf}{'Chr'}; 
    $start    = $mappings->{$svf}{'start'};
    $end      = $mappings->{$svf}{'end'};
    $location = ($start == $end ? "$region:$start" : "$region:$start-$end") . ' (' . ($mappings->{$svf}{'strand'} > 0 ? 'forward' : 'reverse') . ' strand)';
    
    $location_link = sprintf(
      ' | <a href="%s">View in location tab</a>',
      $hub->url({
        type              => 'Location',
        action            => 'View',
        r                 => $region . ':' . ($start - 500) . '-' . ($end + 500),
        sv                => $name,
        svf               => $svf,
        contigviewbottom  => 'variation_feature_structural=normal'
			})
    );
  }
	
	
  if ($count == 1) {
    $html .= "This feature maps to $location$location_link";
		my $current_svf = $mappings->{$svf};
		$html .= $self->get_outer_coordinates($current_svf);
		$html .= $self->get_inner_coordinates($current_svf);
  } else {
    $html =~ s/<\/form>/$location_link<\/form>/;
  }
	
  return qq{<dt>Location</dt><dd>$html</dd>};
} 


sub get_outer_coordinates {
	my $self   = shift;
	my $svf    = shift;
	
	my $region      = $svf->{'Chr'};
	my $outer_start = defined($svf->{'outer_start'}) ? $svf->{'outer_start'} : $svf->{'start'};
	my $outer_end   = defined($svf->{'outer_end'}) ? $svf->{'outer_end'} : $svf->{'end'};
	
	if ($outer_start == $svf->{'start'} and $outer_end == $svf->{'end'}) {
		return '';
	}
	else {
		return qq{<br />Outer coordinates: $region:$outer_start-$outer_end};
	}
}


sub get_inner_coordinates {
	my $self   = shift;
	my $svf    = shift;
	
	my $region      = $svf->{'Chr'};
	my $inner_start = defined($svf->{'inner_start'}) ? $svf->{'inner_start'} : $svf->{'start'};
	my $inner_end   = defined($svf->{'inner_end'}) ? $svf->{'inner_end'} : $svf->{'end'};
	
	if ($inner_start == $svf->{'start'} and $inner_end == $svf->{'end'}) {
		return '';
	}
	else {
		return qq{<br />Inner coordinates: $region:$inner_start-$inner_end};
	}
}


# SV size (format the size with comma separations, e.g: 10000 to 10,000)
sub size {
	my $self     = shift; 
	my $mappings = shift;
	
	my $hub   = $self->hub;
	my $svf   = $hub->param('svf');
	my $count = scalar keys (%$mappings);
	
	my $html = '';
	if ($count == 1 || $svf) {
		my $sv_size = ($mappings->{$svf}{end}-$mappings->{$svf}{start}+1);
		my $int_length = length($sv_size);
		if ($int_length>3){
			my $nb = 0;
			my $int_string = '';
			while (length($sv_size)>3) {
				$sv_size =~ /(\d{3})$/;
				if ($int_string ne '') {	$int_string = ','.$int_string; }
				$int_string = $1.$int_string;
				$sv_size = substr($sv_size,0,(length($sv_size)-3));
			}	
			$sv_size = "$sv_size,$int_string";
		}
		$html = qq{<dt>Genomic size</dt>\n<dd>$sv_size bp</dd>\n};
	}
	return $html;
}


# Validation status
sub get_validation_status {
	my $selft  = shift;
	my $states = shift;
	
	my $html = '';
	if ($states) {
		$html = qq{<dt>Validation status</dt><dd>$states</dd>};
	}
	return $html;
}
1;
