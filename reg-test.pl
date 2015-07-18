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


# Load training header

open my $trainHandle, '<', $args{trainFile}
	|| die "Can't open $trainFile";
	
my @colNames = getCols($trainHandle, $sepChar);
my %colPos = getColumnPositions(@colNames);
my $targetPos = $colPos{$targetName};
my @featureNames = getFeatures($targetPos, @colNames);

# Initialize the linear regression model
my $reg = Statistics::Regression->new(
	# Allow the model to compute a constant "intersept" as well
   "Linear Regression", ["intercept", @featureNames]
);

# Load/process each training line. This is memory-efficient
my %categories;
while (my @cols = getCols($trainHandle, $sepChar)) {
	categorize(\@cols, \%categories);
	my $target = $cols[$targetPos];
	my @features = getFeatures($targetPos, @cols);
	$reg->include($target, [1.0, @features]);
}

foreach my $cat (keys %categories) {
	print STDERR $categories{$cat} . " --- $cat\n";
}

$reg->print;

exit(0);

	
##############################################################################
# Categorize rows by combination of non-numerical columns
# Also replace null with NaN
sub categorize {
	my ($cols, $categories) = @_;
	my $category;
	for (my $i=0 ; $i<scalar(@$cols) ; ++$i) {
		if (!Scalar::Util::looks_like_number($cols->[$i])) {
			$category .= "$i:" . $cols->[$i] . "," if ($cols->[$i]);
			$cols->[$i] = "NaN";
		}
	}
	if (!$categories->{$category}) {
		$categories->{$category} = 1;
	} else {
		++$categories->{$category};
	}
	return $category;
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
	my ($targetPos, @cols) = @_;
	my @features = @cols;
	splice @features, $targetPos, 1;
	return @features;
}



