use Digest::SHA256::Native;
use DBIish;
use Cro::HTTP::Router;
use Cro::HTTP::Cookie;
use Cro::HTTP::Auth;
use Cro::HTTP::Session::InMemory;
use Net::SMTP;

#Opens Connection
my $dbh = DBIish.connect( 'SQLite', database => '../ingredient.db' );

#Create Verified Account Names
my $sth = $dbh.do(q:to/STATEMENT/);
    CREATE TABLE IF NOT EXISTS accounts (
    ID          INTEGER PRIMARY KEY AUTOINCREMENT,
    username    TEXT type UNIQUE,
    email       TEXT,
    password    TEXT,
    date        TEXT,
    code	INT,
    verified	TEXT
    )
    STATEMENT

#For Session and Cookies
$sth = $dbh.do(q:to/STATEMENT/);
    CREATE TABLE IF NOT EXISTS tokens (
    user        PRIMARY KEY,
    hash        TEXT
    )
    STATEMENT

# Cro::HTTP::Auth Stuff for Session Creation
class UserSession does Cro::HTTP::Auth {
    has $.username is rw;

    method logged-in() {
        defined $!username;
        }
}

sub routes() is export {
    route {
	before Cro::HTTP::Session::InMemory[UserSession].new;

        subset LoggedIn of UserSession where *.logged-in;

        #Static Page HTML
        get -> {
            static 'static/index.html';
        }   
        
        get -> 'register' {
            static 'static/register.html';
        }
        
        get -> 'css' {
            static 'static/style.css';
        }

        #Retrieve Info From register.html   
        post -> 'register', 'post' {
            request-body -> (:$username,:$email,:$password) {
                
                #SQL Insert Statment
                $sth = $dbh.prepare(q:to/STATEMENT/);
                    INSERT INTO accounts (username, email, password, date, code, verified)
                    VALUES ( ?, ?, ?, ?, ?, ? )
                    STATEMENT
                
                #Hash Password
                my $hashpassword = sha256-hex $password.encode: 'utf8-c8';

                #Retrieves Date and Time
                my $date = Str(DateTime.now);

		#Generate Random 6 Digit Code
		my $code = (100000^..999999).pick;

                #Inputs Data Into Database Using Prepare Statement (Outputs 1 for one line added, Outputs 0 for error)
                my $count = $sth.execute($username, $email, $hashpassword, $date, $code, "FALSE");
                
                $sth = $dbh.prepare(q:to/STATEMENT/);
                    insert into tokens (user, hash) 
                    VALUES (?,?)
                    STATEMENT
                
                $sth.execute($username,"");

                #Errors (i.e. Username Already Exists)
                CATCH {
                    default {
                       say 'Error caught:  .message';
                       content 'text/html','USERNAME ALREADY EXITS';
                     }
                     return;
                }

                #No Problems | Account Created
                if $count == 1 {
                    static 'static/confirm.html';
		    
		    #Prep email
		    my $from = "ingredient@arltech.com";
		    my $to = "$email";
		    my $message = "Subject: Ingredient Guru Code
		    Message: Your 6 Digit Number: $code";

		    #Send email
		    my $client = Net::SMTP.new(:server("127.0.0.1"), :debug);
		    $client.send($from, $to, $message);
		    $client.quit;
                }

		# construct URL:  http://[server]/confirm/email?userlog='~$userlog~'&code='~$code
            }
        }

	#Get Statement retirving code and username
	get -> 'confirm' {
	    request-body -> (:$email,:$code) {
		
		$sth = $dbh.prepare(q:to/STATEMENT/);
                    SELECT email,code FROM accounts WHERE email = (?) and code = (?)
                    STATEMENT
		    
		$sth.execute($email, $code);
	    	
		my $result = $sth.allrows;
		
		content	'text/html', 'COOL';
		
		#if $result.elems == 1 {
			#content	'text/html', 'COOL';
			#}
         }
     }
	#Authentication
        get -> UserSession $s, 'login' {
            if $s.logged-in {
                content 'text/html','Successful Login: Welcome' ~ " " ~$s.username ~ '<br><a href="/logout">Logout</a>';
            }
            else {static 'static/signin.html'}
        }
 
	post -> UserSession $user, 'login', 'authenticate' {
            request-body -> (:$userlog, :$passlog, *%) {
                if valid-user-pass($userlog, $passlog) {
                    $user.username = $userlog;
		    say "Successful login";
                    content 'text/html','Successful Login: Welcome' ~ " " ~$user.username ~ '<br><a href="/logout">Logout</a>';
                }
                else {
		    say "Bad login";
                    content 'text/html', "Bad username/password";
                }
            }
        }

# Confirm email form/processor
#	get -> 'confirm', 'email' {
#             request-body -> (:$userlog,:$regcode) {
#		if $userlog == "" || $regcode == "" {
#		say $userlog;
#		static 'static/confirm.html';
               
#                else {
#                    content 'text/html','Confirm Account' ~$userlog;
#                }
#            }
#        }

	# Check if the username/password combination is valid
        sub valid-user-pass($username, $password) {
                #Hash Password At Login
                my $hashlogin = sha256-hex $password.encode: 'utf8-c8';

                #Select Statement to find username
                $sth = $dbh.prepare(q:to/STATEMENT/);
                    select username from accounts WHERE username = (?) and password = (?)
                    STATEMENT

                #Executes Select statement
                $sth.execute($username, $hashlogin);

                #Stores the result
                my $result = $sth.allrows;

                #If there is more than one row, the username and password matched
                return $result.elems >= 1;
    	}

	get -> UserSession $s, 'logout' {
	    $s.username = Nil;
	    static 'static/signin.html'
	}
    }
}

