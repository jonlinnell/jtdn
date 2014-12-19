jtdn
A very very alpha and very very basic Twitter monitor
====================

#
# DESCRIPTION
#

jtdn uses the Twitter API to live capture tweets that match certain keywords. It dumps these tweets into an SQLite database, and optionally prints them to STDOUT.

The 't' stands for Twitter, but the other letters are a mystery.

#
# USAGE
#

jtdn [--config path] --db path --keywords keywords [--monitor] [--no-rt]


--config	Use this to specify a different authentication file.

			If not specified, jtdn will use auth.conf in the current directory.

			Authentication files should return a Perl hash containing OAuth/Twitter API keys and tokens. You need to get these yourself.

			The file should look like this:

				return
				{
					token => "<FILL THIS IN>",
					token_secret => "<FILL THIS IN>",
					consumer_key => "<FILL THIS IN>",
					consumer_secret => "<FILL THIS IN>"
				};

--db 		Specifies the SQLite database. Currently mandatory. Set this to something in /tmp if you really don't need it.

			If the database file doesn't exist, it will be created and the table initialised.

			If the database does exist, all Tweets will be appended to the end of the table.

--keywords	A list of keywords to filter.

			Can be one word, or a list of terms. Must be in quotes.

--monitor	Print Tweets to STDOUT in realtime.

--no-rt		Omit quote retweets (i.e. any tweet that begins with 'RT .)

#
# KNOWN BUGS
#

Where do I even start.

- The main problem is with outputting wide characters in Tweets, inasmuch as it doesn't, at least not well.
