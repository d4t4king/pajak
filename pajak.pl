#!/usr/bin/perl

use strict;
use warnings;

use Term::ANSIColor;
use WWW::Mechanize;
use Data::Dumper;
use Getopt::Long qw( :config no_ignore_case bundling );

my ($help, $verbose, $linksfile, $mailsfile, $starturl);
GetOptions(
	'h|help'		=>	\$help,
	'v|verbose+'	=>	\$verbose,
	'l|links=s'		=>	\$linksfile,
	'e|mails=s'		=>	\$mailsfile,
	's|starturl=s'	=>	\$starturl,
);

my (@new_urls);

my $mech = WWW::Mechanize->new();

if ((defined($starturl)) and ($starturl ne '')) {
	push @new_urls, $starturl;
} else {
	die "You must specify a starting URL!";
}

while (scalar(@new_urls) > 0) {
	my $thisurl = shift @new_urls;
	$mech->get($thisurl);
	if ($mech->success) {
		my @links = $mech->find_all_links();
		#print Dumper(\@links);
	}
}
