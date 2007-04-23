use strict;
use warnings;

use Test::More tests => 8;

use_ok( 'URI::Template' );

{
    my $template = URI::Template->new( 'http://{domain}.com/{dir}/{file}.html' );
    isa_ok( $template, 'URI::Template' );
    my %result = $template->deparse( 'http://example.com/test/1.html' );
    is_deeply( \%result, { domain => 'example', dir => 'test', file => '1' }, 'deparse()' );
}

{
    my $template = URI::Template->new( 'http://test.com/{x}/{y}/{x}/{y}' );
    isa_ok( $template, 'URI::Template' );
    my %result = $template->deparse( 'http://test.com/1/2/1/2' );
    is_deeply( \%result, { x => 1, y => 2 }, 'deparse() with multiple values' );
}

{
    my $template = URI::Template->new( 'http://ex.com/{x}' );
    isa_ok( $template, 'URI::Template' );
    my %input = ( x => 'y' );
    my $uri = $template->process( x => 'y' );
    is( $uri, 'http://ex.com/y' );
    my %result = $template->deparse( $uri );
    is_deeply( \%result, \%input, 'process => deparse' );
}
