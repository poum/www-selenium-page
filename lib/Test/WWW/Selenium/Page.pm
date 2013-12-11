package Test::WWW::Selenium::Page;

#ABSTRACT: Page Object for testing with Test::WWW::Selenium

use Carp;
use Moose;
use namespace::autoclean;
use Test::WWW::Selenium;
use MIME::Base64;
use Encode;

=encoding utf8

=cut

=head1 METHODS

=head2 relative location

The page location without protocol, host and port part.

=cut
has 'relative_location' => (
    is  => 'ro',
    isa => 'Str',
    default => '/',
);

=head2 title 

Expected title of aimed HTML page

=cut
has 'title' => (
    is  => 'ro',
    isa => 'Str',
);

=head2 restricted

Flag for restricted access page needing an logged in user.
If set, log_in_user, log_out_user and has_logged_in_user have to be
overloaded.

If undefined, page is usable both for anonymous or logged in user

Set to undef by default.
=cut
has 'restricted' => (
    is  => 'ro',
    isa => 'Bool',
);

=head2 default_user_id

Default user id to log in if page is restricted

=cut
has 'default_user_id' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 default_user_password

Default user password for log in if page is restricted

=cut
has 'default_user_password' => (
    is  => 'rw',
    isa => 'Str',
);

has 'driver' => (
  is  => 'rw',
  isa => 'Test::WWW::Selenium',
);

=head2 driver_host

Selenium host (127.0.0.1 by default)

=cut
has 'driver_host' => (
  is      => 'rw',
  isa     => 'Str', 
  default => '127.0.0.1',
);

=head2 driver_port

Selenium port (4444 by default)

=cut
has 'driver_port' => (
  is      => 'rw',
  isa     => 'Int',
  default => 4444,
);

=head2 driver_browser

Selenium browser (*firefox by default).
See L<WWW::Selenium> for details

=cut
has 'driver_browser' => (
  is      => 'rw',
  isa     => 'Str',
  default => '*firefox',
);

=head2 driver_browser_url

Absolute starting URL for browser

=cut
has 'driver_browser_url' => (
  is      => 'rw',
  isa     => 'Str',
  default => 'http://127.0.0.1',
);

=head2 speed

Execution speed

=cut
has 'speed' => (
  is      => 'rw',
  isa     => 'Int',
  default => 500,
);

sub BUILD {
    my $self = shift;

    $self->driver( 
        Test::WWW::Selenium->new(
            host        => $self->driver_host, 
            port        => $self->driver_port,
            browser     => $self->driver_browser,
            browser_url => $self->driver_browser_url,
        ) 
    ) 
        or croak "Unable to launch Selenium driver: $!";

    $self->driver->start();
    $self->driver->open($self->relative_location);
    # set_speed need an opened page 
    $self->driver->set_speed($self->speed);

    if  ( defined $self->is_restricted 
        and $self->is_restricted == 1
        and not $self->has_logged_in_user() ) {
            $self->log_in_user() 
                or croak 'Unable to log in as ' . $self->default_user_id;
    }

    if ( not $self->has_expected_relative_location() ) {
      my ($expected, $got) = ($self->relative_location, $self->get_relative_location() );

      croak <<"END_CROAK";

Page not correctly created, 

Expected location: $expected
Got:               $got

END_CROAK
    }

    if ( not $self->has_expected_title() ) {
      my ($expected, $got) = ($self->title, $self->get_title() );

      croak <<"END_CROAK";

Page not correctly created, expected title: 

Expected title: $expected
Got:            $got

END_CROAK
    }
}

=head2 get_title

Return the HTML page title

=cut
sub get_title {
    my $self = shift;
    return $self->driver->get_title();
}

=head2 get_location

Return page location

=cut
sub get_location {
    my $self = shift;
    
    return $self->driver->get_location;
}

=head2 get_relative_location

Return site relative location (without protocol, host and port part)

By example, '/home' for 'http://127.0.0.1:3000/home'

=cut
sub get_relative_location {
  my $self = shift;

  my $relative_location = $self->get_location;

  $relative_location =~ s/^https?:\/\/[^\/]+//;

  return $relative_location;
}

=head2 refresh

Refresh page (chainable)

=cut

sub refresh {
    my $self = shift;
    
    $self->driver->refresh();

    return $self;
}

=head2 capture_screenshot

Capture page screenshot (chainable)

The resulting image file would be <page_title>_<time>.png

=cut
sub capture_screenshot {
  my $self = shift;
  $self->driver->capture_screenshot($self->get_title . '_' . time . '.png');

    return $self;
}

=head2 log_in_user

Log in user with supplied id and password (chainable).

B<This method has to be overloaded in inherited restricted page object>

=over 4

=item Parameters

=over 4

=item user id

=item user password

=back

=item Return page reference in case of success, undef oterwhise

=back

=cut
sub log_in_user {
    my $self = shift;
    my $user_id = shift || $self->default_user_id 
        or croak "User id is missing";
    my $password = shift || $self->default_user_password
        or croak "User password is missing";

    if ( $self->is_restricted() ) {
        croak << 'END_CROAK';

authenticate_user method has to be be overloaded in inherited Page class
because this page has restricted access.

Copy/paste/modify following code in your inherited Page class:

sub log_in_user {
    my $self = shift;
    my $user_id = shift || $self->default_user_id 
        or croak 'User id is missing';
    my $password = shift || $self->default_user_password
        or croak 'User password is missing';
    
    # your authentication code here

    return $self->has_logged_in_user($user_id) ? $self : undef;
}
END_CROAK

    }
    else {
        carp 'Page isn\'t restricted ...'; 
    }

    # return undef if user couldn't log in
    # Here, page is not restricted, so we consider user can't be logged
    # in (but page could display differently before / after log in
    # in some situation).
    return $self->has_logged_in_user($user_id) ? $self : undef;
}

=head2 log_out

Log out user (chainable)

Return Page ref is user succeded to log out, undef otherwise.

=cut
sub log_out {
    my $self = shift;

    if ( $self->is_restricted() ) {

        croak << 'END_CROAK';

log_out method has to be be overloaded in inherited Page class
because this page has restricted access.

Copy/paste/modify following code in your inherited Page class:

sub log_out {
    my $self = shift;

    # your log_out code here

    return not $self->has_logged_in_user() ? $self : undef;
}
END_CROAK

    }
    else {
        carp 'Page isn\'t restricted, useless logout operation ...';
    }

    return not $self->has_logged_in_user() ? $self : undef;
}
 
=head2 has_expected_title

Check if the HTML page title match the page name attribut value

=cut
sub has_expected_title {
    my $self = shift;

    return ( $self->title eq $self->get_title() );
}

=head2 has_expected_relative_location

Check if the HTML page relative location match the page relative location
attribute value

=cut
sub has_expected_relative_location {
    my $self = shift;

    return ( $self->relative_location eq $self->get_relative_location() );
}

=head2 is_restricted

Check if page has restricted access :

=over 4

=item 0: means public access only

=item undef: means both public and logged in user access

=item 1: means restricted access only

=back

=cut
sub is_restricted {
    my $self = shift;

    return $self->restricted;
}

=head2 has_logged_in_user

Check if the specified / an user is logged in

B<This method has to be overloaded in inherited restricted page object>

=cut
sub has_logged_in_user {
    my $self = shift;
    my $user_id = shift || $self->default_user_id 
        or croak "User id is missing";

    if ( $self->is_restricted() ) {
        croak << 'END_CROAK';

has_logged_in_user method has to be be overloaded in inherited Page class
because this page has restricted access.

Copy/paste/modify following code in your inherited Page class:

sub has_logged_in_user {
    my $self = shift;
    my $user_id = shift || $self->default_user_id 
        or croak 'User id is missing';

    # your test code here

    # return appropriate boolean value
}
END_CROAK

    }
    else {
        carp 'Page isn\'t restricted, will always return false ...';
    }

    return undef;
}

=head2 get_XPATH_for_field_width_label

Return XPATH locator for field with specified label

=cut
sub get_XPATH_for_field_with_label {
  my $self = shift;
  my $label = shift 
    or croak 'Label required';

  return '//label' . get_XPATH_for_element_containing_text($label .':');
}

=head2 wait_for_field_with_label

Wait for field with specified label is present

=cut
sub get_field_with_label {
  my $self = shift;
  my $label = shift;
  
  $self->driver->wait_for_element_present( $self->get_XPATH_for_field_width_label($label) );
}

=head2 get_XPATH_for_element_containing_text 

Return XPATH locator for elements containing
the specified text.
Split for é, è and ' char

=cut
sub get_XPATH_for_element_containing_text {
  my $text = shift;

  warn 'TODO: improve encoding processing';

  my @strings = split /é|è|'/, $text;
  my $XPATH = '';

  if (scalar @strings == 1) {
    $XPATH = sprintf(q#[.='%s']#, $text);
  }
  else {
    $XPATH .= sprintf(q#[contains(text(), '%s')]#, $_) foreach @strings;
  }
  return $XPATH;
}

=head2 get_XPATH_for_element_with_class

Return XPATH locator for elements having
the specified class.

=cut
sub get_XPATH_for_element_with_class {
  return sprintf(q#[contains(concat(' ', @class, ' '), '%s')]#, shift);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 TEST

Before launching test, you have to:

=over 4

=item download selenium server on L<http://docs.seleniumhq.org/download/>

=item launch it:

    $ java -jar selenium-server-standalone-2.xx.jar

=back


