######################################################################
## Name: 		BDT.pl												##
## Description:	A Black Derman Toy Model of Bonds					##
## Author: 		James Heneghan										##
## Date: 		Mar 2011											##
## Project: 	Financial Maths, Module 2 2011						##
######################################################################

use strict;
use Win32::Console::ANSI;
use Term::ANSIColor qw(:constants);

# Price & Rate Tree Structure
# 
# Jump    Jump   Jump  |
#  0      1      2     |
# ------------------------------
# [0][0] 			   | Year 1
# [1][0] [1][1] 	   | Year 2 
# [2][0] [2][1] [2][2] | Year 3
#
# i.e. When traversing the Price/Rate tree :
# - Rows reperesent the Year 
# - Columns represent the Jumps

use constant EPSILON	=> 0.000000001;	# The maximum error allowed before accepting a rate
use constant MAXDEPTH	=> 100;		# Max No. of itterations allowed when searching for
									# a short rate

my $DEBUG = 0;							# 1-> Debugging on, 1-> off

######################################################################
## Inputs Start ######################################################
#my @yield = (0.04, 0.04, 0.04, 0.04, 0.05, 0.05, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07 );
#my @sigma = (0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2 );
#my @yield = (0.1, 0.11, 0.12, 0.125, 0.13 );
#my @yield = (0.1, 0.11, 0.12, 0.125 );
#my @yield = (0.1, 0.11, 0.12 );
#my @yield = (0.01, 0.02 );
#my @sigma = (0.2, 0.19, 0.18, 0.17, 0.16 );
#my @yield = (0.0450, 0.0495, 0.0538, 0.0576, 0.0609, 0.0636, 0.0659, 0.0681, 0.0700, 0.0714, 0.0727, 0.0739, 0.0750, 0.0758, 0.0764, 0.0771, 0.0777, 0.0781, 0.0784);
#my @sigma = (.1, .1, .09, .09, .08, .08, .07, .07, .06, .06, .05, .05, .04, .04, .03, .03, .02, .02, .02);
my @yield = (.0283, .029, .0322, .0362, .0401, .0435, .0464, .0488, .0508, .0512);
my @sigma = (.1,.1,.1,.1,.1,.1,.1,.1,.1,.1);

my $upProb = 0.5; 		# Binomial Up Probability
						# Note: Down probability = (1 - $upProb)
# Bond Inputs
my $bond = 100;			# Bond final Value
my $coupon = .1;		# The coupon on the bond

## Inputs End ########################################################
######################################################################

my $noYears = @yield;	# Years to Maturity
my $depth;				# Iteration depth

my @priceTree;			# A tree of prices
my @priceTreeHi;		# A tree of prices used when iterating
my @priceTreeBisect;	# A tree of prices used when iterating

my @rateTree;			# A tree of rates
my @rateTreeHi;			# A tree of rates used when iterating
my @rateTreeBisect;		# A tree of rates used when iterating

my $row;				# Used to loop through the rows of a rate/price tree
my $col;				# Used to loop through the columns of a rate/price tree
my $loGuess;			# Initial low guess for Zero jump rates
my $hiGuess;			# Initial high guess for Zero jump rates
my $loCalc;				# Used to compare the Future Value of the priceTree[0][0]
						# generatee from a low guess.
my $hiCalc;				# Same as $loCalc

my @priceDiscounts;		# This is an array of $priceYears
my @priceYear;			# Used to hold the Ex Dvidend price data for a coupon
						# bearing bond

# Print initial paramaters
print "\n";
printf ("------------------------------------------------------------\n");
printf ("-- BLACK DERMAN TOY Model ----------------------------------\n\n");
printf ("Years to Maturity = %d\n", $noYears);
printf ("Up Probability = %.2f\n", $upProb);
print "\n";

## Setup #############
# Initialise Price Trees
for ($row = 1; $row < $noYears + 1; $row++) {
	for ($col = 0; $col <= $row; $col++) {
		$priceTree[$row][$col] = 1;
		$priceTreeHi[$row][$col] = 1;
		$priceTreeBisect[$row][$col] = 1;
	}
}
print2dArr(@priceTree);

# Assign rateTree[0][0] = Year 1 Yield
$rateTree[0][0] = $yield[0];
$rateTreeHi[0][0] = $yield[0];

######################################################################
## Main Loop start ###################################################
######################################################################

print " ----- Short Rates -----\n\n";

# Build the short rate tree
for ($row = 1; $row < $noYears; $row++) {

	# Initial guessed for the Lo and Hi boundry of the Zero jump rates.
	#$loGuess = $yield[$row - 1] * 0.9;
	#$loGuess = $rateTree[$row - 1][0] * 0.7;
	$loGuess = 0; #$rateTree[$row - 1][0] * 0.1;
	#$hiGuess = $rateTree[$row - 1][0] * 1.2;
	#$hiGuess = $rateTree[$row - 1][0] * 2;
	$hiGuess = 1;
	
	$rateTree[$row][0] = iterate($loGuess, $hiGuess);
	@rateTree = @rateTreeBisect;
	#printf ("*** Row %d - %.6f\n", $row, $rateTree[$row][0]);
	#print2dArr (@rateTree);
}

#print2dArr (@priceTree);
print "Short rate tree...\n";
print2dArr (@rateTree);
#exit;

######################################################################
## Coupons ###########################################################
######################################################################

# Initialise Coupon Price Trees
for ($row = 1; $row < $noYears + 1; $row++) {
	for ($col = 0; $col <= $row; $col++) {
		if ($row == $noYears){
			$priceYear[$row][$col] = $bond * (1 + $coupon);
		} else {
			$priceYear[$row][$col] = $bond * $coupon;
		}
	}
}
print "Initialisation of \@priceYear\n";
print2dArr (@priceYear);

my $loopRow;		# Used in totaling up the Ex Divident price tree
my $loopCol;		# Used in totaling up the Ex Divident price tree
my $total;
my @exDivPriceTree;	# The Ex Divident Tree structure (a 2 Dimensional Array)

for ($row = 0; $row < $noYears; $row++) {
	$DEBUG = 0;
	calcZeroPrice(\@priceYear, \@rateTree);
	$DEBUG = 0;
	#print2dArr (@priceYear);
	$total += $priceYear[0][0];
	
	# Build up and total the Ex Dividend Present Value tree
	for ($loopRow = 0; $loopRow <= $row; $loopRow++){
		for ($loopCol = 0; $loopCol <= $loopRow; $loopCol++){
			$exDivPriceTree[$loopRow][$loopCol] += $priceYear[$loopRow][$loopCol];
		}
	}
}

print " ----- Ex Dividend Prices -----\n\n";
print "Ex Dividend Present Value Tree...\n";
print2dArr (@exDivPriceTree);

printf ("\nThe PRESENT VALUE of a \$%d Bond with a %d percent Coupon = \$%.2f\n\n", $bond, $coupon*100, sprintf("%.2f", $total) );

######################################################################
## Euro Call Option ##################################################
######################################################################

print " ----- Euro Call Option -----\n\n";
my $callYears = 2;
my $callValue = 95;
my $loop;
undef (@priceTree);

# Fill in the starting Jump prices for a CALL in the priceTree structure
#for ($loop = 0; $loop <= $callYears; $loop++){
for ($loop = 0; $loop < $callYears; $loop++){
	if ( ($exDivPriceTree[$callYears][$loop] - $callValue) >= 0 ){
		$priceTree[$callYears][$loop] = $exDivPriceTree[$callYears][$loop] - $callValue;
	} else {
		$priceTree[$callYears][$loop] = 0;
	}
	#print "$priceTree[$callYears][$loop]\n";
}

$row = $callYears-1;		# $row is used in calcZeroPrice to determind the start year
calcZeroPrice(\@priceTree, \@rateTree);
printf ("\nThe Value of a %d year European CALL option on \na \$%d Bond with %d percent Coupon = \$%.2f\n\n", $callYears, $bond, $coupon*100, sprintf("%.2f", $priceTree[0][0]) );

## Amer Call Option ##################################################
print " ----- Amer Call Option -----\n\n";
printf ("\nThe Values of a %d year American CALL option on with a Strike price of \$%.2f \n on a \$%.2f Bond with %d \% Coupon are:\n\n", $callYears, $callValue, $bond, $coupon*100 );
print2dArr (@priceTree);

######################################################################
## Euro Put Option ###################################################
######################################################################

print " ----- Euro Put Option -----\n\n";
my $putYears = 2;
my $putValue = 95;
#my $loop;

# Fill in the starting Jump prices for a PUT in the priceTree structure
for ($loop = 0; $loop <= $putYears; $loop++){
#for ($loop = 0; $loop < $putYears; $loop++){
	if ( ($putValue - $exDivPriceTree[$putYears][$loop]) >= 0 ){
		$priceTree[$putYears][$loop] = $putValue - $exDivPriceTree[$putYears][$loop];
	} else {
		$priceTree[$putYears][$loop] = 0;
	}
	#print "$priceTree[$putYears][$loop]\n";
}

$row = $putYears-1;		# $row is used in calcZeroPrice to determind the start year
calcZeroPrice(\@priceTree, \@rateTree);
printf ("\nThe Value of a %d year European PUT option on \na \$%d Bond with %d percent Coupon = \$%.2f\n\n", $callYears, $bond, $coupon*100, sprintf("%.2f", $priceTree[0][0]) );

## Amer Put Option ##################################################
print " ----- Amer Put Option -----\n\n";
printf ("\nThe Values of a %d year American PUT option on with a Strike price of \$%.2f \n on a \$%.2f Bond with %d \% Coupon are:\n\n", $callYears, $callValue, $bond, $coupon*100 );
print2dArr (@priceTree);

printf ("-- BDT End -------------------------------------------------\n");
printf ("------------------------------------------------------------\n");
## Main Loop end #####################################################
######################################################################

# Binary Search until the difference between the FV of Zero 
# value(of the guess) is Less than EPSILON
sub iterate {
	my $lo = $_[0];
	my $hi = $_[1];
	my $bisect;
	my $calcBisect;
	my $diff;
	
	$depth++; 
	# Stop iterating after MAXDEPTH as => probable error
	if ($depth > MAXDEPTH){
		print "**** TOO MANY ITERATIONS ****\n";
		exit;
	}

	# Populate the Rate Tree for the given year (row)
	$rateTree[$row] = populateShortRates($lo, @rateTree);
	# Produce resulting Zero price
	calcZeroPrice(\@priceTree, \@rateTree);
	# calc the resulting maturith value of the bond
	$loCalc = $priceTree[0][0] * (1 + $yield[$row]) ** ($row+1) ;
	
	$diff = $loCalc - 1;
	if (abs($diff) < EPSILON  ) {
		$depth = 0;
		return $lo;
	}
	
	$rateTreeHi[$row] = populateShortRates($hi, @rateTreeHi);
	calcZeroPrice(\@priceTreeHi, \@rateTreeHi);
	$hiCalc = $priceTreeHi[0][0] * (1 + $yield[$row]) ** ($row+1) ;
	#print "loCalc = $loCalc | hiCalc = $hiCalc\n";
	
	$diff = $calcBisect - 1;
	if (abs($diff) < EPSILON  ) {
		$depth = 0;
		return $hi;
	}
	# A sanity check, a guess that is too low will produce a bond price
	# greater than 1 
	#if ( $loCalc < 1 ){
	#	print "Err: loCalc < 1 $loCalc | HiCalc = $hiCalc | Lo G = $lo | Hi G = $hi\n";
	#	print2dArr (@rateTree);
	#	print2dArr (@rateTreeHi);
	#	print "Price tree $priceTree[0][0]\n";
	#	print "Price tree Hi $priceTreeHi[0][0]\n";
	#	exit;
	#}
	#if ( $hiCalc > 1 ){
	#	print "Err: hiCalc > 1 $hiCalc | LoCalc = $loCalc | Lo Guess = $lo | hi Guess = $hi\n";
	#	print2dArr (@rateTree);
	#	#print2dArr (@priceTree);
	#	exit;
	#}

	@rateTreeBisect = @rateTree; # This copies all earlier rates from @rateTree
	$bisect = ($lo + $hi) / 2;
	$rateTreeBisect[$row] = populateShortRates($bisect, @rateTreeBisect);
	calcZeroPrice(\@priceTreeBisect, \@rateTreeBisect);
	#print2dArr(@priceTreeBisect);
	#print " = $priceTreeBisect[0][0]\n";
	$calcBisect = $priceTreeBisect[0][0] * (1 + $yield[$row]) ** ($row+1) ;
	#print "\nBisect = $bisect\n";
	#print "calcBisect = $calcBisect\n";
	
	$diff = $calcBisect - 1;
	if (abs($diff) < EPSILON  ) {
		$depth = 0;
		return $bisect;
	} 
	if ($calcBisect > 1) {
		@rateTree = @rateTreeBisect;
		$rateTree[$row][0] = iterate($bisect, $hi);

	} else {
		@rateTreeHi = @rateTreeBisect;
		$rateTree[$row][0] = iterate($lo, $bisect);
	}
}

sub print2dArr1{
	my @tree = @_;
	my $row = 0;
	my $col = 0;
	my $string;

	#print color 'bold blue';
	print GREEN, "Year\tJump\tValue\n";
	print WHITE, "";
	foreach my $r(@tree){
		foreach my $val(@$r){
			$string = sprintf ("%d\t%d\t%.6f", $row, $col, $val);
			print "$string\n";
			$col++;
		}
		$row++;
		$col = 0;
		print "\n";
	}
}
sub print2dArr{
	my @tree = @_;
	my $row = 0;
	my $col = 0;
	my $string;

	my $count = 0;
	foreach my $r(@tree){
		printf ("%2d ", $count++); 
		foreach my $val(@$r){
			$string = sprintf ("%.4f ", $val);
			print "$string";
			$col++;
		}
		$row++;
		$col = 0;
		print "\n";
	}
}

# Populate the short rates 2D array gased on a guess
sub populateShortRates {
	my $guess = $_[0];
	my @branch ;
	$branch[0] = $guess;
	for ($col = 1; $col <= $row; $col++) {
		#### change here for neg interest rates
		$branch[$col] = $guess * exp(2 * $col * $sigma[$row]);
		#print "$branch[$col] ";
	} #print "\n";
	return \@branch;
}

# Populate a 2D Prices Tree based on a Rate Tree
sub calcZeroPrice {

	my ($ref_tree, $ref_rate) = @_;
	my $calcRow;
	my $calcCol;
	
	if ($DEBUG) {
		print "In calcZeroPrice\n";
		print ${$ref_rate}[$row][0]." Rate[$row][1]\n";
		print ${$ref_tree}[$row][0]." Price[$row][1]\n";
		#print "Row=".$row."\n";
	}
	for ($calcRow = $row; $calcRow >= 0; $calcRow--) {
		if ($DEBUG) {
			#print "calcRow=".$calcRow."\n";
		}
		#for ($calcCol = 0; $calcCol <= $row; $calcCol++) {
		for ($calcCol = 0; $calcCol <= $calcRow; $calcCol++) {
			if ($DEBUG) {
				#print "calcCol=".$calcCol."\n";
			}
			${$ref_tree}[$calcRow][$calcCol] = 
				( (1 - $upProb) * ${$ref_tree}[$calcRow+1][$calcCol] + 
				($upProb) * ${$ref_tree}[$calcRow+1][$calcCol+1]) / 
				(1 + ${$ref_rate}[$calcRow][$calcCol]);
			if ($DEBUG) {
				#print $calcRow."-".$calcCol.":".${$ref_tree}[$calcRow][$calcCol]."; ";
			}
		}
		if ($DEBUG) {
			#print "\n";
		}
	}
}