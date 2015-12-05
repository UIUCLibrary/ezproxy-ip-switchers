#!/usr/bin/env perl

use strict ;
use warnings ;

use DBI ;

use Text::Template ;
use File::Copy ;

use Getopt::Long ;

my $detailed = 0 ;
my $killmode = 0 ;

GetOptions( 'detailed' => \$detailed,
            'kill' => \$killmode,
        ) ;


#####
## This is a rough beta
## attempt to get a monitor in place
## to watch for a lot of ip address hops and changes
#####

# assumes that ip address is first field in ezproxy.log file
# and last field is session, cause that's how we do it.
#
# at some point should use a library like Text::CSV_XS

# kinda of hack to keep from having to synch logs, just track who we're currenlty blocking
# does this need to be here? or can we just moved it down a level
my @blocked_list ;
if( $killmode) {
    @blocked_list = getBlocked() ;
}

# need to add in log4perl

my $input_filename = $ARGV[0] ;

open my $inf, '<', $input_filename or die "Couldn't open $input_filename\n" ;



# we'll probably want to do soemthing so we 

my $dbh = statsDbConnection() ;

my $insert_row_q =<<"EOQ";
insert into session_ips( ip, session, hashedid)
VALUES (?,?,?)
EOQ


my $insert_row_h
    = $dbh->prepare( $insert_row_q) ;

my $count = 0;
while( my $line = <$inf> ) {
    chomp( $line ) ;

    if( $count % 10000 == 0 ) {
        print "." ;
    } ;

    $count++ ;
    
    if($line =~ /^((?:\d|\.)*).* (.*) (.*)$/ ) {

        my $ip = $1 ;
        my $session = $2 ;
        my $hashedid = $3 ;


        $insert_row_h->execute($ip, $session, $hashedid) ;
    }
    
}

my $ip_change_reporting_threshold = 3 ;
my $ip_change_kill_threshold = 15 ;

my $ip_switchers_q =<<"EOQ";
select hashedid, count(distinct ip) as count_ips
from session_ips
group by hashedid
having count(distinct ip) > $ip_change_reporting_threshold
order by count(distinct ip) desc
EOQ

my $ip_switchers_h = $dbh->prepare( $ip_switchers_q ) ;

$ip_switchers_h->execute() ;

my %targetedIDs = () ;


print "\nSession\tCount\n" ;
while(my $row = $ip_switchers_h->fetchrow_hashref() ) {

    print $row->{hashedid} . "\t" . $row->{count_ips} . "\n" ;

    $targetedIDs{ $row->{hashedid} } = 1 ;

    if( $killmode && $row->{count_ips} >= $ip_change_kill_threshold ) {
        kill_and_block( $dbh, $row->{hashedid} ) ;
    }

    
}

if( $detailed ) {

    print detailed_report($dbh, keys( %targetedIDs )  ) ;
}


sub kill_and_block {

    my $dbh = shift ;
    my $hashedid = shift ;

    # rough plan
    # 1) rewrite shibuser.txt
    #    from template + blocked list + hashedid
    #
    # 2) log ips
    #
    # 3) kill all sessions associated with hashedid, log results
    # 
    # At some point auto-email folks
    addBlocked( $hashedid) ;
    push(@blocked_list, $hashedid ) ;  
    rewrite_shibuser( @blocked_list ) ;
}

sub rewrite_shibuser {

    my @blocked_hashes = @_ ;
    
    my $template = Text::Template->new(TYPE => 'FILE',
                                       SOURCE => 'shibuser.txt.tmpl');
    
    my $text = $template->fill_in(HASH => { 'hashedids' => @blocked_hashes } ) ;


    if(-e 'shibuser.txt' ) {
        copy('shibuser.txt','shibuser.txt.bk') or warn("Couldn't back up shibuser.txt");
    }
    open my $shibuser_f, '>', 'shibuser.txt' or die "Could not open shibuser.txt" ;
    print $shibuser_f $text ;
    close $shibuser_f ;
    
}

sub detailed_report {
    my $dbh = shift ;
    my @targetedIDs = @_ ;

    my $get_ips_q =<<"EOQ";
select distinct ip
from session_ips
where session = ?
order by ip
EOQ

    my $get_ips_h = $dbh->prepare( $get_ips_q ) ;
    
    foreach my $targetedID ( @targetedIDs ) {
        print "\n\n === eduPersonTargetedID $targetedID ips ===  \n\n"  ;

        
        $get_ips_h->execute( $targetedID ) ;
        while( my $ip_row = $get_ips_h->fetchrow_hashref() ) {
            print $ip_row->{ip} . "\n" ;
        }
        print "\n\n === end of eduPersonTargetedID $targetedID ips ===  \n\n" 
    }
}


sub statsDbConnection {

    
    my $dbh = DBI->connect( 'dbi:SQLite:', q{}, q{}, { RaiseError => 1 }) ;
    
    $dbh->do( ' create table session_ips(ip text, session text, hashedid text) ' ) ;

    return $dbh ;

}


sub getBlocked {

    # refactor, config object or something
    my $blocked_filename = "blocked.txt" ;

    
    my @blocked_ids = () ;
    
    if( -e $blocked_filename ) {
        open my $blocked_f, '<' , $blocked_filename or warn(" Something went wrong accessing $blocked_filename, will use empty list of already blocked hashes " ) ;

        while( my $blocked_hashedid = <$blocked_f>) {
            chomp( $blocked_hashedid ) ;
            push(@blocked_ids, $blocked_hashedid ) ;
        }
        close $blocked_f ;
    }

    return @blocked_ids ;
}

sub addBlocked {
    # refactor, config object or something
    my $blocked_filename = "blocked.txt" ;


    my $blocked = shift ;
    open my $blocked_f, '>>', $blocked_filename or warn "Couldn't add to $blocked_filename\n " ;

    print $blocked_f $blocked ."\n" ;

    close $blocked_f ;
}
