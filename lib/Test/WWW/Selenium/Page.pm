package Test::WWW::Selenium::Page;

#ABSTRACT: Page Object for Test::WWW::Selenium

use Moose;
use Carp;
use namespace::autoclean;
use Test::WWW::Selenium;
use MIME::Base64;
use Encode;

=encoding utf8

=head1 SYNOPSIS

  use Test::WWW::Selenium::Page;
  
  my $page = new Test::WWW::Selenium::Page()

  say $page->title();

=cut

=head1 METHODS

=head2 name

Name of aimed page, used for prefixing screenshots

=cut
has 'name' => (
    is => 'ro',
    isa => 'Str'
);

has 'driver' => (
  is => 'rw',
  isa => 'Test::WWW::Selenium'
);

has 'host' => (
  is => 'rw',
  isa => 'Str', 
  default => '127.0.0.1'
);

has 'port' => (
  is => 'rw',
  isa => 'Int',
  default => 4444
);

has 'browser' => (
  is => 'rw',
  isa => 'Str',
  default => '*firefox /home/poum/bin/firefox-12/firefox',
);

has 'browser_url' => (
  is => 'rw',
  isa => 'Str',
  default => 'http://154.1.2.205:3000'
);

has 'speed' => (
  is => 'rw',
  isa => 'Int',
  default => 500
);

sub BUILD {
  my $self = shift;
  $self->driver( 
    Test::WWW::Selenium->new(
      host        => $self->host, 
      port        => $self->port,
      browser     => $self->browser,
      browser_url => $self->browser_url
    ) 
  );

  croak "Impossible de lancer le driver Selenium: $!" unless $self->driver;

  $self->driver->start();
  $self->driver->open('/');
  $self->driver->set_speed($self->speed);
}

=head2 url

Retourne l'URL de la page sans le protocole, le serveur et le port.
Par exemple, pour "http://127.0.0.1:3000/aide", on aura: "/aide"

=cut
sub url {
  my $self = shift;
  my $url = $self->driver->get_location;

  $url =~ s/^https?:\/\/[^\/]+//;

  return $url;
}

=head2 get_title

Returns web page title (String)

=cut
sub get_title {
  my $self = shift;
  return $self->driver->get_title();
}

=head2 capture_screenshot

Take a page screenshot and generate an png image <page name>_<time>.png

=cut
sub capture_screenshot {
  my $self = shift;
  $self->driver->capture_screenshot($self->name . '_' . time . '.png');
}

=head2 menu

Retourne le XPATh du menu indiqué

=cut
sub menu {
  my ($self, $menu) = @_;
  croak "Nom du menu attendu" unless $menu;

  return q#//div[@id='menus']//button/span# . contientTexte($menu);
}

=head2 aMenu

Attend que le menu indiqué soit présent

=cut
sub aMenu {
  my ($self, $menu) = @_;
  $menu = $self->menu($menu);

  $self->driver->wait_for_element_present($menu);
}

=head2 cliquerMenu

Clique sur le menu indiqué en attendant qu'il soit présent

=cut
sub cliquerMenu {
  my ($self, $menu) = @_;
  
  if ($self->aMenu($menu)) {
    $self->driver->click($self->menu($menu));
  }
}

=head2 sousMenu

Clique sur le menu pour faire apparaître le sous-menu
puis retourne le chemin XPATH du sous-menu indiqué

=cut
sub sousMenu {
  my ($self, $menu, $sousMenu) = @_;
  my @resteNonGere = ();

  croak "Nom du menu attendu" unless $menu;

  ($menu, $sousMenu, @resteNonGere) = split /\//, $menu if $menu =~ /\// and not $sousMenu;
  croak "Nom du sous-menu attendu" unless $sousMenu;
  croak "Gestion limité à un sous-niveau pour le moment" if @resteNonGere;

  $self->cliquerMenu($menu) or croak "Menu non trouvé";
  
  return '//a' . aClasse('x-menu-item-link') . '/span' . contientTexte($sousMenu);
}

=head2 aSousMenu

Clique sur le menu puis attend que le sous-menu indiqué soit présent

=cut
sub aSousMenu {
  my ($self, $sousMenu) = @_;
  $sousMenu = $self->sousMenu($sousMenu);

  $self->driver->wait_for_element_present($sousMenu);
}

=head2 cliquerSousMenu

Clique sur le menu pour faire apparaître le sous-menu
puis clique sur le sous-menu indiqué

=cut
sub cliquerSousMenu {
  my ($self, $sousMenu) = @_;
  $sousMenu = $self->sousMenu($sousMenu);

  $self->driver->click($sousMenu);
}

=head2 fenetreConnexion

Retourne la fenêtre de connexion (Selenium::Remote::WebElement).
Retourne undef si elle n'est pas trouvée (pas d'exception) ce qui
permet de tester sa disparition.

=cut
sub fenetreConnexion {
  my $self = shift;

  return q#//div[starts-with(@id,'ConnexionWindow')]# . aClasse('x-window'); 
}

sub aFenetreConnexion {
  my $self = shift;

  $self->driver->wait_for_element_present($self->fenetreConnexion);
};

sub aDisparuFenetreConnexion {
  my $self = shift;

  my $id;
  eval {
    $self->driver->is_element_present($self->fenetreConnexion);
  };

  unless ($@) {
    eval {
      $id = $self->driver->get_attribute($self->fenetreConnexion . '@id');
    };

    if ($id) {
      $self->driver->wait_for_condition("document.getElementById($id) === null", $self->speed);
    }

  };

  return 1;

}

=head2 boiteAlerte

Retourne la boite d'alerte avec le titre fourni

=over 4

=item paramètres

=over 4

=item titre de la boîte d'alerte cherchée

=back

=item retourne

=over 4

=item la boîte d'alerte (Selenium::Remote::WebElement) ou undef

=back

=back

=cut
sub boiteAlerte {
  my $self = shift;
  my $titre = shift;

  return 
    '//div' . aClasse('x-message-box') .
    '//span' . aClasse('x-window-header-text') . contientTexte($titre);
}

sub aBoiteAlerte {
  my $self = shift;
  my $titre = shift;

  $self->driver->wait_for_element_present($self->boiteAlerte($titre));
}

sub messageBoiteAlerte {
  my $self = shift;
  my $message = shift;

  return 
    '//div' . aClasse('x-message-box') . 
    '//div' . aClasse('x-form-display-field') . contientTexte($message);
}

sub aMessageBoiteAlerte {
  my $self = shift;
  my $message = shift;
  
  $self->driver->wait_for_element_present($self->messageBoiteAlerte($message));
}

sub champ {
  my $self = shift;
  my $label = shift or croak "Label du champ obligatoire";
  return '//label' . contientTexte($label .':');
}

sub aChamp {
  my $self = shift;
  my $champ = shift;
  
  $self->driver->wait_for_element_present($self->champ($champ));
}

=head2 saisirIdentifiants

Saisit l'identifiant et le mot passe fournis dans les champs correspondants.
Ces champs sont effacés au préalable.
Attend ensuite 1 seconde pour que le formulaire puisse se valider
et que le bouton "Se connecter" ait le temps de s'activer.

=cut
sub saisirIdentifiants {
  my ($self, $identifiant, $mot_de_passe) = @_;

  $self->driver->type("//input[\@name='identifiant']", $identifiant);
  $self->driver->type("//input[\@name='mot_de_passe']", $mot_de_passe);

  #$self->driver->pause(1); # temps validation formulaire
}

sub bouton {
  my $self = shift;
  my $bouton = shift or croak "Nom du bouton attendu";

  return '//button/span' . contientTexte($bouton);
}

sub aBouton {
  my $self = shift;
  my $bouton = shift or croak "Nom du bouton attendu";

  $bouton = $self->bouton($bouton);

  $self->driver->wait_for_element_present($bouton);
}

sub cliquerBouton {
  my $self = shift;
  my $bouton = shift or croak "Nom du bouton attendu";

  $self->driver->click($self->bouton($bouton));
}

sub boutonDesactive {
  my $self = shift;
  my $bouton = shift or croak "Nom du bouton attendu";

  return '//button/span' . contientTexte($bouton) . '/../../..' . aClasse('x-btn-disabled');
}

sub aBoutonDesactive {
  my $self = shift;

  $self->driver->wait_for_element_present($self->boutonDesactive);
}

sub iconeFermeture {
  my $self = shift;
  return q#//img[@class='x-tool-close']#;
}

sub aIconeFermeture {
  my $self = shift;
  
  $self->driver->wait_for_element_present($self->iconeFermeture);
}

sub cliquerIconeFermeture {
  my $self = shift;
 
  $self->driver->click($self->iconeFermeture);  
}

sub texteMenu {
  my $self = shift;
  my $texteMenu = shift;

  croak "Texte du menu attendu" unless $texteMenu;

  return q#//div[@id='menus']//*# . contientTexte($texteMenu);
}

sub aTexteMenu {
  my $self = shift;
  my $texte = shift;

  $self->driver->wait_for_element_present($self->texteMenu($texte));
}

sub contientTexte {
  my $texte = shift;

  my @chaines = split /é|è|'/, $texte;
  my $reponse = '';

  if (scalar @chaines == 1) {
    $reponse = sprintf(q#[.='%s']#, $texte);
  }
  else {
    $reponse .= sprintf(q#[contains(text(), '%s')]#, $_) foreach @chaines;
  }
  return $reponse;
}

sub aClasse {
  return sprintf(q#[contains(concat(' ', @class, ' '), '%s')]#, shift);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 TODO

=over 4

=item Generalize

=item Suppress ExtJS specific and put in Test::WWW::Selenium::Page::ExtJS

=item Suppress Menu stuff

=item Rename methods with appropriate english names

=back

=head1 SEE ALSO

=over 4

=item Test::WWW::Selenium of course

=item Test::WWW:Selenium::Page::ExtJS (coming soon)

=back

=cut
