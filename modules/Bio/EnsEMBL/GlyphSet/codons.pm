package Bio::EnsEMBL::GlyphSet::codons;

use strict;

use Bio::EnsEMBL::Feature;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self       = shift;
  my $max_length = $self->my_config('threshold') || 50;
  
  # This is the threshold calculation to display the start/stop codon track warning if the track length is too long.
  return $self->errorTrack("Start/Stop codons only displayed for less than $max_length Kb.") unless $self->{'container'}->length <= $max_length * 1000;
  
  foreach (@{$self->features}) {
    $self->push($self->Rect({
      width     => 3,
      height    => 2,
      absolutey => 1,
      %$_
    }));
  }
}

sub features {
  my $self        = shift;
  my $slice       = $self->{'container'};
  my $slice_start = $slice->start;
  my $height      = 3;
  my $padding     = 1;
  my $fullheight  = $height * 2 + $padding;
  my $stop_col    = $self->my_colour('stop')  || 'red';
  my $start_col   = $self->my_colour('start') || 'green';
  my (@codons, @features, $offset, $strand, $base);
  
  if ($self->cache('codon_cache')) { # Reverse strand (2nd to display) so we retrieve information from the codon cache  
    $offset = 3;                              # For drawing loop look at elements 3, 4, 7, 8, 11, 12
    $strand = -1;                             # Reverse strand
    $base   = $height;                        # Start at the bottom
    @codons = @{$self->cache('codon_cache')}; # retrieve data from cache
  } else {
    $offset = 1;                              # For drawing loop look at elements 1, 2, 5, 6, 9, 10
    $strand = 1;                              # Forward strand
    $base   = 0;                              # Start at the top
    
    # As this is the first time around we will have to create the cache in the @data array    
    my $seq = $slice->seq;
      
    # Start/stop codons on the forward strand have value 1/2
    # Start/stop codons on the reverse strand have value 3/4
    my %h = qw(ATG 1 TAA 2 TAG 2 TGA 2 CAT 3 TTA 4 CTA 4 TCA 4);
    
    # The value is used as the index in the array to store the information. 
    # [ For each "phase" this is incremented by 4 ]
    foreach my $phase (0..2) {
      pos($seq) = $phase;
      
      # Perl regexp from hell! Well not really but it's a fun line anyway....      
      #   step through the string three characters at a time
      #   if the three characters are in the h (codon hash) then
      #   we push the co-ordinate element on to the $v'th array in the $data
      #   array. Also update the current offset by 3...
      while ($seq =~ /(...)/g) {
        push @{$codons[$h{$1}]}, pos($seq) - 3 if $h{$1};
      }
      
      $h{$_} += 4 foreach keys %h; # At the end of the phase loop lets move the storage indexes forward by 4
    }
    
    $self->cache('codon_cache', \@codons); # Store the information in the codon cache for the reverse strand
  }
  
  foreach my $phase (0..2) {
    my $index = $offset + $phase * 4;
    
    foreach my $i ($index, $index + 1) {
      foreach (@{$codons[$i]}) {
        push @features, {
          x      => $_,
          y      => $base + ((2 - $phase) * $fullheight) + ($i == $index ? 0 : $height) * $strand,
          start  => $_ + $slice_start,
          end    => $_ + $slice_start + 3,
          colour => $i == $index ? $start_col : $stop_col,
        };
      }
    }
  }
  
  return \@features;
}

1;
