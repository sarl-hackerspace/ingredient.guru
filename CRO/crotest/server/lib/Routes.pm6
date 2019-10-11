use Cro::HTTP::Router;
use DBIish;

### Attributes to pass to DBI->connect() to disable automatic 
### error checking
my %attr = (
    database => '../ingredient.db', 
    PrintError => 1, 
    RaiseError => 0,
);
    
my $dbh = DBIish.connect( 'SQLite', database => '../ingredient.db' );

my $sth = $dbh.do(q:to/STATEMENT/);
    CREATE TABLE IF NOT EXISTS accounts (
    ID          INTEGER PRIMARY KEY AUTOINCREMENT,
    username    TEXT type UNIQUE,
    email       TEXT,
    password    TEXT,
    date        TEXT
    )
    STATEMENT

#$dbh.dispose;


sub routes() is export {
    route {
        get -> {
            static 'static/index.html'
        }   
        get -> 'static', *@path {
            static 'static', @path;
        }   
        post -> 'posts' {
            request-body -> (:$username,:$email,:$password) {
                $sth = $dbh.prepare(q:to/STATEMENT/);
                    INSERT INTO accounts (username, email, password, date)
                    VALUES ( ?, ?, ?, ? )
                    STATEMENT

                    my $date = Str.DateTime.now;
                    my $count = $sth.execute($username, $email, $password, $date);

                #IF USERNAME EXISTS
                CATCH {
                    default { content 'text/html','USERNAME ALREADY EXITS'; }
                    return;
                    }

                    if $count == 1 {
                        content 'text/html','SUCCESS';
                        }
            }
        }
    }
}

