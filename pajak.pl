#!/usr/bin/perl

use strict;
use warnings;

use Term::ANSIColor;
use IO::Socket::SSL;
use WWW::Mechanize;
use Data::Dumper;
use Getopt::Long qw( :config no_ignore_case bundling );

my ($help, $verbose, $linksfile, $mailsfile, $starturl, $blackout);
GetOptions(
	'h|help'		=>	\$help,
	'v|verbose+'	=>	\$verbose,
	'l|links=s'		=>	\$linksfile,
	'e|mails=s'		=>	\$mailsfile,
	'b|blackout=s'	=>	\$blackout,
	's|starturl=s'	=>	\$starturl,
);

&usage if ($help);

my (@new_urls);
my (%blackouts, %processed_urls, %emails);

if ((!defined($linksfile)) or ($linksfile eq '')) { 
	print "You must specify the file to save links.\n";
	&usage;
}
if ((!defined($mailsfile)) or ($mailsfile eq '')) {
	print "You must specify the file to save mails.\n";
	&usage;
}
if ((defined($starturl)) and ($starturl ne '')) {
	push @new_urls, $starturl;
} else {
	print "You must specify a starting URL!\n";
	&usage;
}
if ((defined($blackout)) and ($blackout ne '')) {
	open FILE, "<$blackout" or die "There was a problem opening the blackouts file: $!";
	while (<FILE>) { chomp(); $blackouts{$_}++; }
	close FILE or die "There was a problem closing the blackouts file: $!";
}

my $mech = WWW::Mechanize->new(
	ssl_opts => {
		SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE,
		verify_hostname => 0,
	},
);

while (scalar(@new_urls) > 0) {
	my $thisurl = shift @new_urls;
	next if ($thisurl =~ /^\#/);
	next if ($thisurl =~ /javascript/);
	print "Processing $thisurl\...\n";
	$mech->get($thisurl);
	if ($mech->success) {
		# get all the links
		my @links = $mech->find_all_links();
		#print Dumper(\@links);
		foreach my $link ( @links ) {
			if ($link->url =~ /^\//) {
				# skip same-page links
				next if ($link->url =~ /^\#/);
				# skip "root" links
				next if ($link->url =~ /^\/$/);
				push @new_urls, $link->base."/".$link->url;
			} else {
				push @new_urls, $link->url;
			}
		}
		# get all the emails
		foreach my $line ( $mech->content ) {
			if ($line =~ /([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})/) {
				my $m = $1;
				$emails{$m}++;
			}
		}
	}
}

###############################################################################
###	Subs
###############################################################################
sub usage {
	print <<END;
	
$0 -h|--help -v|--verbose -l|--links <links output> -e|--mails <mails output> -s|--starturl <starturl>

-h|--help			Display this message and exit.
-v|--verbose		Increase verbosity.
-l|--links			Specifies the path to the file to which discovered links will be written.
-e|--mails			Specifies the path to the file to which discovered emails will be written.
-b|--blackout		Specifies the path to the file containing expressions to be excluded.
-s|--starturl		Specifies the URL to begin crawling.

END
	exit 0;
}

