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
    my $channel = "testchannel";

    my $notify = Pg::Notify.new(:$db, :$channel );

    lives-ok { $notify.listen }, 'listen';

    # we only want the middle one
    $db.do("NOTIFY wrongchannel, 'Not Interested'");
    $db.do("NOTIFY $channel, 'TEST VALUE'");
    $db.do("NOTIFY otherchannel, 'Not Interested'");

    my $count = 1;
    react {
        whenever $notify -> $value {
            isa-ok $value, DBDish::Pg::Native::pg-notify;
            is $value.relname, $channel, "and got the right relname";
            is $value.extra, "TEST VALUE", "got the right value";
            done();
        }
        whenever Supply.interval(1) -> $v {
            bail-out 'Timeout' if $v == 4;
        }
    }

    lives-ok { $notify.unlisten }, "unlisten";
}
else {
    skip "Can't connect to DB, won't test";
}

done-testing;
# vim: expandtab shiftwidth=4 ft=raku
