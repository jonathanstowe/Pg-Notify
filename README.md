# DBIishX::PGNotify

Perl6-ish interface to PostgresQL notifies.

## Synopsis

```perl6

... 

use DBIishX::PGnotify;

my $notify = DBIish::PGNotify.new(:$db, :$channel );

react {
    whenever $notify -> $notification {
        say $notification.extras;
    }
}
```

## Description

This provides a simple mechanism to get a supply of the PostgresQL notifications
for a particular *channel*.

## Install


