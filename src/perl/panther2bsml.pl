#!/usr/local/packages/perl-5.8.5/bin/perl

BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};
use lib (@INC,$ENV{"PERL_MOD_DIR"});
no lib "$ENV{PERL_MOD_DIR}/i686-linux";
no lib ".";

=head1  NAME 

panther2bsml.pl - convert panther raw output to BSML

=head1 SYNOPSIS

USAGE: panther2bsml.pl 
        --input=/path/to/somefile.panther.raw 
        --output=/path/to/somefile.panther.bsml
		--query_file_path=/path/to/query.fasta.fsa
        --gzip_output=1
      [ --log=/path/to/some.log
        --debug=4 
        --help
      ]

=head1 OPTIONS

B<--input,-i> 
    Input raw alignment file from an panther search.

B<--output,-o> 
    Output BSML file

B<--query_file_path,-q> 
    Full path to query sequence file used for Panther run.

B<--gzip_output,-g>
    A non-zero will result in compressed bsml output.  If there is not a .gz extension 
    on the output file name, one will be added.

B<--debug,-d> 
    Debug level.  Use a large number to turn on verbose debugging. 

B<--log,-l> 
    Log file

B<--help,-h> 
    This help message

=head1   DESCRIPTION

This script is used to convert the raw output from a panther search into BSML.

=head1 INPUT

The input file passed to this script must be a raw alignment file generated by panther.
Define the input file using the --input option.

Illegal characters will be removed from the IDs for the query sequence and subject hit
if necessary to create legal XML id names.  For each element, the original, unmodified 
name will be stored in the "title" attribute of the Sequence element.  You should make 
sure that your ids don't begin with a number.  This script will successfully create a 
BSML document regardless of your ID names, but the resulting document may not pass DTD 
validation.

=head1 OUTPUT

The BSML file to be created is defined using the --output option.  If the file already exists
it will be overwritten.

=head1 CONTACT

    Brett Whitty
    bwhitty@tigr.org

=cut

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Ergatis::Logger;
use File::Basename;
use BSML::BsmlRepository;
use BSML::BsmlBuilder;
use BSML::BsmlParserTwig;

my $defline;

my %options = ();
my $results = GetOptions (\%options, 
              'input|i=s',
              'output|o=s',
			  'query_file_path|q=s',
              'gzip_output|g=s',
              'log|l=s',
              'debug=s',
              'help|h') || pod2usage();

my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
                  'LOG_LEVEL'=>$options{'debug'});
$logger = $logger->get_logger();

# display documentation
if( $options{'help'} ){
    pod2usage( {-exitval=>0, -verbose => 2, -output => \*STDOUT} );
}

## make sure all passed options are peachy
&check_parameters(\%options);

my $infile = basename($options{'input'});

my $query_id = '';
if ($infile =~ /^(.*)\.panther\.raw/) {
	$query_id = $1;
} else {
	$logger->logdie("bad input file '$options{input}'");
}

## open the input file for parsing
open (my $ifh, $options{'input'}) || $logger->logdie("can't open input file for reading");

## we want a new doc
my $doc = new BSML::BsmlBuilder();

## make sure the name is legal
my $query_id_orig = $query_id;
$query_id =~ s/[^a-zA-Z0-9\.\-\_]/_/g;

## add the query sequence file to the doc
##  the use of 'aa' is not guaranteed here, but we're not using it anyway in loading
my $seq = $doc->createAndAddSequence($query_id, $query_id_orig, undef, 'aa', 'polypeptide');
$doc->createAndAddSeqDataImport($seq, 'fasta', $options{'query_file_path'}, '', $query_id);
$seq->addBsmlLink('analysis', "#panther_analysis", 'input_of');
$seq->addBsmlAttr('defline', $defline);

my @panther_results = ();
while (<$ifh>) {
	chomp;
	## Panther raw format
	# sma1.model.48073_00236  PTHR23256:SF53  TYROSINE-PROTEIN KINASE-LIKE 7  5.9e-65 226.6   229-343,422-510,539-564,615-727,761-802,827-868,
	my @results = split("\t", $_);
	
    ## add this model sequence
	my $seq = $doc->createAndAddSequence($results[1], $results[2], undef, 'aa', 'polypeptide');
   
	my $seqPairAlignment = $doc->createAndAddSequencePairAlignment( refseq => $query_id,
																   	refstart => 0,
                                                                   	compseq => $results[1],
                                                                    class => 'match',
                                                                  );
    
	## add a link element inside this seq-pair-alignment
	$seqPairAlignment->addBsmlLink('analysis', "panther_analysis", 'computed_by');
    
	## add the total_score and total_eval for this pair
	$doc->createAndAddBsmlAttribute($seqPairAlignment, 'total_score', $results[4]);
	$doc->createAndAddBsmlAttribute($seqPairAlignment, 'total_e_value',  $results[3]);

	my $segments = pop(@results);
	$results[5] =~ s/\,$//;
	
	my $seg_counter = 0;
	my $seg_total = scalar(split(",", $segments));
	foreach my $segment(split(",", $segments)) {
		$seg_counter++;

		my ($startpos, $endpos) = split("-", $segment);
		$startpos--; ## correct startpos for interbase

		my $run = $doc->createAndAddSequencePairRun(   alignment_pair => $seqPairAlignment,
                                                       runlength => ($endpos - $startpos),
                                                       comprunlength => ($endpos - $startpos),
                                                       refpos => $startpos,
                                                       refcomplement => 0,
                                                       comppos => 0,
                                                       compcomplement => 0,
                                                   );
        ## add other attributes of the run
        $doc->createAndAddBsmlAttribute( $run, 'class', 'match_part');
        $doc->createAndAddBsmlAttributes(	$run, 
											domain_num => $seg_counter,
											domain_of  => $seg_total,
                                        );
	}
}

close $ifh;

## add the analysis element
$doc->createAndAddAnalysis(
                            id => "panther_analysis",
                            sourcename => $options{'output'},
                          );

## now write the doc
$doc->write($options{'output'}, '', $options{'gzip_output'});

exit;

sub check_parameters {
    
    ## make sure input file exists
    if (! -e $options{'input'}) { $logger->logdie("input file $options{'input'} does not exist") }

    ## make user an output file was passed
    if (! $options{'output'}) { $logger->logdie("output option required!") }

    ## if the query fasta file was given, parse out the header line (defline).
    if($options{'query_file_path'}) {
        open(IN, "< $options{query_file_path}") or
            $logger->logdie("Unable to open $options{query_file} ($!)");
        while(<IN>) {
            chomp;
            if(/^>(.*)/) {
                $defline = $1;
                last;
            }
        }
        close(IN);
    }

    return 1;
}
