#!/usr/local/bin/perl

use strict;
#use Log::Log4perl qw(get_logger);
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use BSML::BsmlBuilder;
use File::Basename;


my %options = ();
my $results = GetOptions (\%options, 'pe_file|p=s', 'bsml_dir|b=s', 'verbose|v', 'output|o=s', 'verbose|v', 'help|h',);

###-------------PROCESSING COMMAND LINE OPTIONS-------------###

my $output     = $options{'output'};
my $pe_file     = $options{'pe_file'};
my $BSML_dir   = $options{'bsml_dir'};
$BSML_dir =~ s/\/+$//;         #remove terminating '/'s
my $verbose    = $options{'verbose'};
#Log::Log4perl->init("log.conf");
#my $logger = get_logger();

if(!$pe_file or !$output or exists($options{'help'})) {
    #$logger->fatal("Not all of the required options have been defined.  Exiting...");
    &print_usage();
}

###-------------------------------------------------------###


read_pe_output($pe_file);


sub read_pe_output {

    my $pe_out = shift;

    my $doc = BSML::BsmlBuilder->new();

    my $seq_pair = {};

    my ($ClusterGeneCount, $ClusterGapCount, $ClusterScore, $ClusterId);
    open (PE, "$pe_out") or die "Unable to open \"$pe_out\" due to $!";
    while (my $line = <PE> ) {
	chomp($line);
	my @pe = split(/\s+/, $line);
	if(@pe == 5) {
	    #Encountered a cluster definition
	    $ClusterGeneCount = $pe[0];
	    $ClusterGapCount = $pe[1];
	    $ClusterScore = $pe[2];
	    $ClusterId = $pe[4];
	} elsif(@pe == 4) {
	    if(! (exists $seq_pair->{$pe[2]}->{$pe[3]})){
		$seq_pair->{$pe[2]}->{$pe[3]} = [];
	    }
	    push @{$seq_pair->{$pe[2]}->{$pe[3]}}, {
		'start_query'    => $pe[0],
		'runlength'      => 0,
		'start_hit'      => $pe[1],
		'runscore'       => $ClusterScore,
		'PEffect_Cluster_Id' => $ClusterId,
		'PEffect_Cluster_Gap_Count' => $ClusterGapCount,
		'PEffect_Cluster_Gene_Count' => $ClusterGeneCount 
		};
	}
    }

    close PE;

    print STDERR "Created lookup with ",scalar(keys %$seq_pair)," matches\n";

    foreach my $query_name (keys %$seq_pair){
	foreach my $dbmatch_accession (keys %{$seq_pair->{$query_name}}){
	    my $aln = $doc->createAndAddSequencePairAlignment( 'refseq'  => $query_name,
							       'compseq' => $dbmatch_accession 
							     );
	    my $runs = $seq_pair->{$query_name}->{$dbmatch_accession};
	    my $hitnum = 0;
	    foreach my $run (sort {$b->{'runscore'} <=> $a->{'runscore'}} (@$runs)){
		if($hitnum <3){
		    my $s = $doc->createAndAddSequencePairRun( 'alignment_pair' => $aln,
							       'refpos'    => $run->{'start_query'},
							       'runlength'      => $run->{'runlength'},
							       'comppos'      => $run->{'start_hit'},
							       'runscore'       => $run->{'runscore'},
							       );
		    #additional attributes
		    $s->addBsmlAttr( 'PEffect_Cluster_Id',  $run->{'PEffect_Cluster_Id'} );
		    $s->addBsmlAttr( 'PEffect_Cluster_Gap_Count', $run->{'PEffect_Cluster_Gap_Count'} );
		    $s->addBsmlAttr( 'PEffect_Cluster_Gene_Count', $run->{'PEffect_Cluster_Gene_Count'} );

		}
		$hitnum++;
	    }
	}
    
    }

    $doc->createAndAddAnalysis("program" => "peffect", "programversion" => '1.0', 'sourcename' =>$output,
                               "bsml_link_relation" => 'SEQ_PAIR_ALIGNMENTS', 'bsml_link_url' => '#BsmlTables');
    print STDERR "Writing output\n";
    
    $doc->write($output);

    print STDERR "Writing done\n";
    chmod 0666, $output;
}

sub print_usage {


    print STDERR "SAMPLE USAGE:  pe2bsml.pl -p PEffect_output -o output_file\n";
    print STDERR "  --pe_file     = PEffect output file\n";
    print STDERR "  --output      = bsml output file\n";
    print STDERR "  --help = This help message.\n";
    exit 1;

}
