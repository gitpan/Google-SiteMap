use ExtUtils::MakeMaker;
WriteMakefile(
	NAME				=> 'Google::SiteMap',
	VERSION_FROM		=> 'lib/Google/SiteMap.pm',
	PREREQ_PM			=> {
		'XML::Simple'		=> 0,
		'IO::Zlib'			=> 0,
		'IO::File'			=> 0,
	},
	($] >= 5.005 ? (
		ABSTRACT_FROM	=> 'lib/Google/SiteMap.pm',
		AUTHOR			=> 'Jason Kohles <email@jasonkohles.com>'
	) : ()),
);
