#!/usr/bin/perl

use strict;
use warnings;

use Term::ANSIColor;
use IO::Socket::SSL;
use WWW::Mechanize;
use Data::Dumper;
use Getopt::Long qw( :config no_ignore_case bundling );
use URI::Split qw( uri_split uri_join );

my ($help, $verbose, $linksfile, $mailsfile, $starturl, $blackout, $count, $strict);
GetOptions(
	'h|help'		=>	\$help,
	'v|verbose+'	=>	\$verbose,
	'S|strict'		=>	\$strict,
	'l|links=s'		=>	\$linksfile,
	'e|mails=s'		=>	\$mailsfile,
	'b|blackout=s'	=>	\$blackout,
	's|starturl=s'	=>	\$starturl,
	'c|count=s'		=>	\$count,
);

&usage if ($help);

my (%new_urls, %blackouts, %processed_urls, %emails);
my ($base_url);

if ((!defined($linksfile)) or ($linksfile eq '')) { 
	print "You must specify the file to save links.\n";
	&usage;
}
if ((!defined($mailsfile)) or ($mailsfile eq '')) {
	print "You must specify the file to save mails.\n";
	&usage;
}
if ((defined($starturl)) and ($starturl ne '')) {
	$new_urls{$starturl}++;
} else {
	print "You must specify a starting URL!\n";
	&usage;
}
if ($strict) {
	my ($scheme, $auth, $path, $query, $frag) = uri_split($starturl);
	$base_url = $auth;
}
if ($verbose) { print colored("Base URL: $base_url\n", "bold cyan"); }

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
$mech->agent_alias('Windows Mozilla');

while (scalar(keys(%new_urls)) > 0) {
	my $thisurl = (keys(%new_urls))[0];
	delete($new_urls{$thisurl});
	next if (exists($processed_urls{$thisurl}));
	if ($strict) { 
		if (($thisurl =~ m@^http://@) and ($thisurl !~ /$base_url/)) {
			print color('bold green');
			print "Base URL not found in this URL.  Skipping...\n";
			print "$thisurl\n";
			print color("reset");
			next;
		}
	}
	next if ($thisurl =~ /^\#/);
	next if ($thisurl =~ /javascript/);
	print "Processing $thisurl\...\n";
	my ($scheme, $auth, $path, $query, $frag) = uri_split($thisurl);
	no warnings;
	#print colored("S: $scheme ", "green");
	#print colored("A: $auth ", "yellow");
	#print colored("P: $path ", "magenta");
	#print colored("Q: $query ", "red");
	#print colored("F: $frag\n", "cyan");
	$path =~ s@///?@/@g;
	my $repack = uri_join($scheme, $auth, $path, $query, $frag);
	use warnings;
	#print colored("$repack\n", "bright_yellow");
	eval { $mech->get($thisurl); };
	if ($mech->success) {
		$processed_urls{$thisurl}++;
		# get all the links
		my @links = $mech->find_all_links();
		if ($verbose) { print "Got ".scalar(@links)." links from URL.\n"; }
		foreach my $link ( @links ) {
			print $link->url."\n" if ($verbose);
			if ($link->url =~ /^\//) {
				# skip same-page links
				next if ($link->url =~ /^\#/);
				# skip "root" links
				next if ($link->url =~ /^\/$/);
				$new_urls{$link->base."".$link->url}++;
			} else {
				$new_urls{$link->url}++;
			}
		}
		if ($verbose) { print scalar(keys(%new_urls))." new URLs after processing.\n"; }
		# get all the emails
		foreach my $line ( $mech->content ) {
			if ($line =~ /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/) {
				my $m = $1;
				$emails{$m}++;
			}
		}
	} else {
		print colored("HTTP CODE: ".$mech->status." \n", "red");
		warn colored("There was a problem GET'ing the requested URL.", "red");
	}
	print scalar(keys(%emails))." email addresses harvested so far.\n";
	if ($verbose) {
		print color('bright_cyan');
		print Dumper(\%new_urls);
		print color('reset');
	}
	last if (($count) and (scalar(keys(%emails)) >= $count));
}

END {
	print "In the END block....\n";
	print "Got ".scalar(keys(%processed_urls))." unique URLs processed.\n";
	open FILE, ">$linksfile" or die "There was a problem opening the links file ($linksfile) for writing: $!";
	foreach my $p ( sort keys %processed_urls ) {	print FILE "$p\n"; }
	close FILE or die "There was a problem closing the links file: $!";

	print "Got ".scalar(keys(%emails))." unique email addresses found.\n";
	open FILE, ">$mailsfile" or die "There was a problem opening the mails file ($mailsfile) for writing: $!";
	foreach my $m ( sort keys %emails ) { print FILE "$m\n"; }
	close FILE or die "There was a problem closing the mails file: $!";
}

###############################################################################
###	Subs
###############################################################################
sub usage {
	print <<END;
	
$0 -h|--help -v|--verbose -l|--links <links output> -e|--mails <mails output> -s|--starturl <starturl>

-h|--help			Display this message and exit.
-v|--verbose			Increase verbosity.
-l|--links			Specifies the path to the file to which discovered links will be written.
-e|--mails			Specifies the path to the file to which discovered emails will be written.
-b|--blackout			Specifies the path to the file containing expressions to be excluded.
-s|--starturl			Specifies the URL to begin crawling.

END
	exit 0;
}

sub dump_findings {
	open FILE, ">$linksfile" or die "There was a problem opening the links file for writing: $!";
	foreach my $p ( sort keys %processed_urls ) {	print FILE "$p\n"; }
	close FILE or die "There was a problem closing the links file: $!";

	open FILE, "$mailsfile" or die "There was a problem opening the mails file for writing: $!";
	foreach my $m ( sort keys %emails ) { print FILE "$\m"; }
	close FILE or die "There was a problem closing the mails file: $!";
}

