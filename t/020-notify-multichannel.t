#!/usr/bin/env raku

use v6;

use Test;

use Pg::Notify;
use DBIish;
need  DBDish::Pg::Native;

my %args;
%args<database> = %*ENV<PG_NOTIFY_DB> // 'postgres';

if %*ENV<PG_NOTIFY_HOST> -> $host {
    %args<host> = $host;
}
if %*ENV<PG_NOTIFY_USER> -> $user {
    %args<user> = $user;
}
if %*ENV<PG_NOTIFY_PW> -> $pw {
    %args<password> = $pw;
}

my $db = try DBIish.connect('Pg', |%args);

if $db {
    my @channel = ("test1", "test2", "test3");

    my $notify = Pg::Notify.new(:$db, :@channel);
    $notify.listen();

    # Send through an unrelated notice. This should not be received.
    $db.do(qq{NOTIFY junk, 'Not expecting it back'});

    for @channel -> $channel {
       $db.do(qq{NOTIFY $channel, 'TEST $channel VALUE'});
    }
    my $count = 1;
    react {
        whenever $notify -> $value {
            my $channel = $value.relname;
            is $value.relname, "test$count", "and got the right relname";
            is $value.extra, "TEST $channel VALUE", "got the right value";

            if ($count >= @channel.elems) {
                done();
            } else {
                $count += 1;
            }
        }
        whenever Supply.interval(1) -> $v {
            bail-out 'Timeout' if $v == 4;
        }
    }

    is $count, @channel.elems, "Received expected number of notifications";
}
else {
    skip "Can't connect to DB, won't test";
}

done-testing;
# vim: expandtab shiftwidth=4 ft=raku
