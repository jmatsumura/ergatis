#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
#use lib ("/usr/local/projects/ergatis/package-latest/lib/perl5");
use lib ("/usr/local/projects/ergatis/package-nightly/lib/perl5");
use Ergatis::Pipeline;
use Ergatis::SavedPipeline;
use Ergatis::ConfigFile;

# If set to 1, script will not exit until pipeline finishes
my $sync = 0;
# If sync and p_bar are set to 1, progress bar will be shown instead of standard logging
my $p_bar = 0;

my %options;
my $results = GetOptions (\%options,
                          "layout|l=s",
                          "config|c=s",
                          "ergatis_config|e=s",
                          "repository_root|r=s",
						  "sync|s=i",
						  "progress_bar|p=i"
                          );

&check_options(\%options);

my $repo_root = $options{'repository_root'};
my $id_repo = $repo_root."/workflow/project_id_repository";

my $layout = $options{'layout'};
my $config = $options{'config'};
my $ecfg; 
$ecfg = $options{'ergatis_config'} if( $options{'ergatis_config'} );

my $ergatis_config;
if( $ecfg ) {
    $ergatis_config = new Ergatis::ConfigFile( '-file' => $ecfg );
}

my $id = &make_pipeline( $layout, $repo_root, $id_repo, $config, $ergatis_config );
#Label the pipeline.
&label_pipeline( $repo_root, $id);

my $url = "http://ergatis.igs.umaryland.edu/cgi/view_pipeline.cgi?instance=$repo_root/workflow/runtime/pipeline/$id/pipeline.xml";
print "pipeline_id -> $id | pipeline_url -> $url\n";

sub make_pipeline {
    my ($pipeline_layout, $repository_root, $id_repo, $config, $ergatis_config) = @_;
    my $template = new Ergatis::SavedPipeline( 'template' => $pipeline_layout );
    $template->configure_saved_pipeline( $config, $repository_root, $id_repo );
    my $pipeline_id = $template->pipeline_id();    
    if( $ergatis_config ) {
        my $xml = $repository_root."/workflow/runtime/pipeline/$pipeline_id/pipeline.xml";
        my $pipeline = new Ergatis::Pipeline( id => $pipeline_id,
                                              path => $xml );

		if ($sync) {
            print "Script is running synchronously\n";
            print "pipeline_id => $pipeline_id\n";

            # The 'block' term is used to make the pipeline invocation synchronous, so that
            # we can determine success/failure by the return and use that to determine this
            # script's exit value.
            my $success = $pipeline->run( ergatis_cfg => $ergatis_config,
                           block       => 1,
						   show_progress => $p_bar
                         );

            ## Determine the exit value based on the success of the pipeline.
            my $exit_value = ($success) ? 0 : 1;
			exit $exit_value;
		}
        $pipeline->run( 'ergatis_cfg' => $ergatis_config );
    }
    return $pipeline_id;
}

sub label_pipeline {
        my ($repository_root, $pipeline_id) = @_; 
        my $pipeline_runtime_folder = "$repository_root/workflow/runtime/pipeline/$pipeline_id";
	my $genome = `grep "\$;GENOME\$;=" $config|cut -d= -f2`;
	chomp($genome);
	my $abbreviation = `grep "\$;ABBREVIATION\$;=" $config|cut -d= -f2`;
	chomp($abbreviation);
	my $database = `grep "\$;DB\$;=" $config|cut -d= -f2`;
	chomp($database);
	my $comment = "Genome : ".$genome." , ".$abbreviation;
	if(length($database) > 1) {
		$comment .= "<br>Database : ".$database;
	} 
        my $groups_file = "$pipeline_runtime_folder/pipeline.xml.groups";
        open( GROUP, ">> $groups_file") or die("Unable to open $groups_file for writing ($!)");
        print GROUP "$comment\n";
        close(GROUP);
	my $comment_file = "$pipeline_runtime_folder/pipeline.xml.comment";
        open( COM, ">> $comment_file") or die("Unable to open $comment_file for writing ($!)");
        print COM "$comment";
        close(COM);
}

sub check_options {
    my ($opts) = @_;
    
    my @reqs = qw(layout config repository_root);
    foreach my $req ( @reqs ) {
        die("Option $req is required") unless( exists( $opts->{$req} ) );
    }

	$sync = 1 if $opts->{"sync"};
	$p_bar = 1 if ( $opts->{"sync"} && $opts->{"progress_bar"} );
}
