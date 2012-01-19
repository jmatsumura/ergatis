#!/usr/bin/env perl

=head1 NAME

run_bmtagger.pl - Generates a command line string and runs bmtagger based on input options

=head1 SYNOPSIS

USAGE: run_bmtagger.pl 
            --bmtagger_path=/path/to/bmtagger.sh 
            --input_file1=/path/to/some.fastq
            --input_file2=/path/to/another.fastq
            --reference_bitmask=/path/to/reference.bitmask
            --reference_srprism=/path/to/reference.srprism
            --input_format=fasta|fastq
            --input_class=single|paired
            --output_file=/path/to/some.out
          [ --tmp_dir=/tmp
            --log=/path/to/some.log
            --debug=4
          ]

=head1 OPTIONS

B<--bmtagger_path,-b>
    The path to the bmtagger.sh script in your bmtagger install.

B<--input_file1,-i>
    A single input file in FASTA or FASTQ format, specified below.  If you have single
    reads (rather than paired) put the file path here.

B<--input_file2, -j>
    A single input file in FASTA or FASTQ format, this specified an input file for read
    mates, required to be in the same format as the file specified with -i option, and 
    should have all same read IDs and in the same order.

B<--reference_bitmask,-r>
    The path to the bitmask file created by bmtool (or the bmtagger_index component
    in Ergatis.)

B<--reference_srprism,-s>
    The path to the srprism file created by srprism (or the bmtagger_index component
    in Ergatis.)

B<--input_format,-f>
    Format of the input file.  Value should be either 'fasta' or 'fastq'.

B<--input_class,-c>
    Are the input reads 'single' or 'paired' ?

B<--output_file,-o>
    The output file that will be created.

B<--tmp_dir,-t>
    Temporary space to use with bmtagger.  Default = /tmp

B<--log,-l> 
    Log file

B<--debug> 
    Debug level.

B<--help,-h>
    This help message

=head1  DESCRIPTION

put a longer overview of your script here.

=head1  INPUT

the input expectations of your script should be here.  pasting in examples of file format
expected is encouraged.

=head1  OUTPUT

the output format of your script should be here.  if your script manipulates a database,
you should document which tables and columns are affected.

=head1  CONTACT

    Joshua Orvis
    jorvis@users.sf.net

=cut

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Ergatis::Logger;
use Pod::Usage;

my %options = ();
GetOptions(\%options, 
           'bmtagger_path|b=s',
           'input_file1|i=s',
           'input_file2|j=s'
           'reference_bitmask|r=s',
           'reference_srprism|s=s',
           'input_format|f=s',
           'input_class|c=s',
           'output_file|o=s',
           'tmp_dir|t=s',
           'log|l=s',
           'debug=s',
           'help|h') || pod2usage();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

## make sure everything passed was peachy
&check_parameters(\%options);

## Setup the logger.  See perldoc for more info on usage
my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger('LOG_FILE' =>$logfile,
                                 'LOG_LEVEL'=>$options{'debug'});
$logger = $logger->get_logger();

my $cmd = $options{bmtagger_path} . " -b " . $options{reference_bitmask} . 
          " -x " . $options{reference_srprism} . " -T " . $options{tmp_dir};

if ( $options{input_format} eq 'fasta' ) {
    $cmd .= " -q0";

} elsif ( $options{input_format} eq 'fastq' ) {
    $cmd .= " -q1";
}

$cmd .= " -1 $options{input_file1}";

if ( $options{input_class} eq 'paired' ){
    $cmd .= " -2 $options{input_file2}";
}

$cmd .= " -o $options{output_file}";

print STDERR "INFO: running command: $cmd\n";

system($cmd);

if ($? == -1) {
    print "failed to execute: $!\n";
    exit(1);
} elsif ($? & 127) {
    printf "child died with signal %d, %s coredump\n",
           ($? & 127),  ($? & 128) ? 'with' : 'without';
    exit(1);
} else {
    printf "child exited with value %d\n", $? >> 8;
    exit(0);
}




sub check_parameters {
    my $options = shift;
    
    ## make sure required arguments were passed
    my @required = qw( bmtagger_path reference_bitmask reference_srprism input_format
                       input_class output_file );
    for my $option ( @required ) {
        unless  ( defined $$options{$option} ) {
            die "--$option is a required option";
        }
    }
    
    ##
    ## you can do other things here, such as checking that files exist, etc.
    ##
    if ( $$options{input_format} =~ /^fast[qa]$/ ) {
        die "ERROR: --input_format must be either 'fasta' or 'fastq'";
    }

    if ( $$options{input_class} ne 'single' && $$options{input_class} ne 'paired' ) {
        die "ERROR: --input_class must be either 'paired' or 'single'";
    }

    ## if paired input the --input_file2 must have been specified
    if ( $$options{input_class} eq 'paired' && ! $$options{input_file2} ) {
        die "ERROR: --input_file2 must be specified when using paired read types.";
    }

    ## handle some defaults
    $$options{tmp_dir}   = '/tmp'  unless ($$options{tmp_dir});
}
