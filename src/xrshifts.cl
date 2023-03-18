# Compute accurate shifts for a list of images taken in time sequence with
# a known approximate shift between adjacent images using cross-corelation
# techniques.

procedure xrshifts (inlist, output, shifts, regions, xlag, ylag, window, cbox)

string	inlist		{prompt="The input sky subtracted image sequence"}
string	output		{prompt="The output img, pixel shifts, and exposure time file"}
string	shifts		{prompt="Optional output relative shifts file"}
string	regions		{"[*,*]", prompt="Reference image regions used for correlation"}
real	xlag		{0, prompt="Initial shift in x in pixels"}
real	ylag		{0, prompt="Initial shift in y in pixels"}
int	window		{21, prompt="Width of the correlation window"}
int	cbox		{7, prompt="Width of the centering box"}
string	background	{"none", enum="|none|mean|median|plane|", prompt="Background fitting function"}
string	correlation	{"discrete", enum="|discrete|fourier|", prompt="Cross-correlation function"}
string	function	{"centroid", enum="|none|centroid|sawtooth|parabolic|mark|", prompt="Correlation peak centering algorithm"}
real	tolerance	{5.0, prompt="Maximum difference of shift from lag"}
bool	interactive	{no, prompt="Run in interactive mode ?"}

struct	*imglist

begin
	# Declare local variables.
	real	txlag, tylag
	real	sumdx, sumdy, dx, dy
	int	ixlag, iylag, twindow, tcbox
	int	i, nimages, idx, idy
	string	tinlist, toutput, tshifts, tregions
	string	img, refimages, inimages, refname, shiftsdb

	print ("start")
	time ("")

	# Get query parameters.
	tinlist = mktemp ("tmp$xrshifts")
	sections (inlist, option="fullname", > tinlist)
	count (tinlist) | scan (nimages)
	if (nimages <= 0) {
	    print ("The input image list is empty")
	    delete (tinlist, verify-)
	    return
	}
	toutput = output
	if (access (toutput)) {
	    print ("The output file: ", toutput, " already exists")
	    delete (tinlist, verify-)
	    return
	}
	tshifts = shifts
	if (tshifts != "") {
	    if (access (tshifts)) {
	        print ("The shifts file: ", tshifts, " already exists")
	        delete (tinlist, verify-)
	        return
	    }
	}
	tregions = regions
	txlag = xlag
	tylag = ylag
	twindow = window
	tcbox = cbox

	# Contruct temporary file names for xregister.
	inimages = mktemp ("tmp$xrshifts")
	refimages = mktemp ("tmp$xrshifts")
	shiftsdb = mktemp ("tmp$xrshifts")

	# Contruct the reference and input images list.
	imglist = tinlist
	for (i = 1; i <= nimages; i = i + 1) {
	    if (fscan (imglist, img) == EOF) {
		break
	    }
	    if (i == 1) {
		refname = img
		print (img, >> refimages)
	    } else if (i == nimages) {
		print (img, >> inimages)
	    } else {
		print (img, >> refimages)
		print (img, >> inimages)
	    }
	}

	print ("Begin computing cross-correlation functions")
	time ("")
	# Call xregister.
	ixlag = nint (txlag)
	iylag = nint (tylag)
	xregister ("@" // inimages, "@" // refimages, tregions,
	    shiftsdb, output="", databasefmt-, append-, records="",
	    coords="", xlag=ixlag, ylag=iylag, dxlag=0, dylag=0,
	    background=background, border=INDEF, loreject=INDEF, hireject=INDEF,
	    apodize=0.0, filter="none", correlation=correlation,
	    xwindow=twindow, ywindow=twindow, function=function,
	    xcbox=tcbox, ycbox=tcbox, interp_type="linear",
	    boundary_type="nearest", constant=0.0, interactive=interactive,
	    verbose-, graphics="stdgraph", display="stdimage", gcommands="",
	    icommands="")

	# Create the output file to use as input by sregister.
	imglist = shiftsdb 

	# Write the results for the first image.
	print (refname, " 0.0 0.0 1.0", >> toutput)

	# Convert the remaining shifts to integer and record. If the shift
	# is undefined or zero set it to the negative of the initial lag.
	print ("Begin accumulating total shifts ...")
	time ("")
	sumdx = 0.0
	sumdy = 0.0
	while (fscan (imglist, img, dx, dy) != EOF) {
	    if (dx == INDEF || abs (-dx - txlag) > tolerance ) {
		dx = -txlag
		dy = -tylag
		print ("    Warning the shift for image ", img, "is undefined")
	    } else if (dy == INDEF || abs (-dy - tylag) > tolerance) {
		dx = -txlag
		dy = -tylag
		print ("    Warning the shift for image ", img, "is undefined")
	    }
	    sumdx = sumdx - dx
	    sumdy = sumdy - dy
	    if (sumdx == 0.0) {
		idx = 0
	    } else {
		idx = sumdx + (abs (sumdx) / sumdx) * 0.5
	    }
	    if (sumdy == 0.0) {
		idy = 0
	    } else {
		idy = sumdy + (abs (sumdy) / sumdy) * 0.5
	    }
	    print (img, " ", sumdx, sumdy, " 1.0", >> toutput)
	}

	# Cleanup.

	if (tshifts != "") {
	    print (refname, " 0.0 0.0 ", >> tshifts)
	    concatenate (shiftsdb, tshifts, out_type="in_type", append+)
	}
	delete (shiftsdb, verify-)
	delete (refimages, verify-)
	delete (inimages, verify-)
	delete (tinlist, verify-)
	imglist = ""

	print ("finish")
	time ("")
end
