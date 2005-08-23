package Fasta::FastaIndexedReader;

use strict;
use warnings;

use Sequence::Sequence;
use Utils::Progress;

use IO::File;

sub new
{
	my ($class, $files, $show_progress) = @_;
	my $this = {};
	bless $this, $class;
	$this->Init($files, $show_progress);
	return $this;
}

sub Init
{
	my ($this, $files, $show_progress) = @_;
	return unless $files;
	if (ref($files) ne 'ARRAY') {
		$files = [$files];
	}
	$this->{INDEX} = {};
	my $progress = new Utils::Progress("Indexing FASTA");
	foreach my $file (@$files) {
		my $fh = new IO::File($file) or
			die "Error reading FASTA data $file: $!";
		while (my $c = $fh->getc) {
			$progress->Show if $show_progress;
			if ($c ne ">") {
				<$fh>;
				next;
			}
			my $fpos = $fh->tell;
			<$fh> =~ /^[\w\|\.]+/;
			my $id = $&;
			$this->{INDEX}->{$id} = [$fh, $fpos];
		}
	}
	$progress->Show(1) if $show_progress;
}

sub FetchSequence
{
	my ($this, $id) = @_;
	return undef unless defined($id) and defined($this->{INDEX}->{$id});
	my ($fh, $fpos) = @{$this->{INDEX}->{$id}};
	$fh->seek($fpos, 0);
	<$fh> =~ /^[\w\|]+\s+(.*)$/;
	my $title = $1;
	my $seq = "";
	while (my $line = <$fh>) {
		last if $line =~ /^>/;
		chomp $line;
		$seq .= $line;
	}
	return new Sequence::Sequence($id, $seq, $title);
}

1;
