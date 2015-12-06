#!/usr/bin/env perl

# should make an actual module, but for
# now just using ShibBlock::

package ShibBlock ;

use strict ;
use warnings ;

use Text::Template ;
use File::Copy ;



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


      
    my @blocked_hashes = @_ ;
    
    my $template = Text::Template->new(TYPE => 'FILE',
                                       SOURCE => 'shibuser.txt.tmpl');
    
    my $text = $template->fill_in(HASH => { 'hashedids' => \@blocked_hashes } ) ;


    if(-e 'shibuser.txt' ) {
        copy('shibuser.txt','shibuser.txt.bk') or warn("Couldn't back up shibuser.txt");
    }
    open my $shibuser_f, '>', 'shibuser.txt' or die "Could not open shibuser.txt" ;
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

    return @blocked_ids ;
}

sub addBlocked {
    my $self = shift ;

    my @blocked = @_ ;
    open my $blocked_f, '>>', $self->{blocked_filename} or warn "Couldn't add to $self->{blocked_filename}\n " ;
    foreach my $blocked_hashid (@blocked) {
        print $blocked_f $blocked_hashid ."\n" ;
    }
    close $blocked_f ;
}
1;
