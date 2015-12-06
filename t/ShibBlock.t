#!/usr/bin/env perl

use strict ;
use warnings ;

use Test::More ;

use lib '..' ;

use ShibBlock ;


my $blocked_file_path  = 'test_blocked.txt' ; 
writeTestFile( $blocked_file_path ) ;

my $shib_block = ShibBlock->new( $blocked_file_path ) ;

my @sorted_blocked = sort $shib_block->getBlocked() ;

my @expected_block = ('alicealicealice',
                      'alqksdjflaskj141?=\\asldf=',
                      'bobbobbob' ) ;

is_deeply(\@sorted_blocked, \@expected_block, "Reading from block list" ) ;

#
#my @new_blocks = qw(zia2341 barcka) ;#
#
#@sorted_blocked = sort $shib_block->getBlocked() ;#
#
#@expected_block = ('alicealicealice',
#                   'alqksdjflaskj141?=\asldf=',
#                   'barcka',
#                   'bobbobbob',
#                   'zia') ;
#
#is_deeply(\@sorted_blocked, \@expected_block, "added to  block list" ) ;
##
#
#$shib_block->addBlocks( @new_blocks ) ;

unlink( 'block.txt' ) ;

done_testing() ;


sub writeTestFile {
    
    my $block_list_path = shift ;
    open my $block_list_fh, '>', $block_list_path or die "Can't prepare $block_list_path\n" ;

    my $block_file_contents =<<'EOC';
bobbobbob
alicealicealice
alqksdjflaskj141?=\asldf=
EOC

    print $block_list_fh $block_file_contents ;
}
