use v6.c;

use NativeCall;
use NativeHelpers::CStruct;
need DBDish::Pg::Connection;

class Pg::Notify {
    has DBDish::Pg::Connection  $.db      is required;
    has Str                     $.channel is required;

    has $!thread;

    has Supplier $!supplier;

    has Promise $!run-promise;

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
            $!run-promise = Promise.new;
            $!thread = Thread.start: :app_lifetime, {
                loop {
                    #last if $!run-promise.status ~~ Kept;
                    $!db.pg-consume-input;
                    if $!db.pg-notifies -> $not {
                        if $not.relname eq $!channel {
                            $supplier.emit: $not;
                        }
                    }
					self.poll-once;
                }
            }
            $supplier;
        }
    }

    method poll-once() returns Int {
        my $fds = LinearArray[PollFD].new(1);
        $fds[0] = PollFD.new(fd => $!db.pg-socket,  events => 1, revents => 0);
        poll($fds.base, 1, -1);
        my $rc = $fds[0].revents;
        $fds.dispose;
        $rc;
    }


    method listen() {
        $!db.do("LISTEN " ~ $!channel);
    }

    method unlisten() {
        $!db.do("UNLISTEN " ~ $!channel);
        if $!run-promise {
            $!run-promise.keep: True;
        }
    }
}


# vim: ft=perl6 ts=4 sw=4 expandtab
