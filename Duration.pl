#!/usr/bin/perl -w
use strict;
use Tk;

use constant {
   SCALE_X	=> 40,	# 
   SCALE_Y	=> .3,	# 
   OFFSET_X	=> 60,	# 
   OFFSET_Y	=> 550,	# 
   WIDTH	=> 800,	# Window Width
   HEIGHT	=> 600,	# Window Height
   YIELD_LO	=> 0,	# 
   YIELD_HI => 18,	# 
   };

my $scale_x;
my $scale_y;

#my $bondPrice		= 100;
#my $coupon 			= 0.1395;
#my $term 			= 10;
#my $pay_interval	= 1;

my $bondPrice		= 100;
my $annual_coupon	= 0.08;
my $term 			= 5;
my $pay_interval	= 0.5;


my $coupon 			= $annual_coupon * $pay_interval;
my $percent_coup = $coupon * 100;

my $window = MainWindow->new;
$window->title("Bond Data");
$window->Label(-text => "Duration of a Bond")->pack;
my $drawing = $window->Canvas(-width => WIDTH, -height => HEIGHT, -background => "white") -> pack;

# Draw X & Y axis
$drawing->createLine(&x(0), &y(0), 750, 550, -fill => "#ff0000");
$drawing->createLine(&x(0), &y(0), OFFSET_X, 50, -fill => "#ff0000");
# Label axis
$drawing->createText(700,575,-text=>"Yield",-anchor=>"center", -fill => "red");
#$drawing->createText(OFFSET_X -5, 100,-text=>"Price",-anchor=>"e", -fill => "black");
#$drawing->createText(OFFSET_X -5, 200,-text=>"Duration",-anchor=>"e", -fill => "green");
#$drawing->createText(OFFSET_X -5, 300,-text=>"Convexity",-anchor=>"e", -fill => "red");

# Display Bond Details
$drawing->createText(500,100,-text=>"BOND DETAILS",-anchor=>"nw", -fill => "black");
$drawing->createText(500,115,-text=>"Face Value:\t$bondPrice",-anchor=>"nw", -fill => "#ff0000");
$drawing->createText(500,130,-text=>"Coupon:\t\t$percent_coup\%",-anchor=>"nw", -fill => "#ff0000");
$drawing->createText(500,145,-text=>"Term:\t\t$term",-anchor=>"nw", -fill => "#ff0000");
$drawing->createText(500,160,-text=>"Pay Interval (Years):\t$pay_interval",-anchor=>"nw", -fill => "#ff0000");

# Calc PV of coupons
my @pv;
for (my $my_yield = YIELD_LO; $my_yield <= YIELD_HI; $my_yield++) {
	my $count = 1;
	for (my $interval = $pay_interval; $interval <= $term; $interval += $pay_interval){
		if ($interval != $term) {
			$pv[$my_yield][$count++] = $bondPrice * $coupon * exp ( -($my_yield/100) * $interval);
			#$pv[$my_yield][$count++] = $bondPrice * $coupon / exp ( -($my_yield/100) * $interval);
		} else {
			$pv[$my_yield][$count++] = $bondPrice * (1 + ($coupon)) * exp ( -($my_yield/100) * $interval);
		}
		if ($my_yield == 12) {printf("Interval %.2f \tPV %.3f\n", $interval, $pv[$my_yield][$count-1]);}
	}
}

# Calc Price from by totaling coupon PVs (for a given Yield)
my @price;
my $maxY = 0;	# Used to calc Scale Y
for my $loop1 (YIELD_LO .. YIELD_HI) {
	for my $loop (1 .. ($term/$pay_interval)){
		$price[$loop1] += $pv[$loop1][$loop];
	}
	if ($price[$loop1] > $maxY){
		$maxY = $price[$loop1];
	}
	printf ("Yield [$loop1] - Price[$loop1] = %.2f\n",$price[$loop1]);
}

# Scaling
$scale_y = 425 / $maxY;

$drawing->createText(OFFSET_X -5, &y($price[0]),-text=>"Price",-anchor=>"e", -fill => "black");

# Plot the Price line for the bond
for my $loop ( YIELD_LO .. (YIELD_HI - 1) ) {
	$drawing->createLine(&x($loop), &y($price[$loop]), &x($loop + 1), &y($price[$loop + 1]), -width => 1, -fill => "black");
	#$drawing->createLine(&x($loop), &y($price[$loop]), &x($loop), &y($price[$loop] + 10), -width => 5, -fill => "black");
	$drawing->createOval(&x($loop)-2, &y($price[$loop])-2,&x($loop)+2, &y($price[$loop])+2, -fill => "yellow");
	my $myPrice = sprintf("%.1f",$price[$loop]);
	$drawing->createText(&x($loop), &y($price[$loop])-10,-text=>"$myPrice",-anchor=>"w");
	my $myYield = sprintf("%.1f",$loop);
	$drawing->createText(&x($loop), 560,-text=>"$myYield",-anchor=>"center");
	# Disect X Axis
	$drawing->createLine(&x($loop), &y(0), &x($loop), 540, -width => 1, -fill => "black");
}

# Calc the contribution of a coupon to the bond duration
my @coupon_duration;
my @coupon_convexity;
for my $yield (YIELD_LO .. YIELD_HI) {
	for my $time (1 .. ($term/$pay_interval)){
		$coupon_duration[$yield][$time] += $pv[$yield][$time] / $price[$yield] * $time * $pay_interval;
		#$coupon_convexity[$yield][$time] += $pv[$yield][$time] / $price[$yield] * ($time + $time^2) * $pay_interval * exp ( -($time/100) * $yield);
		if ($time == ($term/$pay_interval)) {
			$coupon_convexity[$yield][$time] = 
				#((1+$coupon) * $price[$yield] * ($time*($time+1)) / ((1+$coupon)**($time+2)));
				((1+$coupon) * 100 * ($time*($time+1)) / ((1+$yield/200)**($time+2)));
				#($pv[$yield][$time] * ($time*($time+1)) / ((1+$coupon)**($time+2)));
				# 1/(1+$B$5/$B$6)^2*C14*(A14^2+A14)
		} else {
			$coupon_convexity[$yield][$time] = 
				($coupon * 100 * ($time*($time+1)) / ((1+$yield/200)**($time+2)));
				#($pv[$yield][$time] * ($time*($time+1)) / ((1+$coupon)**($time+2)));
		}
		#print "Coupon Duration[$yield] = $coupon_duration[$yield][$time]\n";
		#printf ("%d t(t+1)CF = %.4f\t", $yield, $coupon * 100 * ($time*($time+1)));
		#printf ("1/(1+r)^2 = %.4f\t", 1 / ((1+$coupon)**($time+2)));
		#printf ("Coup con = %.2f\n", $coupon_convexity[$yield][$time]);
	}
	#print "\n";
}

# For each yield, sum the duration, and conv
my @duration;
my @modduration;
my @convexity;
$maxY = 0;
for my $loop1 (YIELD_LO .. YIELD_HI) {
	for my $loop (1 .. ($term/$pay_interval)){
		$duration[$loop1] += $coupon_duration[$loop1][$loop];
		$convexity[$loop1] += $coupon_convexity[$loop1][$loop] ;
		#print "Coupon duration[$loop1][$loop] = $coupon_duration[$loop1][$loop]\n";
	}
	#printf ("Dur[$loop1] = %.3f\t", $duration[$loop1]);
	#printf ("Conv[$loop1] = %.3f\t", $convexity[$loop1]);
	$modduration[$loop1] += $duration[$loop1]/ exp($loop1/200);
	#$convexity[$loop1] = $convexity[$loop1] * ($pay_interval**2) / ($price[$loop1] );
	$convexity[$loop1] = $convexity[$loop1] *($pay_interval**2) / ($price[$loop1] ) ;
	printf ("Mod Dur[$loop1] = %.3f\t", $modduration[$loop1]);
	#printf ("Price[$loop1] = %.3f\t", $price[$loop1]);
	printf ("Conv[$loop1] = %.2f\n", $convexity[$loop1]);
}

# Find MaxY for scaling
for my $loop1 (YIELD_LO .. YIELD_HI) {
	if ($duration[$loop1] > $maxY){
		$maxY = $duration[$loop1];
	}
	if ($convexity[$loop1] > $maxY){
		$maxY = $convexity[$loop1];
	}
}
# Scaling for duration
$scale_y = 400 / $maxY;

$drawing->createText(OFFSET_X -5, &y($duration[0])-10,-text=>"Duration",-anchor=>"e", -fill => "red");
$drawing->createText(OFFSET_X -5, &y($modduration[0])+10,-text=>"Mod. Dur",-anchor=>"e", -fill => "blue");
$drawing->createText(OFFSET_X -5, &y($convexity[0]),-text=>"Convexity",-anchor=>"e", -fill => "green");

# Plot the Duration & Convexity lines for the bond
for my $loop ( YIELD_LO .. (YIELD_HI - 1) ) {
	# Macaulay duration
	$drawing->createLine(&x($loop), &y($duration[$loop]), &x($loop + 1), &y($duration[$loop + 1]), -width => 1, -fill => "red");
	$drawing->createOval(&x($loop)-2, &y($duration[$loop])-2,&x($loop)+2, &y($duration[$loop])+2, -fill => "yellow");
	my $myDuration = sprintf("%.2f",$duration[$loop]);
	$drawing->createText(&x($loop), &y($duration[$loop])-10,-text=>"$myDuration",-anchor=>"w", -fill => "red");
	
	# Modified duration
	$drawing->createLine(&x($loop), &y($modduration[$loop]), &x($loop + 1), &y($modduration[$loop + 1]), -width => 1, -fill => "blue");
	$drawing->createOval(&x($loop)-2, &y($modduration[$loop])-2,&x($loop)+2, &y($modduration[$loop])+2, -fill => "yellow");
	my $myModDuration = sprintf("%.2f",$modduration[$loop]);
	$drawing->createText(&x($loop), &y($modduration[$loop])+10,-text=>"$myModDuration",-anchor=>"w", -fill => "blue");
	
	# 1st Deravative
	#$drawing->createLine(&x($loop), &y($duration[$loop]), &x($loop + 1), &y($duration[$loop + 1]), -width => 1, -fill => "red");
	#$drawing->createOval(&x($loop)-2, &y($duration[$loop])-2,&x($loop)+2, &y($duration[$loop])+2, -fill => "yellow");
	#$myDuration = sprintf("%.2f",$duration[$loop]);
	#$drawing->createText(&x($loop), &y($duration[$loop])-10,-text=>"$myDuration",-anchor=>"w");
	
	# Convexity
	$drawing->createLine(&x($loop), &y($convexity[$loop]), &x($loop + 1), &y($convexity[$loop + 1]), -width => 1, -fill => "green");
	$drawing->createOval(&x($loop)-2, &y($convexity[$loop])-2,&x($loop)+2, &y($convexity[$loop])+2, -fill => "yellow");
	my $myConvexity = sprintf("%.2f",$convexity[$loop]);
	$drawing->createText(&x($loop), &y($convexity[$loop])-10,-text=>"$myConvexity",-anchor=>"w", -fill => "green");
}

# Create points
my @points;
for my $loop (YIELD_LO .. YIELD_HI) {
	$points[$loop][0] = $loop;
	$points[$loop][1] = $price[$loop];
}

#@points = ( [0.0833, 0.095], [.25,0.096], [0.5, 0.097], [1,0.1], [2, 0.11], [3,0.12], [5, 0.11] );
#@points = ( [-1,1], [0,2], [1,-1], [2, 2] );
my $coeffs = &spline_generate( @points );
print "Spline coefficients: @$coeffs\n";

#printf("\nApprox. 1st Derivative\n\n");

# 1st deravative
#for my $i  (YIELD_LO .. YIELD_HI) {
    #printf "[%.2f, %.2f]\n", $i, &spline_evaluate($i - 0.001, $coeffs, @points);
	#printf "[%.2f, %.2f]\n", $i, &spline_evaluate($i + 0.001, $coeffs, @points);
#	printf "%d Duration [%.4f]\n", $i, ((&spline_evaluate($i + 0.001, $coeffs, @points) - &spline_evaluate($i - 0.001, $coeffs, @points)) / 0.002)/ $price[$i]
#}

MainLoop;

#$drawing->createOval(100,50,300,250,-fill=>"black");
#$drawing->createRectangle(150,100,250,200,-fill=>"white");
#$drawing->createText(200,275,-text=>"Some text on my drawing!",-anchor=>"center");
#$drawing->createLine(2, 3, 350, 100, -width => 10, -fill => "black");
#$drawing->createLine(120, 220, 450, 200, -fill => "red");
#$drawing->createOval(30, 80, 100, 150, -fill => "yellow");
#$drawing->createRectangle(50, 20, 100, 50, -fill => "cyan");
#$drawing->createArc(40, 40, 200, 200, -fill => "green");
#$drawing->createPolygon(350, 120, 190, 160, 250, 120, -fill => "white");

# Convert x & y coordinate to the logical x
sub x {
	my $xx = $_[0];
	#printf( "X = %.1f  ", ($xx * SCALE_X) + OFFSET_X);
	return ($xx * SCALE_X) + OFFSET_X;
}
sub y {
	my $yy = $_[0];
	#printf( "Y = %.1f\n", OFFSET_Y - ($yy * $scale_y));
	return OFFSET_Y - ($yy * $scale_y);
}

sub spline_generate {
    my @points = @_;
    my ($i, $delta, $temp, @factors, @coeffs);
    $coeffs[0] = $factors[0] = 0;

    # Decomposition phase of the tridiagonal system of equations
    for ($i = 1; $i < @points - 1; $i++) {
        $delta = ($points[$i][0] - $points[$i-1][0]) /
            ($points[$i+1][0] - $points[$i-1][0]);
        $temp = $delta * $coeffs[$i-1] + 2;
        $coeffs[$i] = ($delta - 1) / @points;
        $factors[$i] = ($points[$i+1][1] - $points[$i][1]) /
            ($points[$i+1][0] - $points[$i][0]) -
                ($points[$i][1] - $points[$i-1][1]) /
                    ($points[$i][0] - $points[$i-1][0]);
        $factors[$i] = ( 6 * $factors[$i] /
                        ($points[$i+1][0] - $points[$i-1][0]) -
                        $delta * $factors[$i-1] ) / $temp;
    }

    # Backsubstitution phase of the tridiagonal system
    #
    $coeffs[$#points] = 0;
    for ($i = @points - 2; $i >= 0; $i--) {
        $coeffs[$i] = $coeffs[$i] * $coeffs[$i+1] + $factors[$i];
    }
    return \@coeffs;
}

sub spline_evaluate {
    my ($x, $coeffs, @points) = @_;
    my ($i, $delta, $mult);

    # Which section of the spline are we in?
    #
    for ($i = @points - 2; $i >= 1; $i--) {
        last if $x >= $points[$i][0];
    }

    $delta = $points[$i+1][0] - $points[$i][0];
    $mult = ( $coeffs->[$i]/2 ) +
        ($x - $points[$i][0]) * ($coeffs->[$i+1] - $coeffs->[$i])
            / (6 * $delta);
    $mult *= $x - $points[$i][0];
    $mult += ($points[$i+1][1] - $points[$i][1]) / $delta;
    $mult -= ($coeffs->[$i+1] + 2 * $coeffs->[$i]) * $delta / 6;
    return $points[$i][1] + $mult * ($x - $points[$i][0]);
}