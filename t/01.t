#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";

my $oldDir = chdir $Bin;

diag('Testing ExtJS::Generator::DBIC::TypeTranslator ...');

require_ok('Test::WWW::Selenium::Page');

my $page;

ok( $page = Test::WWW::Selenium::Page->new(
                driver_browser_url => 'http://search.cpan.org',
                title              => 'The CPAN Search Site - search.cpan.org',
            ), 
  'Page object loaded correctly'
);

can_ok(
  $page, 
  (qw/get_title            get_location                           get_relative_location
      refresh              capture_screenshot                     log_in_user
      log_in_user          log_out                                log_out
      has_expected_title   has_expected_relative_location         is_restricted
      has_logged_in_user   has_logged_in_user                     get_XPATH_for_field_with_label
      get_field_with_label get_XPATH_for_element_containing_text  get_XPATH_for_element_with_class/
  )
);

done_testing;

chdir $oldDir;
