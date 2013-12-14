#!/usr/bin/perl

use strict;
use warnings;

use HTTP::Daemon;
use HTTP::Status;
use LWP::Simple;

use Test::More;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";

my $oldDir = chdir $Bin;

my $SELENIUM_URL   = 'http://127.0.0.1:4444';
my $WEB_SERVER_URL = 'http://127.0.0.1:8042';
my $SELENIUM_JAR   = $Bin . '/selenium-server-standalone-2.38.0.jar';

die $SELENIUM_JAR . ' not found' if not -e $SELENIUM_JAR;

my $selenium_pid   = start_selenium($SELENIUM_URL);
my $web_server_pid = start_web_server($WEB_SERVER_URL);

require_ok('WWW::Selenium::Page');

my $page;

ok( $page = WWW::Selenium::Page->new(
                driver_browser_url => $WEB_SERVER_URL,
                relative_location => '/test_page.html',
                title              => 'My HTML test page',
            ), 
  'Page object loaded correctly'
);

can_ok(
  $page, 
  (qw/get_title                 get_location                           get_relative_location
      refresh                   capture_screenshot                     log_in_user
      log_in_user               log_out                                log_out
      has_expected_title        has_expected_relative_location         is_restricted
      has_logged_in_user        has_logged_in_user                     get_XPATH_for_field_with_label
      wait_for_field_with_label get_XPATH_for_element_containing_text  get_XPATH_for_element_with_class/
  )
);

is($page->get_title(), 'My HTML test page');
is($page->get_location, $WEB_SERVER_URL . '/test_page.html');
is($page->get_relative_location, '/test_page.html');

done_testing;

kill 9 => $web_server_pid if $web_server_pid;
kill 9 => $selenium_pid   if $selenium_pid;

chdir $oldDir;

sub start_selenium {
    my $selenium_url = shift;

    my $response 
        = get($selenium_url . '/selenium-server/driver/?cmd=getLogMessages');

    my $pid;
    if (not defined $response) {
        diag('[INFO] Launching Selenium Server ....');

        if ($pid = open(CHILD, "-|")) {
            my $line = '';
            while ($line !~ /Started\s+org.openqa.jetty.jetty.Server/) {
                $line = <CHILD>;
                diag('[INFO] Waiting for Selenium Server ... : ' . $line);
            }

            diag('[INFO] Testing Selenium server connection ...');
            die unless get($selenium_url .  '/selenium-server/driver/?cmd=getLogMessages');
            diag('[INFO] Selenium server OK ...');

            return $pid;
        }
        else {
            die "Fork impossible: $!" unless defined $pid;
            exec('java -jar ' . $SELENIUM_JAR);
        }
    }
    else {
        diag('[INFO] Selenium server already running');
    }
}

sub start_web_server {

    my $web_server_url = shift;
    my ($protocole, $address, $port) = split ':',$web_server_url;
    $address =~ s/^\/\///;

    my $response 
        = get($web_server_url . '/test_page.html');

    diag($response);
    if (not $response) {
        diag('[INFO] Launching Web Server ....');
        my $pid;
        if ($pid = fork) {
            return $pid;
        }
        else {
            die "Fork error: $!" unless defined $pid;
            my $d = HTTP::Daemon->new(
                        LocalAddr => $address,
                        LocalPort => $port,
                    ) or die 'Unable to start test web server: ' . $!;
            diag('[INFO] HTTP server ready at ' . $d->url);
            while (my $c = $d->accept) {
                while (my $r = $c->get_request) {
                    if ($r->method eq 'GET' and $r->uri->path eq "/test_page.html") {
                        $c->send_file_response("$Bin/htdocs/test_page.html");
                    }
                    else {
                        $c->send_error(RC_FORBIDDEN)
                    }
                }
                $c->close;
                undef($c);
            }
        }
    }
    else {
        diag('[INFO] Web server already running');
    }
}
