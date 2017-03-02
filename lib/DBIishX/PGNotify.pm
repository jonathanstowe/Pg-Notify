use v6.c;

class DBIishX::PGNotify {
    has DBDish::Pg::Connection  $.db      is required;
    has Str                     $.channel is required;
    has Supply                  $.Supply;

    has $!listen-sth;


    method listen() {
        my $sth = $db.prepare("LISTEN ?");
        $sth.execute($!channel);
    }
    method Supply() returns Supply {
        $!Supply =  supply {
                self.listen;
                whenever Supply.interval(0.1) {
                    $db.pg-consume-input;
                    if $db.pg-notifies -> $not {
                        if $not.relation eq $!channel {
                            emit $not;
                        }
                    }
                }
            }
    }
}


# vim: ft=perl6 ts=4 sw=4 expandtab
