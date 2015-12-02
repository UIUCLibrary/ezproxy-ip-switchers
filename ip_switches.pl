#!/usr/bin/env perl

use strict ;
use warnings ;

use DBI ;


#####
## This is a rough beta
## attempt to get a monitor in place
## to watch for a lot of ip address hops and changes
#####

# assumes that ip address is first field in ezproxy.log file
# and last field is session, cause that's how we do it.
#
# at some point should use a library like Text::CSV_XS


# need to add in log4perl

my $input_filename = $ARGV[0] ;

open my $inf, '<', $input_filename or die "Couldn't open $input_filename\n" ;



# we'll probably want to do soemthing so we 

my $dbh = statsDbConnection() ;

my $insert_row_h
    = $dbh->prepare("insert into session_ips( ip, session) VALUES (?,?)") ;

my $count = 0;
while( my $line = <$inf> ) {
    chomp( $line ) ;

    if( $count % 10000 == 0 ) {
        print "." ;
    } ;

    $count++ ;
    
    if($line =~ /^((?:\d|\.)*).* (.*$)/ ) {

        my $ip = $1 ;
        my $session = $2 ;
        $insert_row_h->execute($ip, $session) ;
        
    }
    
}

my $ip_change_threshold = 3 ;

my $ip_switchers_q =<<"EOQ";
select session, count(distinct ip) as count_ips
from session_ips
group by session
having count(distinct ip) > $ip_change_threshold
order by count(distinct ip) desc
EOQ

my $ip_switchers_h = $dbh->prepare( $ip_switchers_q ) ;

$ip_switchers_h->execute() ;


print "\nSession\tCount\n" ;
while(my $row = $ip_switchers_h->fetchrow_hashref() ) {
    use Data::Dumper ;
    print $row->{session} . "\t" . $row->{count_ips} . "\n" ;
}




sub statsDbConnection {

    
    my $dbh = DBI->connect( 'dbi:SQLite:', q{}, q{}, { RaiseError => 1 }) ;
    
    $dbh->do( ' create table session_ips(ip text, session text) ' ) ;

    return $dbh ;

}
