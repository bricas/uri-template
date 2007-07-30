use strict;
use warnings;

use Test::More tests => 25;

use_ok( 'URI::Template' );

# fatal - no template provided
{
   eval { URI::Template->new; };
   ok( $@ );
}

{
    my $text     = 'http://foo.com/{bar}/{baz}?q=%7B';
    my $template = URI::Template->new( $text );
    isa_ok( $template, 'URI::Template' );
    is_deeply( [ sort $template->variables ], [ qw( bar baz ) ], 'variables()' );
    is( "$template", $text, 'as_string()' );

    {
        my $result = $template->process( bar => 'x', baz => 'y' );
        is( $result, 'http://foo.com/x/y?q=%7B', 'process()' );
        isa_ok( $result, 'URI', 'return value from process() isa URI' );
    }
    {
        my $result = $template->process_to_string( bar => 'x', baz => 'y' );
        is( $result, 'http://foo.com/x/y?q=%7B', 'process_to_string()' );
        ok( !ref $result, 'result is not a ref' );
    }
}

{
    my $template = URI::Template->new( 'http://foo.com/{z(}/' );
    my $result = $template->process( 'z(' => 'x' );
    is( $result, 'http://foo.com/x/', 'potential regex issue escaped' );
}

{
    my $template = URI::Template->new( 'http://foo.com/{z}/' );
    {
        my $result = $template->process( 'z' => '{x}' );
        is( $result, 'http://foo.com/%7Bx%7D/', 'values are uri escaped' );
    }
    {
        my $result = $template->process( );
        is( $result, 'http://foo.com//', 'no value sent' );
    }
    {
        my $result = $template->process( 'y' => '1' );
        is( $result, 'http://foo.com//', 'no valid keys used' );
    }
}

# test from spec
{
    my %vals = (
        a => 'fred',
        b => 'barney',
        c => 'cheeseburger',
        d => 'one two three',
        e => '20% tricky',
        f => '',
        20 => 'this-is-spinal-tap',
        scheme => 'https',
        p => 'quote=to+be+or+not+to+be',
        q => 'hullo#world',
    );

    my @urls = (
        [ (
            'http://example.org/page1#{a}',
            'http://example.org/page1#fred',
        ) ],
        [ (
            'http://example.org/{a}/{b}/',
            'http://example.org/fred/barney/',
        ) ],
        [ (
            'http://example.org/{a}{b}/',
            'http://example.org/fredbarney/',
        ) ],
        [ (
            'http://example.com/order/{c}/{c}/{c}/',
            'http://example.com/order/cheeseburger/cheeseburger/cheeseburger/',
        ) ],
        [ (
            'http://example.org/{d}',
            'http://example.org/one%20two%20three',
        ) ],
        [ (
            'http://example.org/{e}',
            'http://example.org/20%25%20tricky',
        ) ],
        [ (
            'http://example.com/{f}/',
            'http://example.com//',
        ) ],
        [ (
            '{scheme}://{20}.example.org?date={wilma}&option={a}',
            'https://this-is-spinal-tap.example.org?date=&option=fred',
        ) ],
        [ (
            'http://example.org?{p}',
            'http://example.org?quote=to+be+or+not+to+be',
        ) ],
        [ (
            'http://example.com/{q}',
            'http://example.com/hullo#world',
        ) ],
    );

    for my $list ( @urls ) {
        my $template = URI::Template->new( $list->[ 0 ] );
        my $result = $template->process( %vals );
        is( $result, $list->[ 1 ], 'escaped properly' );
    }
}

{
    my $template = URI::Template->new( 'http://foo.com/{z}/{z}/' );
    is_deeply( [ $template->variables ], [ 'z' ], 'unique vars' );
    my $result = $template->process( 'z' => 'x' );
    is( $result, 'http://foo.com/x/x/', 'multiple replaces' );
}

