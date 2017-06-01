#!/usr/bin/perl

use strict;
use warnings;

use WWW::Mechanize;

use Getopt::Long qw( no_ignore_case bundling );

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
