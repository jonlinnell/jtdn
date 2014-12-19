#!/usr/bin/env perl

# jtdn
#
# Tweet scraper. Plug one end into Twitter, the other into an SQLite database, and turn on the power.

use strict;
use utf8;

no warnings 'utf8';
 
use AnyEvent::Twitter::Stream;
use Log::Minimal;
use DBI;
use Getopt::Long;

$Log::Minimal::AUTODUMP = 1;
$Log::Minimal::COLOR = 1;

#######  DATABASE SETTINGS  #######
my %db_attr =
(
	PrintError 			=> 0,
	RaiseError 			=> 1,
	mysql_enable_utf8 	=> 1
);

my $table_seed_sql =
	"CREATE TABLE tweets
	(
		username		VARCHAR(48) not null,
		fullname		VARCHAR(64),
		timestamp_ms	BIGINT,
		tweet_id		VARCHAR(20),
		text			VARCHAR(160)
	);";

#	jtdn creates a 160-character field for storing Tweet text, in order not to truncate the text in the case of
#	a badly interpretted HTML character or something.

###################################

my $usage = "Usage: ".$0."\n
   [--config path]\t- Specifies OAuth config file.   Default: ./auth.conf
   --db path\t\t- Specifies output SQLite database. Currently mandatory.
   --keywords keywords\t- Search keywords.
   [--monitor]\t\t- Print Tweets to STDOUT in realtime.
   [--no-rt]\t\t- Omit quote retweets (i.e. any tweet that begins with 'RT @'.)\n\nSee README for more information.\n\n";

my $config_file = 'auth.conf';
my $keywords;
my $db_file;
my $monitor;
my $no_rt;

GetOptions
	(
		"config=s"	=> 	\$config_file,
		"db=s"		=>	\$db_file,
		"keywords=s" => \$keywords,
		"monitor"	=> 	\$monitor,
		"no-rt"		=>	\$no_rt
	)
	or die $usage;

die $usage unless defined $keywords;
die $usage unless defined $db_file;

my $config = do $config_file or die "Can't load $config_file : $!$@";

die "You must acquire a Twitter API token before using this program.\n\n" unless defined $config->{token_secret};

my $dsn = "DBI:SQLite:dbname=".$db_file;

###################################
########## END OF CONFIG ##########
###################################

unless (-e $db_file)
{
	my $newdb;

	open ($newdb, '>>', $db_file)
		or die "$db_file: Could not create database file: $!\n\n";

	close $newdb;

	my $dbh_new = DBI->connect($dsn, "", "", \%db_attr);

	my $dbquery = $dbh_new->do($table_seed_sql);

	if ( $dbquery < 0 )
	{
		print $DBI::errstr;
	}
	else
	{
		print "Table created successfully\n";
	}
	
	$dbh_new->disconnect;
} 

my $dbh = DBI->connect($dsn, "", "", \%db_attr);
 
my $done = AnyEvent->condvar;

###################################
######### BEGIN LISTENING #########
###################################

my $listener = AnyEvent::Twitter::Stream->new(
	token           => $config->{token},
	token_secret    => $config->{token_secret},
	consumer_key    => $config->{consumer_key},
	consumer_secret => $config->{consumer_secret},
	method          => 'filter',
	track           => $keywords,
	timeout         => 300,
	on_tweet => sub
	{
		my $tweet = shift;

		if (defined $no_rt)
		{
			if ($tweet->{text} =~ /^RT @/) { next; }
		}

		if (defined $monitor)
		{
			my $tweet_no_newline = $tweet->{text};
			my $count = $tweet_no_newline =~ s/\r?\n/ /g;

			print "[" . scalar localtime ($tweet->{timestamp_ms}/1000) . "] " . $tweet->{user}{name} . " (" . $tweet->{user}{screen_name} . ")\n";

			print $tweet_no_newline;

			if ($count > 1) { print "\t[Removed ".$count." linespaces]"; }

			print "\n\n";
		}

		my $query_string = 
			"INSERT INTO tweets(username, fullname, timestamp_ms, tweet_id, text)
			 VALUES(?, ?, ?, ?, ?);";

		my $query = $dbh->prepare($query_string);

		$query->execute($tweet->{user}{screen_name}, $tweet->{user}{name}, $tweet->{timestamp_ms}, $tweet->{id}, $tweet->{text});

		$query->finish();
	},

	on_error => sub
	{
		my $error = shift;
		warnf($error);
		$done->send;
	},

	on_eof => sub
	{
		$done->send;
	},
);
 
$done->recv;

$dbh->disconnect();
