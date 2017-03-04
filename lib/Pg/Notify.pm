use v6.c;

use NativeCall;
use NativeHelpers::CStruct;
need DBDish::Pg::Connection;

class Pg::Notify {
    has DBDish::Pg::Connection  $.db      is required;
    has Str                     $.channel is required;

    has $!thread;

    has Supplier $!supplier;

    class PollFD is repr('CStruct') {
        has int32 $.fd;
        has int16 $.events;
        has int16 $.revents;
    }

    sub poll(PollFD $fds, int64 $nfds, int32 $timeout) returns int32 is native { * }

    method supplier() returns Supplier handles <Supply> {
        $!supplier //= do {
            my $supplier = Supplier.new;
            self.listen;
            $!thread = Thread.start: :app_lifetime, {
                loop {
					self.poll-once;
                    $!db.pg-consume-input;
                    if $!db.pg-notifies -> $not {
                        if $not.relname eq $!channel {
                            $supplier.emit: $not;
                        }
                    }
                }
            }
            $supplier;
        }
    }

    method poll-once() returns Int {
        my $fds = LinearArray[PollFD].new(1);
        $fds[0] = PollFD.new(fd => $!db.pg-socket,  events => 1, revents => 0);
        poll($fds.base, 1, -1);
        $fds[0].revents;
    }



    method listen() {
        my $sth = $!db.prepare("LISTEN " ~ $!channel);
        $sth.execute();
    }
}


# vim: ft=perl6 ts=4 sw=4 expandtab
