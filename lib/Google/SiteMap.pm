package Google::SiteMap;
our $VERSION = '0.01';

=head1 NAME

Google::SiteMap - Perl extension for managing Google SiteMaps

=head1 SYNOPSIS

  use Google::SiteMap;

  my $map = Google::SiteMap->new(file => 'sitemap.gz');

  # Main page, changes a lot because of the blog
  $map->add(Google::SiteMap::URL->new(
    loc        => 'http://www.jasonkohles.com/',
    lastmod    => '2005-06-03',
    changefreq => 'daily',
    priority   => 1.0,
  ));

  # Top level directories, don't change as much, and have a lower priority
  $map->add({
    loc        => "http://www.jasonkohles.com/$_/",
    changefreq => 'weekly',
    priority   => 0.9, # lower priority than the home page
  ) for qw(
    software gpg hamradio photos scuba snippets tools
  );

  $map->write;

=head1 DESCRIPTION

The Sitemap Protocol allows you to inform search engine crawlers about URLs
on your Web sites that are available for crawling. A Sitemap consists of a
list of URLs and may also contain additional information about those URLs,
such as when they were last modified, how frequently they change, etc.

This module allows you to create and modify sitemaps.

=head1 METHODS

=over 4

=cut

use strict;
use warnings;
use Google::SiteMap::URL;
require XML::Simple;
require IO::Zlib;
require IO::File;
require UNIVERSAL;
use Carp qw(carp croak);

=item new()

Creates a new Google::SiteMap object.

  my $map = Google::SiteMap->new(
    file	=> 'sitemap.gz',
  );

=cut

sub new {
	my $class = shift;
	my %opts = @_;
	my $self = bless({}, $class);
	while(my($key,$value) = each %opts) { $self->$key($value) }
	if($self->file && -e $self->file) { $self->read }
	return $self;
}

=item read()

Read a sitemap in to this object.  If a filename is specified, it will be
read from that file, otherwise it will be read from the file that was
specified with the file() method.  Reading of compressed files is done
automatically if the filename ends with .gz.

=cut

sub read {
	my $self = shift;
	my $file = shift || $self->file ||
		croak "No filename specified for Google::SiteMap::read";

	my $fh;
	if($file =~ /\.gz$/i) {
		$fh = IO::Zlib->new($file,"rb");
	} else {
		$fh = IO::File->new($file,"r");
	}
	# I think there is a strange bug interaction between IO::Zlib and
	# XML::Simple, just passing the filehandle to XMLin doesn't work
	my $tmp = XML::Simple::XMLin(join('',$fh->getlines),
		ForceArray	=> [qw(url)],
	);
	$self->xmlns($tmp->{xmlns}) if $tmp->{xmlns};
	$self->urls(map {
		Google::SiteMap::URL->new(%{$_}, lenient => 1)
	} @{$tmp->{url}});
}

=item write([$file])

Write the sitemap out to the file.  If a filename is specified, it will be
written to that file, otherwise it will be written to the file that was
specified with the file() method.  Writing of compressed files is done
automatically if the filename ends with .gz.

=cut

sub write {
	my $self = shift;
	my $file = shift || $self->file ||
		croak "No filename specified for Google::SiteMap::write";

	my $fh;
	if($file =~ /\.gz$/i) {
		$fh = IO::Zlib->new($file,"wb9");
	} else {
		$fh = IO::File->new($file,"w");
	}
	$fh->print($self->xml);
}

=item urls()

Return the L<Google::SiteMap::URL> objects that make up the sitemap.

=cut

sub urls {
	my $self = shift;
	$self->{urls} = \@_ if @_;
	my @urls = grep { ref($_) && defined $_->loc } @{$self->{urls}};
	return wantarray ? @urls : \@urls;
}

=item add(item,[item...])

Add the L<Google::SiteMap::URL> items listed to the sitemap.

If you pass hashrefs instead of L<Google::SiteMap::URL> objects, it will turn
them into objects for you.  If the first item you pass is a simple scalar that
matches \w, it will assume that the values passed are a hash for a single
object.  If the first item passed matches m{^\w+://} (i.e. it looks like a URL)
then all the arguments will be treated as URLs, and L<Google::SiteMap::URL>
objects will be constructed for them, but only the loc field will be populated.

This means you can do any of these:

  # create the Google::SiteMap::URL object yourself
  my $url = Google::SiteMap::URL->new(loc => 'http://www.jasonkohles.com/');
  $map->add($url);

  # or
  $map->add(
    { loc => 'http://www.jasonkohles.com/' },
    { loc => 'http://www.jasonkohles.com/software/google-sitemap/' },
    { loc => 'http://www.jasonkohles.com/software/geo-shapefile/' },
  );

  # or
  $map->add(
    loc       => 'http://www.jasonkohles.com/',
    priority  => 1.0,
  );

  # or even something funkier
  $map->add(qw(
    http://www.jasonkohles.com/
    http://www.jasonkohles.com/software/google-sitemap/
    http://www.jasonkohles.com/software/geo-shapefile/
    http://www.jasonkohles.com/software/text-fakedata/
  ));
  foreach my $url ($map->urls) { $url->changefreq('daily') }
    
=cut

sub add {
	my $self = shift;
	if(ref($_[0])) {
		if(UNIVERSAL::isa($_[0],"Google::SiteMap::URL")) {
			push(@{$self->{urls}}, @_);
		} elsif(ref($_[0]) =~ /HASH/) {
			push(@{$self->{urls}},map { Google::SiteMap::URL->new($_) } @_);
		}
	} elsif($_[0] =~ /^\w+$/) {
		push(@{$self->{urls}}, Google::SiteMap::URL->new(@_));
	} elsif($_[0] =~ m{^\w+://}) {
		push(@{$self->{urls}}, map { Google::SiteMap::URL->new(loc => $_) } @_);
	} else {
		croak "Can't turn '".(ref($_[0]) || $_[0])."' into Google::SiteMap::URL object";
	}
}

=item xml()

Return the xml representation of the sitemap

=cut

sub xml {
	my $self = shift;

	return XML::Simple::XMLout(
		{
			xmlns			=> $self->xmlns,
			url				=> [map { $_->hash } $self->urls],
		},
		AttrIndent		=> $self->pretty,
		NoIndent		=> !$self->pretty,
		NoSort			=> !$self->pretty,
		SuppressEmpty	=> 1,
		RootName		=> 'urlset',
		XMLDecl			=> '<?xml version="1.0" encoding="UTF-8"?>',
	);
}

=item file()

Get or set the filename associated with this object.  If you call read() or
write() without a filename, this is the default.

=cut

sub file {
	my $self = shift;
	$self->{file} = shift if @_;
	return $self->{file};
}

=item xmlns()

Get or set the XML namespace to be used for the urlset.  Default is
http://www.google.com/schemas/sitemap/0.84

=cut

sub xmlns {
	my $self = shift;
	$self->{xmlns} = shift if @_;
	return $self->{xmlns} || 'http://www.google.com/schemas/sitemap/0.84';
}

=item pretty()

Set this to a true value to enable 'pretty-printing' on the XML output.  If
false (the default) the XML will be more compact but not as easily readable
for humans (Google and other computers won't care what you set this to).

=cut

sub pretty {
	my $self = shift;
	$self->{pretty} = shift if @_;
	return $self->{pretty};
}

=back

=head1 SEE ALSO

L<https://www.google.com/webmasters/sitemaps/docs/en/protocol.html>

=head1 AUTHOR

Jason Kohles, E<lt>email@jasonkohles.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Jason Kohles

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;
__END__
