#!/usr/bin/env perl

use strict ;
use warnings ;

use Test::More ;

use lib '..' ;

use ShibBlock ;


writeTestFile( 'block.txt' ) ;

my $shibblock = ShibBlock->new( 'test' ) ;

my @sorted_blocked = sort $shibblock->getBlocked() ;

my @expected_block = ('alicealicealice',
                      'alqksdjflaskj141?=\asldf=',
                      'bobbobbob' ) ;

is_deeply(\@sorted_blocked, \@expected_block, "Reading from block list" ) ;



done_testing() ;


sub writeTestFile {
    
    my $block_list_path = shift ;
    open my $block_list_fh, '>', $block_list_path or die "Can't prepare $block_list_path\n" ;

    my $block_file_contents =<<"EOC";
bobbobbob
alicealicealice
alqksdjflaskj141?=\asldf=
EOC

    print $block_list_fh $block_file_contents ;
}
