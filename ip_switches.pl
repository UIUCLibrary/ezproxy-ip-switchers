#!/usr/bin/env perl

use strict ;
use warnings ;

use DBI ;

use POSIX;

use Getopt::Long ;

use ShibBlock ;

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

    my $shib_block = ShibBlock->new() ;
    @blocked_list = $shib_block->getBlocked() ;
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
my %sentencedIDs = () ;

print "\nSession\tCount\n" ;
while(my $row = $ip_switchers_h->fetchrow_hashref() ) {

    print $row->{hashedid} . "\t" . $row->{count_ips} . "\n" ;

    $targetedIDs{ $row->{hashedid} } = 1 ;

    if( $killmode && $row->{count_ips} >= $ip_change_kill_threshold ) {
        $sentencedIDs{ $row->{hashedid} } = 1 ;
    }
}


if( $detailed ) {

    print detailed_report($dbh, keys( %targetedIDs )  ) ;
}


if( $killmode ) {
    kill_and_block($dbh,  keys %sentencedIDs ) ;
}

    


# make this operate on list easier?
sub kill_and_block {

    my $dbh = shift ;
    my @sentenced = @_ ;

    my $log_path = 'ip_switches.log' ;
    open my $log_fh, '>>', $log_path or warn("Can't log to $log_path") ; 
 
    
    # rough plan
    # 1) rewrite shibuser.txt
    #    from template + blocked list + hashedid
    #
    # 2) log ips
    #
    # 3) kill all sessions associated with hashedid, log results
    #
    # At some point auto-email folks
    #
    my $shib_block = ShibBlock->new() ;

    my %prev_sentenced = map
                        { $_ => 1 }
                        ($shib_block->getBlocked()) ;
        
    my @new_sentenced = grep { !($prev_sentenced{ $_ }) } @sentenced ;

    if (@new_sentenced ) {
        # need to add log4per
        my $log_path = 'blocks.log' ;
        print $log_fh  strftime("%Y-%m-%d %H:%M:%S", localtime(time))
                      . " adding blocks " .  join(q{,},@new_sentenced) . "\n" ;
        
        
        $shib_block->addBlocks( @new_sentenced ) ;
        $shib_block->rewrite_shibuser() ;
    }

    # now for good measure, nuke any session from blocked sessions, even old ones

    my $session_ids_q =<<"EOQ";
select distinct session from session_ips where hashedid = ?
EOQ
    my $session_ids_h = $dbh->prepare( $session_ids_q );
    HAHSEDID: foreach my $hash ( $shib_block->getBlocked() ) {
        $session_ids_h->execute( $hash );
        SESSION: while( my $session_info = $session_ids_h->fetchrow_hashref() ) {
              my $session_id = $session_info->{session} ;
              if($session_id eq '-' || $session_id =~ /^\s*$/
                     || $hash eq '-' || $hash =~ /^\s$$/ ) {
                  next SESSION ;
              }
              my $cmd = "../ezproxy kill $session_id" ; 
              print  $cmd . "\n " ;
              my $kill_result = `$cmd`;
              print $kill_result . "\n" ;
              print $log_fh  strftime("%Y-%m-%d %H:%M:%S", localtime(time))
                          . "Killing $session_id for $hash, result was "
                          . $kill_result . "\n" ;
        }
    }
    close $log_fh ;
 
}


sub detailed_report {
    my $dbh = shift ;
    my @targetedIDs = @_ ;

    my $get_ips_q =<<"EOQ";
select distinct ip
from session_ips
where hashedid = ?
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


