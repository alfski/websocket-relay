#!/usr/bin/perl 
# websocket-relay.pl
# Alf 20110923 - websocket relayer/echo
# - if client sends "master" it is removed the send list
# - client is not sent it's own message
# - if client send "resend" the last message is resent
#
# Alf 20160520 - added "sink". Messages will ONLY go to this client
#
# run with 
# perl ~/websocket/mojo/websocket-echo.pl daemon --listen http://*:3000

use Mojolicious::Lite;
use Mojo::IOLoop;

@ARGV = qw( daemon ) unless @ARGV;

my $clients = {};
my $noofClients = 0;
my $lastMessage = "";
my $sink = "";

websocket '/relay' => sub {		# ws://IP_ADDRESS:3000/relay

  my $self = shift;
  my $id;

  #  Increase inactivity timeout for connection a bit
  Mojo::IOLoop->stream($self->tx->connection)->timeout(36000); # 10 hours

  $id = sprintf "%s", $self->tx; 	# Add connection to clients list
  $clients->{$id} = $self->tx;

  # on new client connecting always send lastMessage?
  $clients->{$id}->send("$lastMessage") if $lastMessage ne "";

  $noofClients++;
  # warn "client added ($noofClients)\n";

  $self->on(message => sub {
      my ($self, $message) = @_;

	warn "message=$message\n";
	my $thisClient = sprintf "%s", $self->tx; # who was the message from

	if ($message eq "master") {	# remove any master from client send list
		warn "client is declaring master: $thisClient\n";
		delete $clients->{$thisClient};
	}
	elsif ($message eq "sink") {
		warn "client is declaring sink: $thisClient\n";
		$sink = $thisClient;
	}
	elsif ($message eq "resend") {
		$clients->{$thisClient}->send("$lastMessage");
	} else {
		if ($sink ne "") {	# if sink set only send to the sink
			$clients->{$sink}->send("$message");
		} else {		# send message everyone but sender (relay)
        		for $id (keys %$clients) {
				if ($id ne $thisClient) { $clients->{$id}->send("$message"); }
			}
		}
		$lastMessage = $message if $message ne "R"; # R for 'reload'
	}
    });

  $self->on(finish => sub {
      delete $clients->{$id};
      $noofClients--;
      # warn "client removed ($noofClients)\n";
    });
};

app->start;
