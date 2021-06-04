use feature 'unicode_strings';
use strict;
use Setup;

my %ctx = test_init();

require Hydra::Schema;
require Hydra::Model::DB;
require Hydra::Helper::Nix;

use Test2::V0;
require Catalyst::Test;
Catalyst::Test->import('Hydra');
use HTTP::Request::Common qw(POST PUT GET DELETE);


my $db = Hydra::Model::DB->new;
hydra_setup($db);

# Create a user to log in to
my $user = $db->resultset('Users')->create({ username => 'alice', emailaddress => 'root@invalid.org', password => '!' });
$user->setPassword('foobar');
$user->userroles->update_or_create({ role => 'admin' });

# Login and save cookie for future requests
my $req = request(POST '/login',
    Referer => 'http://localhost/',
    Content => {
        username => 'alice',
        password => 'foobar'
    }
);
is($req->code, 302);
my $cookie = $req->header("set-cookie");


# Setup our project and jobset
my $project = $db->resultset('Projects')->create({name => "tests", displayname => "", owner => "root"});

my $jobset = createJobsetWithOneInput("cancel_non_current_builds", "input-based.nix", "counter", "string", "0" , $ctx{jobsdir});

ok(evalSucceeds($jobset),               "Evaluating jobs/input-based.nix should exit with return code 0");
is(nrQueuedBuildsForJobset($jobset), 1, "Evaluating jobs/input-based.nix should result in 1 builds");

# update the input to the next value and queue another build
my $input = $jobset->jobsetinputs->find({ name => "counter", type => "string" });
$input->jobsetinputalts->update({ value => "2" });

ok(evalSucceeds($jobset),               "Evaluating jobs/input-based.nix should exit with return code 0");
is(nrQueuedBuildsForJobset($jobset), 2, "Evaluating jobs/input-based.nix should result in 2 builds");

# updating it one more time should bump the counter again
$input->jobsetinputalts->update({ value => "3" });

ok(evalSucceeds($jobset),               "Evaluating jobs/input-based.nix should exit with return code 0");
is(nrQueuedBuildsForJobset($jobset), 3, "Evaluating jobs/input-based.nix should result in 3 builds");

# calling the cancel-non-current build endpoints should remove two of the jobs again
my $response = request(GET '/jobset/tests/cancel_non_current/cancel-non-current', Accept => 'application/json');
ok($response->is_success);

is(nrQueuedBuildsForJobset($jobset), 1, "Cancelling non-current builds should result in 1 builds");

done_testing();
