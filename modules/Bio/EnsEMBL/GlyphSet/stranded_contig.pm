package Bio::EnsEMBL::GlyphSet::stranded_contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::contig;
@ISA = qw(Bio::EnsEMBL::GlyphSet::contig);
use Sanger::Graphics::Glyph::Poly;


## We inherit from normal strand-agnostic contig module
## but add arrows when we want to draw in stranded form.
 
sub add_arrows {   
    my ($self, $im_width, $black, $ystart) = @_;
    my $gtriag;    
    
  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h = $res[3];

    $gtriag = new Sanger::Graphics::Glyph::Poly({
    	'points'       => [$im_width-10,$ystart-4, $im_width-10,$ystart, $im_width,$ystart],
	    'colour'       => $black,
    	'absolutex'    => 1,'absolutewidth'=>1,
    	'absolutey'    => 1,
    });
    
    $self->push($gtriag);
    $gtriag = new Sanger::Graphics::Glyph::Poly({
	    'points'       => [0,$ystart+$h+8, 10,$ystart+$h+8, 10,$ystart+$h+12],
    	'colour'       => $black,
    	'absolutex'    => 1,'absolutewidth'=>1,
    	'absolutey'    => 1,
    });
    $self->push($gtriag);
 }   


1;