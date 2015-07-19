#!/usr/bin/perl

##############################################################################
# reg-test.pl
# R. Gonzalez 2015
##############################################################################

use Statistics::Regression;
use Scalar::Util;

my $sepChar = "\t"; # tab-delimited files
my $targetName = "target";
my %args = loadArgs();


#####
# First pass to load training header and decide which columns to skip

open my $trainHandle, '<', $args{trainFile}
	|| die "Can't open $trainFile";
my @colNames = getCols($trainHandle, $sepChar);
my %colPos = getColumnPositions(@colNames);
my $targetPos = $colPos{$targetName};
my %skipCols = getNonnumericCols($trainHandle, $sepChar);
close $trainHandle;
$skipCols{$targetPos} = 1;
my @featureNames = getFeatures(\%skipCols, \@colNames);

# Initialize the linear regression model
my $reg = Statistics::Regression->new(
	# Allow the model to compute a constant "intersept" as well
   "Linear Regression", ["intercept", @featureNames]
);

#####
# Second pass to load/process each training line. This is memory-efficient

open $trainHandle, '<', $args{trainFile}
	|| die "Can't open $trainFile";
getCols($trainHandle, $sepChar); # skip header line
while (my @cols = getCols($trainHandle, $sepChar)) {
	my $target = $cols[$targetPos];
	my @features = getFeatures(\%skipCols, \@cols);
	cleanCols(\@features);
	$reg->include($target, [1.0, @features]);
}

$reg->print;

exit(0);

	
##############################################################################
# Get positions of columns containing nonnumeric data, sorry
sub getNonnumericCols {
	my ($trainHandle, $sepChar) = @_;
	my %skipCols;
	while (my @cols = getCols($trainHandle, $sepChar)) {
		for (my $i=0 ; $i<scalar(@cols) ; ++$i) {
			if ($cols[$i] && !Scalar::Util::looks_like_number($cols[$i])) {
				$skipCols{$i} = 1;
			}
		}
	}
	return %skipCols;
}
	
##############################################################################
# Replace missing data with NaN
sub cleanCols {
	my ($cols) = @_;
	for (my $i=0 ; $i<scalar(@$cols) ; ++$i) {
		if ($cols->[$i] !~ /\d/) {
			$cols->[$i] = "NaN";
		}
	}
}
	
##############################################################################
sub loadArgs {
	my $usage = "ARGS:
		-train <training data file>
		-test <test data file>
		-out <output file>
	";
	my %args;
	while ((my $arg=$ARGV[0]) =~ /^-/) {
	    if ($arg eq "-train")
	        { shift @ARGV; $args{trainFile} = $ARGV[0]; }
	    elsif ($arg eq "-test")
	        { shift @ARGV; $args{testFile} = $ARGV[0]; }
	    elsif ($arg eq "-out")
	        { shift @ARGV; $args{outFile} = $ARGV[0]; }
	    else
	        { die $usage }
	    shift @ARGV;
	}
	die $usage if (!$args{trainFile} || !$args{testFile} || !$args{outFile});
	return %args;
}

##############################################################################
sub getCols {
	my ($trainHandle, $sepChar) = @_;
	return split /$sepChar/, <$trainHandle>;
}

##############################################################################
sub getColumnPositions {
	my @colNames = @_;
	my %colPos;
	for (my $i=0 ; $i<scalar(@colNames) ; ++$i) {
		$colPos{$colNames[$i]} = $i;
	}
	return %colPos;
}

##############################################################################
# Strip "target" column
sub getFeatures {
	my ($skipCols, $cols) = @_;
	my @features;
	for (my $i=0 ; $i<scalar(@$cols) ; ++$i) {
		push @features, $cols->[$i] if (!$skipCols->{$i});
	}
	return @features;
}



