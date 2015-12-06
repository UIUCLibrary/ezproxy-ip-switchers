#!/usr/bin/env perl

# should make an actual module, but for
# now just using ShibBlock::

package ShibBlock ;

use strict ;
use warnings ;

use Text::Template ;
use File::Copy ;

use List::MoreUtils qw(uniq);

sub new {
    my $class = shift;
    my $blocked_filename = shift ;
    if( ! defined( $blocked_filename ) ) {
        $blocked_filename = "blocked.txt" ;
    }
    
    my $self = bless {
        blocked_filename => $blocked_filename,
    }, $class;
    return $self;
}


sub rewrite_shibuser {

    my $self = shift ;
    my $filename = 'shibuser.txt' ;
       
    my @blocked_hashes = $self->getBlocked() ;
    
    
    my $template = Text::Template->new(TYPE => 'FILE',
                                       SOURCE => 'shibuser.txt.tmpl');

    use Data::Dumper ;

    my $vars = { hashedids => \@blocked_hashes };
    my $text = $template->fill_in(HASH => $vars ) ;
    if(-e $filename) {
        copy($filename,$filename . '.bk' ) or warn("Couldn't back up $filename");
    }
    open my $shibuser_f, '>', $filename or die "Could not open $filename" ;
    print $shibuser_f $text ;
    close $shibuser_f ;
    
}


sub getBlocked {
    my $self = shift ;

    # refactor, config object or something

    
    my @blocked_ids = () ;
    
    if( -e $self->{blocked_filename} ) {
        open my $blocked_f, '<' , $self->{blocked_filename} or warn(" Something went wrong accessing $self->{blocked_filename}, will use empty list of already blocked hashes " ) ;

        while( my $blocked_hashedid = <$blocked_f>) {
            chomp( $blocked_hashedid ) ;
            push(@blocked_ids, $blocked_hashedid ) ;
        }
        close $blocked_f ;
    }

    return $self->_cleanBlockList( @blocked_ids );
}


# probably shoudl do some dedup and the like on both the way in and the way out...

sub addBlocks {
    my $self = shift ;

    # could use grep too later..
    my @prev_blocked = $self->getBlocked() ;
    
    my @blocked = @_ ;

    @blocked = $self->_cleanBlockList( @blocked ) ;
    
    open my $blocked_f, '>>', $self->{blocked_filename} or warn "Couldn't add to $self->{blocked_filename}\n " ;
    foreach my $blocked_hashid (@blocked) {
        if( ! ( grep {$blocked_hashid eq $_ } @prev_blocked ) ) { 
            print $blocked_f $blocked_hashid ."\n" ;
        }
    }
    close $blocked_f ;
}

sub _cleanBlockList {
    my $self = shift ;

    my @blocks = @_ ;
    return grep { !( $_ eq '-') }
           grep { !( $_ =~ /^\s*$/ ) }
           uniq @blocks ;
}
1;
